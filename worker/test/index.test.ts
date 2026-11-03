// index.test.ts - end-to-end tests of the router with a fake provider and fake KV:
// the guard order, the 403/413/429 refusals, and the /test response shape.
// Each test builds a Request like a browser would, hands it to handleRequest, and
// checks the Response. `calls` from fakeProvider proves whether money would have
// been spent (calls.image counts image generations).

import { describe, expect, it } from "vitest";
import { handleRequest } from "../src/index";
import { fakeEnv, fakeProvider, TINY_PNG } from "./fakes";

// Helper: a POST to /test from `origin` with an optional body.
// `string | null` lets a test send no Origin at all; `body = ""` is a default value.
function post(origin: string | null, body = "", ip = "1.2.3.4"): Request {
	// `Record<string, string>` is a generic type: an object whose keys and values are strings.
	const headers: Record<string, string> = { "CF-Connecting-IP": ip, "Content-Type": "application/json" };
	if (origin) headers.Origin = origin;
	return new Request("https://worker.test/test", { method: "POST", headers, body });
}

// The origin itch.io's game iframe is expected to send.
const ITCH = "https://html-classic.itch.zone";

describe("POST /test", () => {
	it("returns a base64 image with CORS headers", async () => {
		const { provider } = fakeProvider();
		const res = await handleRequest(post(ITCH), fakeEnv(), provider);
		expect(res.status).toBe(200);
		expect(res.headers.get("Access-Control-Allow-Origin")).toBe(ITCH);
		expect(await res.json()).toEqual({ ok: true, image: TINY_PNG.base64, mime: "image/png" });
	});

	it("adds the letter check when asked", async () => {
		const { provider, calls } = fakeProvider("NO");
		const res = await handleRequest(post(ITCH, '{"check_letters":true}'), fakeEnv(), provider);
		// `as { letters: boolean }` tells TypeScript what shape the parsed JSON has.
		expect(((await res.json()) as { letters: boolean }).letters).toBe(false);
		expect(calls.text).toBe(1);
	});

	it("rejects a bad origin with 403 and no CORS, before any provider call", async () => {
		const { provider, calls } = fakeProvider();
		const res = await handleRequest(post("https://evil.example"), fakeEnv(), provider);
		expect(res.status).toBe(403);
		// No CORS header means the browser hides the response from the page entirely.
		expect(res.headers.get("Access-Control-Allow-Origin")).toBeNull();
		expect(calls.image).toBe(0);
	});

	it("answers the CORS preflight without counting it", async () => {
		// Limit of 1: if the preflight used the slot, the real POST would get 429.
		const env = fakeEnv({ RATE_LIMIT_PER_HOUR: "1" });
		// `const { provider } = ...` is destructuring: take just the provider field.
		const { provider } = fakeProvider();
		const pre = new Request("https://worker.test/test", { method: "OPTIONS", headers: { Origin: ITCH } });
		expect((await handleRequest(pre, env, provider)).status).toBe(204);
		expect((await handleRequest(post(ITCH), env, provider)).status).toBe(200);
	});

	it("refuses a body over 16 KB with 413", async () => {
		const { provider } = fakeProvider();
		// 16385 bytes = one byte past the 16 KB limit.
		const res = await handleRequest(post(ITCH, "x".repeat(16385)), fakeEnv(), provider);
		expect(res.status).toBe(413);
	});

	it("returns 429 {fallback:true} on the 4th request in an hour", async () => {
		const env = fakeEnv();
		const { provider, calls } = fakeProvider();
		for (let i = 0; i < 3; i++) expect((await handleRequest(post(ITCH), env, provider)).status).toBe(200);
		const res = await handleRequest(post(ITCH), env, provider);
		expect(res.status).toBe(429);
		expect(await res.json()).toEqual({ fallback: true });
		// Only the first three reached the image model.
		expect(calls.image).toBe(3);
	});

	it("returns 429 {fallback:true} when the daily cap is reached", async () => {
		const { provider, calls } = fakeProvider();
		// A $0.01 cap is below one $0.07 image, so nothing may be generated.
		const res = await handleRequest(post(ITCH), fakeEnv({ DAILY_CAP_USD: "0.01" }), provider);
		expect(res.status).toBe(429);
		expect(await res.json()).toEqual({ fallback: true });
		expect(calls.image).toBe(0);
	});

	it("turns a provider failure into 502 {fallback:true}", async () => {
		// fail = true makes the fake provider throw, like a provider outage.
		const res = await handleRequest(post(ITCH), fakeEnv(), fakeProvider("NO", true).provider);
		expect(res.status).toBe(502);
		expect(await res.json()).toEqual({ fallback: true });
	});

	it("404s unknown paths", async () => {
		const req = new Request("https://worker.test/nope", { method: "POST", headers: { Origin: ITCH } });
		expect((await handleRequest(req, fakeEnv(), fakeProvider().provider)).status).toBe(404);
	});
});
