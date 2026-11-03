// env.ts - the shape of everything Cloudflare hands the Worker (the "env" object):
// the KV binding, the plain [vars] from wrangler.toml, and the secrets set with
// `wrangler secret put`. Also small helpers that turn the string vars into numbers.

export interface Env {
	// KV namespace used for rate limiting and spend tracking.
	LIMITS: KVNamespace;

	// Plain vars from wrangler.toml. Cloudflare passes them as strings.
	ALLOWED_ORIGINS: string;
	RATE_LIMIT_PER_HOUR: string;
	DAILY_CAP_USD: string;
	COST_TEXT_USD: string;
	COST_VISION_USD: string;
	COST_IMAGE_USD: string;
	LLM_MODEL: string;
	IMAGE_MODEL: string;
	MAX_BODY_BYTES: string;

	// Secrets (never in code or wrangler.toml).
	ANTHROPIC_API_KEY: string;
	GEMINI_API_KEY: string;
}

// Parse a numeric var; fall back to `fallback` if it is missing or not a number.
export function num(value: string | undefined, fallback: number): number {
	const n = Number(value);
	return value !== undefined && value !== "" && Number.isFinite(n) ? n : fallback;
}

// Defaults used when a var is missing, so a typo in wrangler.toml fails safe.
export const DEFAULTS = {
	RATE_LIMIT_PER_HOUR: 3,
	DAILY_CAP_USD: 10,
	COST_TEXT_USD: 0.002,
	COST_VISION_USD: 0.002,
	COST_IMAGE_USD: 0.07,
	MAX_BODY_BYTES: 16384,
} as const;
