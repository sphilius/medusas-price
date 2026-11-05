// letter_check.ts - asks a vision-capable LLM whether a generated image contains
// any letters, numbers or inscriptions (the game's NO TEXT rule). Used by /vase and
// /gallery before an image is sent to the game; /test can call it on request.
//
// Fail safe: on any error, an unclear answer, or a full spend cap, it answers
// TRUE ("has letters"), so the caller throws the image away and the game uses its
// non-AI fallback instead of risking text on screen.

import { DEFAULTS, Env, num } from "./env";
import { reserveSpend } from "./guards";
import { AIProvider, ImageData } from "./providers";

const SYSTEM =
	"You inspect images for a video game that must never show text. " +
	"Answer with exactly one word: YES or NO.";

// Greek vases are covered in ornament (meander/Greek-key borders, zigzags, rays, dots,
// palmettes). Asked plainly, the vision model called those "glyphs" and rejected every
// vase (checked 2026-11-05 on a saved reject: no writing at all, only meander bands).
// So the question names the ornaments as NOT writing and asks only about readable script.
const QUESTION =
	"Decorative patterns are not writing: ignore meander or Greek-key borders, zigzags, " +
	"rays, dots, spirals, palmettes and other repeating ornament. " +
	"Apart from such ornament, does this image contain any readable letters, words, " +
	"numbers, digits, inscriptions, signatures or watermarks, in any alphabet? Answer YES or NO.";

// Turn the model's reply into a boolean. Only a clear "NO" means "no letters".
export function parseLetterAnswer(reply: string): boolean {
	const word = reply.trim().toUpperCase().replace(/[^A-Z]/g, " ").trim().split(/\s+/)[0] ?? "";
	if (word === "NO") return false;
	return true; // "YES", empty, or anything unexpected
}

// Charge the vision cost, ask the model, and return true if the image has writing.
// `async` + `await`: the function waits for the network reply without blocking the
// Worker; `try { } catch { }` turns any thrown error into the safe answer (true).
export async function hasLetters(provider: AIProvider, image: ImageData, env: Env): Promise<boolean> {
	const cost = num(env.COST_VISION_USD, DEFAULTS.COST_VISION_USD);
	if (!(await reserveSpend(env, cost))) return true;
	try {
		const reply = await provider.generateText({
			system: SYSTEM,
			prompt: QUESTION,
			images: [image],
			maxTokens: 5,
		});
		return parseLetterAnswer(reply);
	} catch {
		return true;
	}
}
