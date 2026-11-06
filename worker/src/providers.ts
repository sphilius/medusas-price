// providers.ts - THE ONLY FILE THAT TALKS TO AI PROVIDERS.
// Everything else uses the small `AIProvider` interface below, so swapping a
// provider (say Gemini images -> something else) means editing only this file.
//
// Current providers:
// - Text (and vision): Anthropic Messages API, model from LLM_MODEL (claude-haiku-5-5).
// - Images: Google Gemini generateContent with image output, model from IMAGE_MODEL.
//
// Logging rule: on failure we log only the HTTP status, never prompts, bodies or keys.
//
// TypeScript idioms: an `interface` describes the shape an object must have;
// `?` after a field name (images?) makes it optional; `Promise<T>` is the result
// of an async function that eventually produces a T.

import { Env } from "./env";

// An image passed around as base64 text plus its type, e.g. "image/png".
export interface ImageData {
	base64: string;
	mime: string;
}

export interface TextRequest {
	system?: string; // instructions for the model
	prompt: string; // the user message
	images?: ImageData[]; // optional pictures for vision (the letter check uses this)
	maxTokens?: number;
}

export interface ImageRequest {
	prompt: string;
	width: number;
	height: number;
	referenceImages?: ImageData[]; // optional pictures to work from (img2img, the gallery)
}

// The whole contract between the Worker and "some AI".
export interface AIProvider {
	generateText(req: TextRequest): Promise<string>;
	generateImage(req: ImageRequest): Promise<ImageData>;
}

// Thrown when a provider call fails. Carries only the HTTP status, nothing sensitive.
export class ProviderError extends Error {
	constructor(public readonly status: number) {
		super(`provider error: status ${status}`);
	}
}

// ---------------------------------------------------------------------------
// Anthropic (text + vision)
// ---------------------------------------------------------------------------

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

async function anthropicText(env: Env, req: TextRequest): Promise<string> {
	// Images first, then the question, as Anthropic recommends for vision.
	const content: unknown[] = (req.images ?? []).map((img) => ({
		type: "image",
		source: { type: "base64", media_type: img.mime, data: img.base64 },
	}));
	content.push({ type: "text", text: req.prompt });

	const res = await fetch(ANTHROPIC_URL, {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			"x-api-key": env.ANTHROPIC_API_KEY,
			"anthropic-version": ANTHROPIC_VERSION,
		},
		body: JSON.stringify({
			model: env.LLM_MODEL,
			max_tokens: req.maxTokens ?? 512,
			// Claude Haiku 5.5 thinks by default, and thinking spends max_tokens first. With
			// our tiny budgets (5 tokens for the YES/NO letter check, 120 for the frieze) the
			// thinking used them all, so the reply had no text: the frieze fell back to the
			// plain description and the empty YES/NO counted as "has letters" (every vase
			// rejected, found 2026-11-05). These calls are simple, so thinking stays off.
			// ("disabled" is accepted on Haiku 5.5 at its default effort, medium.)
			thinking: { type: "disabled" },
			...(req.system ? { system: req.system } : {}),
			messages: [{ role: "user", content }],
		}),
	});
	if (!res.ok) throw new ProviderError(res.status);

	// The reply is a list of content blocks; join the text ones.
	const data = (await res.json()) as { content?: { type: string; text?: string }[] };
	return (data.content ?? [])
		.filter((block) => block.type === "text")
		.map((block) => block.text ?? "")
		.join("");
}

// ---------------------------------------------------------------------------
// Google Gemini (images)
// ---------------------------------------------------------------------------

const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models";

// Gemini picks resolution by tier, not exact pixels: "512", "1K", "2K", "4K".
function geminiImageSize(width: number, height: number): string {
	const side = Math.max(width, height);
	if (side <= 512) return "512";
	if (side <= 1024) return "1K";
	return "2K";
}

// Gemini wants an aspect ratio string like "1:1". Use the closest supported one.
function geminiAspect(width: number, height: number): string {
	const options: [string, number][] = [
		["1:1", 1], ["3:2", 1.5], ["2:3", 2 / 3], ["4:3", 4 / 3], ["3:4", 0.75],
		["16:9", 16 / 9], ["9:16", 9 / 16],
	];
	const ratio = width / height;
	let best = options[0];
	for (const opt of options) {
		if (Math.abs(opt[1] - ratio) < Math.abs(best[1] - ratio)) best = opt;
	}
	return best[0];
}

async function geminiImage(env: Env, req: ImageRequest): Promise<ImageData> {
	// Reference images go in the same message as the prompt.
	const parts: unknown[] = (req.referenceImages ?? []).map((img) => ({
		inline_data: { mime_type: img.mime, data: img.base64 },
	}));
	parts.push({ text: req.prompt });

	const res = await fetch(`${GEMINI_URL}/${env.IMAGE_MODEL}:generateContent`, {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			"x-goog-api-key": env.GEMINI_API_KEY,
		},
		body: JSON.stringify({
			contents: [{ role: "user", parts }],
			generationConfig: {
				responseModalities: ["IMAGE"],
				imageConfig: {
					aspectRatio: geminiAspect(req.width, req.height),
					imageSize: geminiImageSize(req.width, req.height),
				},
			},
		}),
	});
	if (!res.ok) throw new ProviderError(res.status);

	// Find the first image part. REST replies use camelCase (inlineData); accept
	// snake_case too in case that changes.
	type Part = {
		inlineData?: { mimeType?: string; data?: string };
		inline_data?: { mime_type?: string; data?: string };
	};
	const data = (await res.json()) as { candidates?: { content?: { parts?: Part[] } }[] };
	for (const part of data.candidates?.[0]?.content?.parts ?? []) {
		const base64 = part.inlineData?.data ?? part.inline_data?.data;
		if (base64) {
			const mime = part.inlineData?.mimeType ?? part.inline_data?.mime_type ?? "image/png";
			return { base64, mime };
		}
	}
	// A 200 with no image (e.g. a safety block) counts as a failure.
	throw new ProviderError(502);
}

// ---------------------------------------------------------------------------
// The provider the Worker actually uses
// ---------------------------------------------------------------------------

export function makeProvider(env: Env): AIProvider {
	return {
		generateText: (req) => anthropicText(env, req),
		generateImage: (req) => geminiImage(env, req),
	};
}
