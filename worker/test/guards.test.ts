// guards.test.ts - unit tests for the request guards and the letter-check parser.
// Run with `npm test`. No network, no Cloudflare account needed.
//
// vitest basics: `describe` groups tests, `it` is one test, and
// `expect(x).toBe(y)` fails the test if x is not y. Tests are `async` because the
// guards await KV reads; `await` waits for each result before checking it.

import { describe, expect, it } from "vitest";
import { isAllowedOrigin, readBodyLimited, reserveSpend, spentToday, takeRateSlot } from "../src/guards";
import { hasLetters, parseLetterAnswer } from "../src/letter_check";
import { fakeEnv, fakeProvider, TINY_PNG } from "./fakes";

describe("origin allowlist", () => {
	const list = "https://*.itch.zone,https://example.com";
	it("allows localhost on any port", () => {
		expect(isAllowedOrigin("http://localhost:8060", list)).toBe(true);
		expect(isAllowedOrigin("http://localhost", list)).toBe(true);
		expect(isAllowedOrigin("http://127.0.0.1:8787", list)).toBe(true);
	});
	it("allows itch.zone subdomains and exact entries", () => {
		expect(isAllowedOrigin("https://html-classic.itch.zone", list)).toBe(true);
		expect(isAllowedOrigin("https://example.com", list)).toBe(true);
	});
	it("rejects look-alikes, http itch, and missing origins", () => {
		expect(isAllowedOrigin("https://evil-itch.zone", list)).toBe(false);
		expect(isAllowedOrigin("https://itch.zone.evil.com", list)).toBe(false);
		expect(isAllowedOrigin("http://html-classic.itch.zone", list)).toBe(false);
		expect(isAllowedOrigin("https://localhost.evil.com", list)).toBe(false);
		expect(isAllowedOrigin(null, list)).toBe(false);
	});
});

describe("body limit", () => {
	// Arrow-function helper: builds a POST request carrying `body`.
	const post = (body: string) => new Request("https://w.test/test", { method: "POST", body });
	it("accepts exactly the limit", async () => {
		expect(await readBodyLimited(post("a".repeat(16384)), 16384)).toHaveLength(16384);
	});
	it("rejects one byte over", async () => {
		expect(await readBodyLimited(post("a".repeat(16385)), 16384)).toBeNull();
	});
});

describe("rate limit", () => {
	// Helper: a request that looks like it came from `ip` (Cloudflare sets this header).
	const req = (ip: string) => new Request("https://w.test/test", { headers: { "CF-Connecting-IP": ip } });
	it("allows 3 per hour per IP, then refuses", async () => {
		const env = fakeEnv();
		// A fixed clock, so the test doesn't break if it runs across an hour boundary.
		const now = new Date("2026-11-02T15:00:00Z");
		for (let i = 0; i < 3; i++) expect(await takeRateSlot(req("1.2.3.4"), env, now)).toBe(true);
		expect(await takeRateSlot(req("1.2.3.4"), env, now)).toBe(false);
		// Another IP is unaffected, and the next hour starts fresh.
		expect(await takeRateSlot(req("5.6.7.8"), env, now)).toBe(true);
		expect(await takeRateSlot(req("1.2.3.4"), env, new Date("2026-11-02T16:00:00Z"))).toBe(true);
	});
});

describe("spend cap", () => {
	it("charges until the cap, then refuses without charging", async () => {
		// Cap of $0.20 fits two $0.07 images; the third would make $0.21.
		const env = fakeEnv({ DAILY_CAP_USD: "0.2" });
		const now = new Date("2026-11-02T15:00:00Z");
		expect(await reserveSpend(env, 0.07, now)).toBe(true);
		expect(await reserveSpend(env, 0.07, now)).toBe(true);
		expect(await reserveSpend(env, 0.07, now)).toBe(false);
		expect(await spentToday(env, now)).toBeCloseTo(0.14);
	});
});

describe("letter check", () => {
	it("only a clear NO means no letters", () => {
		expect(parseLetterAnswer("NO")).toBe(false);
		expect(parseLetterAnswer(" no.")).toBe(false);
		expect(parseLetterAnswer("YES")).toBe(true);
		expect(parseLetterAnswer("")).toBe(true);
		expect(parseLetterAnswer("Maybe")).toBe(true);
	});
	it("sends the image to the vision model", async () => {
		const { provider, calls } = fakeProvider("NO");
		expect(await hasLetters(provider, TINY_PNG, fakeEnv())).toBe(false);
		// `?.` is optional chaining: stop with undefined instead of crashing if a part is missing.
		expect(calls.lastText?.images?.[0]).toEqual(TINY_PNG);
	});
	it("fails safe on provider error or full cap", async () => {
		expect(await hasLetters(fakeProvider("NO", true).provider, TINY_PNG, fakeEnv())).toBe(true);
		// With a $0 cap the model must not even be called.
		const broke = fakeProvider("NO");
		expect(await hasLetters(broke.provider, TINY_PNG, fakeEnv({ DAILY_CAP_USD: "0" }))).toBe(true);
		expect(broke.calls.text).toBe(0);
	});
});
