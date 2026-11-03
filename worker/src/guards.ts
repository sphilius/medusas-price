// guards.ts - the checks every request passes before any money is spent:
// Origin allowlist + CORS headers, request body size limit, per-IP hourly rate
// limit, and the daily spend cap. Nothing here ever logs a request body or a key.
//
// TypeScript idioms used below:
// - `async function ... : Promise<boolean>`: the function pauses at each `await`
//   (e.g. waiting on KV) and eventually hands back a boolean.
// - `string | null` is a union type: the value is either a string or null.
// - `a ?? b` means "a, unless a is null/undefined, then b".
// - `const { done, value } = ...` is destructuring: pull two fields out of an object.
// - `as const` freezes an object literal so its values are read-only.

import { DEFAULTS, Env, num } from "./env";

// ---------------------------------------------------------------------------
// Origin allowlist and CORS
// ---------------------------------------------------------------------------

// Local dev origins (any port) are always allowed: Godot's web preview, wrangler dev,
// and desktop Godot runs (which send "Origin: http://localhost" themselves).
const LOCAL_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

// True when `origin` matches the allowlist. Entries are exact origins, or
// "https://*.example.com" to allow any subdomain of example.com.
export function isAllowedOrigin(origin: string | null, allowList: string): boolean {
	if (!origin) return false;
	if (LOCAL_ORIGIN.test(origin)) return true;
	for (const raw of allowList.split(",")) {
		const entry = raw.trim();
		if (entry === "") continue;
		if (entry === origin) return true;
		// Wildcard: "https://*.itch.zone" -> scheme "https://", suffix ".itch.zone".
		const star = entry.indexOf("*.");
		if (star !== -1) {
			const scheme = entry.slice(0, star);
			const suffix = entry.slice(star + 1);
			if (origin.startsWith(scheme) && origin.endsWith(suffix) && origin.length > scheme.length + suffix.length) {
				return true;
			}
		}
	}
	return false;
}

// Log a rejected Origin so it shows up in `wrangler tail` (the only thing logged).
export function logRejectedOrigin(origin: string | null): void {
	console.log(`rejected origin: ${origin ?? "(none)"}`);
}

// CORS headers for an allowed origin. The browser needs these on every response,
// including errors, or the game can't read the {fallback:true} body.
export function corsHeaders(origin: string): Record<string, string> {
	return {
		"Access-Control-Allow-Origin": origin,
		"Access-Control-Allow-Methods": "POST, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type",
		"Access-Control-Max-Age": "86400",
		Vary: "Origin",
	};
}

// Build a JSON response with the given status and extra headers.
export function json(body: unknown, status: number, headers: Record<string, string> = {}): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: { "Content-Type": "application/json", ...headers },
	});
}

// The one refusal body the game understands: "use your non-AI fallback".
export const FALLBACK = { fallback: true } as const;

// ---------------------------------------------------------------------------
// Body size limit
// ---------------------------------------------------------------------------

// Read the request body as text, stopping as soon as it passes `maxBytes`.
// Returns null when the body is too big. Checks Content-Length first (cheap), then
// counts the real bytes, because Content-Length can be missing or wrong.
export async function readBodyLimited(request: Request, maxBytes: number): Promise<string | null> {
	const declared = Number(request.headers.get("Content-Length") ?? "0");
	if (declared > maxBytes) return null;
	if (!request.body) return "";

	const reader = request.body.getReader();
	const chunks: Uint8Array[] = [];
	let total = 0;
	while (true) {
		const { done, value } = await reader.read();
		if (done) break;
		total += value.byteLength;
		if (total > maxBytes) {
			await reader.cancel();
			return null;
		}
		chunks.push(value);
	}
	// Glue the chunks together and decode as UTF-8.
	const bytes = new Uint8Array(total);
	let offset = 0;
	for (const chunk of chunks) {
		bytes.set(chunk, offset);
		offset += chunk.byteLength;
	}
	return new TextDecoder().decode(bytes);
}

// The body limit from wrangler.toml (MAX_BODY_BYTES), or 16 KB if it is missing.
export function maxBodyBytes(env: Env): number {
	return num(env.MAX_BODY_BYTES, DEFAULTS.MAX_BODY_BYTES);
}

// ---------------------------------------------------------------------------
// Per-IP rate limit (generation requests per clock hour)
// ---------------------------------------------------------------------------

// SHA-256 of the IP, shortened. We store the hash, not the raw IP address.
async function hashIp(ip: string): Promise<string> {
	const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(ip));
	return [...new Uint8Array(digest)]
		.slice(0, 8)
		.map((b) => b.toString(16).padStart(2, "0"))
		.join("");
}

// Take one generation slot for this caller's IP. Returns false when the IP has
// already used its slots this hour. KV keys expire on their own after 2 hours.
// (KV is not atomic, so two requests at the same instant could both pass. Fine at jam scale.)
export async function takeRateSlot(request: Request, env: Env, now: Date = new Date()): Promise<boolean> {
	const limit = num(env.RATE_LIMIT_PER_HOUR, DEFAULTS.RATE_LIMIT_PER_HOUR);
	const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
	const hour = Math.floor(now.getTime() / 3_600_000);
	const key = `rl:${await hashIp(ip)}:${hour}`;

	const used = Number((await env.LIMITS.get(key)) ?? "0");
	if (used >= limit) return false;
	await env.LIMITS.put(key, String(used + 1), { expirationTtl: 7200 });
	return true;
}

// ---------------------------------------------------------------------------
// Daily spend cap
// ---------------------------------------------------------------------------

function spendKey(now: Date): string {
	return `spend:${now.toISOString().slice(0, 10)}`; // e.g. spend:2026-11-02 (UTC day)
}

// Charge `costUsd` to today's counter BEFORE a provider call. Returns false (and
// charges nothing) when that would go over the cap. Failed calls stay charged, which
// keeps the estimate on the safe side.
export async function reserveSpend(env: Env, costUsd: number, now: Date = new Date()): Promise<boolean> {
	const cap = num(env.DAILY_CAP_USD, DEFAULTS.DAILY_CAP_USD);
	const key = spendKey(now);
	const spent = Number((await env.LIMITS.get(key)) ?? "0");
	if (spent + costUsd > cap) return false;
	await env.LIMITS.put(key, String(spent + costUsd), { expirationTtl: 172_800 });
	return true;
}

// Today's spend so far (used by tests and handy for debugging).
export async function spentToday(env: Env, now: Date = new Date()): Promise<number> {
	return Number((await env.LIMITS.get(spendKey(now))) ?? "0");
}
