// fakes.ts - test helpers: an in-memory stand-in for Cloudflare KV, a fake Env with
// the same vars as wrangler.toml, and a fake AI provider that never hits the network.

import { Env } from "../src/env";
import { AIProvider, ImageData, TextRequest } from "../src/providers";

// Just enough of KVNamespace for our guards: get and put (expiry is ignored).
export function fakeKV(): KVNamespace {
	const store = new Map<string, string>();
	return {
		get: async (key: string) => store.get(key) ?? null,
		put: async (key: string, value: string) => {
			store.set(key, value);
		},
	} as unknown as KVNamespace; // cast: we only implement the two methods we use
}

// A fake Env matching wrangler.toml's defaults. `Partial<Env>` is a generic that
// makes every Env field optional, so a test can pass just the ones it changes,
// e.g. fakeEnv({ DAILY_CAP_USD: "0" }).
export function fakeEnv(overrides: Partial<Env> = {}): Env {
	return {
		// A fresh empty KV per env, so tests never share counters.
		LIMITS: fakeKV(),
		ALLOWED_ORIGINS: "https://*.itch.zone",
		RATE_LIMIT_PER_HOUR: "3",
		DAILY_CAP_USD: "10",
		COST_TEXT_USD: "0.002",
		COST_VISION_USD: "0.002",
		COST_IMAGE_USD: "0.07",
		LLM_MODEL: "test-llm",
		IMAGE_MODEL: "test-image",
		MAX_BODY_BYTES: "16384",
		ANTHROPIC_API_KEY: "test-key",
		GEMINI_API_KEY: "test-key",
		// `...overrides` (spread) copies the test's fields on top of the defaults above.
		...overrides,
	};
}

// A 1x1 PNG, so tests have a real image to pass around.
export const TINY_PNG: ImageData = {
	base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
	mime: "image/png",
};

// Fake provider: counts calls, returns TINY_PNG, and answers text with `textReply`
// (or throws if `fail` is set).
export function fakeProvider(textReply = "NO", fail = false) {
	// What the test can inspect afterwards. `TextRequest | undefined` is a union:
	// empty until the first text call records its request.
	const calls = { text: 0, image: 0, lastText: undefined as TextRequest | undefined };
	// Typed as AIProvider, so TypeScript checks it has the same methods as the real one.
	const provider: AIProvider = {
		generateText: async (req) => {
			calls.text++;
			calls.lastText = req;
			if (fail) throw new Error("boom");
			return textReply;
		},
		generateImage: async () => {
			calls.image++;
			if (fail) throw new Error("boom");
			return TINY_PNG;
		},
	};
	return { provider, calls };
}
