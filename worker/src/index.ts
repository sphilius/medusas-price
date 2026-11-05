// index.ts - the Worker's front door. Routes requests and runs the guards in order:
//   1. Origin allowlist (rejected origins are logged for `wrangler tail`)
//   2. CORS preflight (OPTIONS) answered here, never counted
//   3. Body size limit (16 KB)
//   4. Per-IP rate limit (3 generations per hour)
//   5. Daily spend cap (estimated cost reserved before the call)
// Then the endpoint itself. Every refusal or failure returns JSON {fallback:true},
// which tells the game to use its non-AI fallback.
//
// Endpoints:
//   POST /test  -> one small black-figure snake image, as base64 in JSON.
//                  Body {"check_letters": true} also runs the letter check.
//   POST /vase  -> the end-of-run amphora. Body {"summary": {...}} (RunLedger.summary()).
//                  Success {"ok":true,"image":"<base64 png>","mime":"image/png"}.
//                  Reserves COST_TEXT_USD + COST_IMAGE_USD; see src/vase.ts.

import { DEFAULTS, Env, num } from "./env";
import {
	corsHeaders,
	FALLBACK,
	isAllowedOrigin,
	json,
	logRejectedOrigin,
	maxBodyBytes,
	readBodyLimited,
	reserveSpend,
	takeRateSlot,
} from "./guards";
import { hasLetters } from "./letter_check";
import { AIProvider, makeProvider, ProviderError } from "./providers";
import { isPlainObject, paintVase, sanitizeSummary, vaseCost, VaseSummary } from "./vase";

const TEST_PROMPT =
	"black-figure Greek pottery style, a single snake, terracotta background, " +
	"no text, no letters, no inscriptions";
const TEST_SIZE = 512;

// The real logic, with the provider passed in so tests can use a fake one.
export async function handleRequest(request: Request, env: Env, provider: AIProvider): Promise<Response> {
	// 1. Origin. Without an allowed origin we send no CORS headers at all.
	const origin = request.headers.get("Origin");
	if (!isAllowedOrigin(origin, env.ALLOWED_ORIGINS)) {
		logRejectedOrigin(origin);
		return json(FALLBACK, 403);
	}
	const cors = corsHeaders(origin as string); // safe: isAllowedOrigin rejected null

	// 2. Preflight: the browser asks "may I POST JSON?" before the real request.
	if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });

	const url = new URL(request.url);
	const isVase = url.pathname === "/vase";
	if (request.method !== "POST" || (url.pathname !== "/test" && !isVase)) return json(FALLBACK, 404, cors);

	// 3. Body size. Parse it as JSON (an empty body counts as {}).
	// Anything that is not a JSON object (e.g. `null`, `[1]`, `"hi"`) is a bad body.
	const text = await readBodyLimited(request, maxBodyBytes(env));
	if (text === null) return json(FALLBACK, 413, cors);
	let body: Record<string, unknown> = {};
	try {
		if (text.trim() !== "") {
			const parsed: unknown = JSON.parse(text);
			if (!isPlainObject(parsed)) return json(FALLBACK, 400, cors);
			body = parsed;
		}
	} catch {
		return json(FALLBACK, 400, cors);
	}

	// /vase needs {"summary": {...}}. Check the shape now, before a rate slot is used.
	// `let x: VaseSummary | null` is a union: null until we have a clean summary.
	let summary: VaseSummary | null = null;
	if (isVase) {
		if (!isPlainObject(body.summary)) return json(FALLBACK, 400, cors);
		summary = sanitizeSummary(body.summary);
	}

	// 4 + 5. Rate limit, then spend cap. Both refuse with 429 {fallback:true}.
	// /vase makes a text call and an image, so it reserves both costs at once.
	if (!(await takeRateSlot(request, env))) return json(FALLBACK, 429, cors);
	const cost = isVase ? vaseCost(env) : num(env.COST_IMAGE_USD, DEFAULTS.COST_IMAGE_USD);
	if (!(await reserveSpend(env, cost))) return json(FALLBACK, 429, cors);

	// `summary !== null` is always true for /vase; the check is there so TypeScript
	// knows summary is a VaseSummary (not null) inside the call.
	if (isVase && summary !== null) return paintVase(summary, env, provider, cors);

	// Otherwise /test, unchanged.
	try {
		const image = await provider.generateImage({ prompt: TEST_PROMPT, width: TEST_SIZE, height: TEST_SIZE });
		const result: Record<string, unknown> = { ok: true, image: image.base64, mime: image.mime };
		if (body.check_letters === true) result.letters = await hasLetters(provider, image, env);
		return json(result, 200, cors);
	} catch (err) {
		// Log only the status code, never the provider's message (it can echo the prompt).
		console.log(err instanceof ProviderError ? err.message : "provider error: exception");
		return json(FALLBACK, 502, cors);
	}
}

// What Cloudflare calls for each request.
export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		return handleRequest(request, env, makeProvider(env));
	},
};
