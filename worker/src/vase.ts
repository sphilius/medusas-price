// vase.ts - the POST /vase endpoint: paint a black-figure Greek amphora that tells
// the story of the player's run.
//
// Flow (the guards in index.ts have already passed and the spend is reserved):
//   1. sanitizeSummary(): the game's RunLedger.summary() is UNTRUSTED input. We keep
//      only known numeric fields, clamp them, and drop everything else. No string
//      from the request ever reaches a prompt.
//   2. runFacts(): turn those numbers into short English facts built only from our
//      own fixed words (e.g. "She turned three hoplite spearmen to stone.").
//   3. Text step: the LLM turns the facts into ONE short frieze description, under a
//      system prompt that forbids any writing in the scene. cleanDescription() then
//      strips digits/odd symbols and caps the length.
//   4. Image step: the image model paints the vase with that description in the frieze.
//   5. Letter check: if the picture contains any writing, we throw it away.
// Any failure returns {fallback:true}, so the game shows its pre-made vase instead.
//
// TypeScript idioms used below:
// - `unknown` is "some value, type not known yet": TypeScript makes us check it
//   (typeof / Array.isArray) before using it, which is exactly what untrusted JSON needs.
// - `Record<string, unknown>` is an object with string keys and unchecked values.
// - `readonly [...] as const` makes a fixed list whose items TypeScript knows exactly.

import { DEFAULTS, Env, num } from "./env";
import { FALLBACK, json } from "./guards";
import { hasLetters } from "./letter_check";
import { AIProvider, ProviderError } from "./providers";

// ---------------------------------------------------------------------------
// 1. Sanitizing the run summary
// ---------------------------------------------------------------------------

// Enemy types the game can petrify (enemy_type in the .tscn files). Anything else
// in the request is ignored, so a made-up enemy name never reaches a prompt.
export const ENEMY_TYPES = ["hoplite", "leaper", "archer", "mirror_bearer", "perseus"] as const;
// `typeof ENEMY_TYPES[number]` = the union "hoplite" | "leaper" | ... (one of the list items).
export type EnemyType = (typeof ENEMY_TYPES)[number];

// The only things /vase knows about a run. Every field is a clamped whole number.
export interface VaseSummary {
	petrified: Record<EnemyType, number>; // statues made, by enemy type
	deaths: number; // times she died and respawned
	poolsUsed: number; // times she used a mirror pool
	level: number; // level reached, 1..4
	hits: number; // times she was struck (counts.hit)
	pits: number; // falls into a pit (counts.pit)
	reflects: number; // gazes bounced back by a mirror (counts.reflect)
	shattered: number; // her statues smashed (counts.statue_shattered)
}

// Upper bounds. Real runs stay far below these; they only stop silly values.
const MAX_COUNT = 99;
const MAX_LEVEL = 4;

// Read `value` as a whole number in [min, max]. Strings, NaN, objects and
// anything else become `min`. Godot sends ints as JSON numbers (sometimes 3.0).
function clampInt(value: unknown, min: number, max: number): number {
	if (typeof value !== "number" || !Number.isFinite(value)) return min;
	return Math.min(max, Math.max(min, Math.floor(value)));
}

// True for a plain JSON object ({...}), false for null, arrays, numbers, strings.
export function isPlainObject(value: unknown): value is Record<string, unknown> {
	// `value is Record<...>` is a "type guard": after `if (isPlainObject(x))`,
	// TypeScript treats x as that type.
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

// Build a VaseSummary from the raw `summary` object, keeping only known fields.
export function sanitizeSummary(raw: Record<string, unknown>): VaseSummary {
	const counts = isPlainObject(raw.counts) ? raw.counts : {};
	const byEnemy = isPlainObject(raw.petrified_by_enemy) ? raw.petrified_by_enemy : null;

	// Start every enemy type at 0, then fill in from the request.
	const petrified = {} as Record<EnemyType, number>;
	for (const type of ENEMY_TYPES) petrified[type] = 0;

	if (byEnemy) {
		// Preferred source: {"hoplite": 3, "leaper": 1, ...}. Only our keys are read.
		for (const type of ENEMY_TYPES) petrified[type] = clampInt(byEnemy[type], 0, MAX_COUNT);
	} else if (Array.isArray(raw.petrified)) {
		// Backup source: the list of statues [{enemy_type: "hoplite", ...}, ...].
		// We compare the string to our list; we never copy it.
		for (const entry of raw.petrified) {
			if (!isPlainObject(entry)) continue;
			const type = ENEMY_TYPES.find((t) => t === entry.enemy_type);
			if (type && petrified[type] < MAX_COUNT) petrified[type]++;
		}
	}
	petrified.perseus = Math.min(petrified.perseus, 1); // there is only one Perseus

	return {
		petrified,
		deaths: clampInt(raw.deaths, 0, MAX_COUNT),
		poolsUsed: clampInt(raw.pools_used, 0, MAX_COUNT),
		level: clampInt(raw.level, 1, MAX_LEVEL),
		hits: clampInt(counts.hit, 0, MAX_COUNT),
		pits: clampInt(counts.pit, 0, MAX_COUNT),
		reflects: clampInt(counts.reflect, 0, MAX_COUNT),
		shattered: clampInt(counts.statue_shattered, 0, MAX_COUNT),
	};
}

// ---------------------------------------------------------------------------
// 2. Facts for the LLM, built only from our own words
// ---------------------------------------------------------------------------

const NUMBER_WORDS = [
	"no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
	"eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
	"eighteen", "nineteen", "twenty",
];

// 3 -> "three", 25 -> "many". Words instead of digits keep numerals out of prompts.
export function numberWord(n: number): string {
	return NUMBER_WORDS[n] ?? "many";
}

// How each enemy type is described on the vase: [one, many].
const ENEMY_NAMES: Record<EnemyType, [string, string]> = {
	hoplite: ["hoplite spearman", "hoplite spearmen"],
	leaper: ["leaping warrior", "leaping warriors"],
	archer: ["archer", "archers"],
	mirror_bearer: ["mirror-bearing soldier", "mirror-bearing soldiers"],
	perseus: ["the hero Perseus", "the hero Perseus"],
};

// Where the run ended, by level number.
const PLACES = [
	"on sunlit temple steps",
	"on cliffs above the sea at dusk",
	"in a torchlit cave full of statues",
	"at a storm-lashed cave mouth, facing Perseus",
];

// "once", "twice", "three times", ...
function times(n: number): string {
	if (n === 1) return "once";
	if (n === 2) return "twice";
	return `${numberWord(n)} times`;
}

// The run as a few plain sentences. Pure function of the sanitized numbers.
export function runFacts(s: VaseSummary): string {
	const facts: string[] = [];

	const frozen: string[] = [];
	for (const type of ENEMY_TYPES) {
		const n = s.petrified[type];
		if (n === 0) continue;
		const [one, many] = ENEMY_NAMES[type];
		frozen.push(type === "perseus" ? one : `${numberWord(n)} ${n === 1 ? one : many}`);
	}
	facts.push(frozen.length > 0 ? `Medusa turned ${frozen.join(", ")} to stone.` : "Medusa turned no one to stone.");

	if (s.deaths === 0) facts.push("She never fell.");
	else facts.push(`She fell ${times(s.deaths)} and rose again each time.`);
	if (s.poolsUsed > 0) facts.push(`She knelt at a mirror pool ${times(s.poolsUsed)}.`);
	if (s.reflects > 0) facts.push(`Her own gaze was thrown back at her by a mirror ${times(s.reflects)}.`);
	if (s.hits + s.pits > 0) facts.push(`She was wounded ${times(Math.min(s.hits + s.pits, MAX_COUNT))}.`);
	if (s.shattered > 0) facts.push(`${capitalize(numberWord(s.shattered))} of her statues were smashed to rubble.`);
	facts.push(`Her journey ended ${PLACES[s.level - 1]}.`);

	return facts.join(" ");
}

// "three" -> "Three", for a number word that starts a sentence.
// `charAt(0)` is the first character; `slice(1)` is everything after it.
function capitalize(word: string): string {
	return word.charAt(0).toUpperCase() + word.slice(1);
}

// ---------------------------------------------------------------------------
// 3. Text step: facts -> one short frieze description
// ---------------------------------------------------------------------------

export const DESCRIBE_SYSTEM =
	"You write one short scene description for a painter decorating an ancient Greek " +
	"black-figure amphora. The scene is one frieze band of silhouette figures. " +
	"Rules: one or two sentences, at most 50 words. Describe only figures, poses, " +
	"gestures and objects. Never mention or ask for text, letters, words, numbers, " +
	"digits, names written out, inscriptions, signatures, labels, banners or symbols. " +
	"Write any count as a word, like three. Reply with the description only.";

// Longest description we pass to the image model (characters).
export const MAX_DESCRIPTION_CHARS = 320;
// Token budget for the text reply (about 50 words plus slack).
const DESCRIBE_MAX_TOKENS = 120;

// The user message for the text step. Contains only runFacts() output (our words).
export function describePrompt(s: VaseSummary): string {
	return (
		`Run facts: ${runFacts(s)}\n\n` +
		"Describe the frieze: Medusa with snake hair at the center, the enemies she " +
		"turned to stone shown as frozen marble statues around her, and her falls and " +
		"rises if any. Keep it to one scene."
	);
}

// Words that ask the painter for writing (a sign, a scroll, an inscription...).
// If the LLM uses one anyway, we drop its reply and use fallbackDescription().
// `\b` in a regex is a word boundary, so "sign" matches but "design" does not;
// the trailing `s?` also catches plurals; the `i` flag ignores upper/lower case.
const WRITING_WORDS =
	/\b(text|texts|letters?|lettering|words?|writing|written|writes?|inscri\w*|signs?|signature\w*|labels?|labell?ed|captions?|banners?|scrolls?|tablets?|plaques?|names?|named|numbers?|numerals?|digits?|glyphs?|symbols?|runes?|alphabet|spells? out|reads?|reading)\b/i;

// Tidy the LLM's reply before it goes into the image prompt:
// keep letters, spaces and simple punctuation (no digits, quotes or symbols that
// could invite painted glyphs), collapse spaces, and cut at a word boundary.
// Returns "" when nothing usable is left, or when the reply asks for writing.
export function cleanDescription(reply: string): string {
	if (WRITING_WORDS.test(reply)) return "";
	let text = reply.replace(/[^A-Za-z ,.;'\-]/g, " ").replace(/\s+/g, " ").trim();
	if (text.length > MAX_DESCRIPTION_CHARS) {
		text = text.slice(0, MAX_DESCRIPTION_CHARS);
		const lastSpace = text.lastIndexOf(" ");
		if (lastSpace > 0) text = text.slice(0, lastSpace);
		text = text.replace(/[ ,;'\-]+$/, "") + ".";
	}
	// Fewer than 3 words is not a scene (e.g. the model answered "NO").
	return text.split(" ").length >= 3 ? text : "";
}

// Used if the LLM's reply is unusable: a plain scene from the facts alone.
export function fallbackDescription(s: VaseSummary): string {
	const total = ENEMY_TYPES.reduce((sum, t) => sum + s.petrified[t], 0);
	const statues = total > 0 ? `${numberWord(total)} soldiers frozen as stone statues around her` : "soldiers fleeing from her gaze";
	return `Medusa with writhing snake hair stands at the center, ${statues}.`;
}

// ---------------------------------------------------------------------------
// 4. Image step
// ---------------------------------------------------------------------------

// Portrait 3:4. Gemini maps this to its "3:4" ratio at the 1K tier.
export const VASE_WIDTH = 768;
export const VASE_HEIGHT = 1024;

// The full image prompt. `description` must already be cleaned.
export function vaseImagePrompt(description: string): string {
	return (
		// Colors are named, never written as hex codes: image models tend to paint a code
		// like "#1A1410" onto the picture as visible text, which the letter check then
		// (rightly) rejects. Plain bands replace the Greek key, which can read as glyphs.
		"Front view of a single ancient Greek black-figure amphora, upright and centered, " +
		"the whole vessel visible, on a flat solid near-black background. " +
		"The vase body is warm terracotta orange, painted with glossy black slip. " +
		`One wide frieze band around the belly shows, in black-figure silhouettes: ${description} ` +
		"The soldiers turned to stone are painted pale marble white, frozen mid-pose. " +
		"Plain solid black bands run above and below the frieze, simple black rays at the foot. " +
		"Flat graphic style, crisp edges, no background gradient. " +
		"Absolutely no text, no letters, no numbers, no inscriptions, no signatures, " +
		"no watermark, no labels, no captions."
	);
}

// ---------------------------------------------------------------------------
// The endpoint
// ---------------------------------------------------------------------------

// What /vase reserves against the daily cap up front: one text call + one image.
// (The letter check reserves its own vision cost inside hasLetters().)
export function vaseCost(env: Env): number {
	return num(env.COST_TEXT_USD, DEFAULTS.COST_TEXT_USD) + num(env.COST_IMAGE_USD, DEFAULTS.COST_IMAGE_USD);
}

// Run steps 2-5 and build the response. `cors` are the headers index.ts computed.
export async function paintVase(
	summary: VaseSummary,
	env: Env,
	provider: AIProvider,
	cors: Record<string, string>,
): Promise<Response> {
	try {
		const reply = await provider.generateText({
			system: DESCRIBE_SYSTEM,
			prompt: describePrompt(summary),
			maxTokens: DESCRIBE_MAX_TOKENS,
		});
		const description = cleanDescription(reply) || fallbackDescription(summary);
		// Local debugging only: show why a reply was dropped. Never logged in production.
		if (env.DEBUG_REJECTS === "1") console.log("vase debug: LLM reply:", reply);

		const image = await provider.generateImage({
			prompt: vaseImagePrompt(description),
			width: VASE_WIDTH,
			height: VASE_HEIGHT,
		});

		// The NO TEXT rule. hasLetters() answers true when unsure, so doubt = fallback.
		// 502 because the upstream output was unusable, same as a provider failure.
		if (await hasLetters(provider, image, env)) {
			console.log("vase: letters found, using fallback");
			// Local debugging only (see Env.DEBUG_REJECTS): hand back the rejected picture.
			if (env.DEBUG_REJECTS === "1") {
				return json({ fallback: true, rejected: true, image: image.base64, mime: image.mime, description }, 502, cors);
			}
			return json(FALLBACK, 502, cors);
		}
		return json({ ok: true, image: image.base64, mime: image.mime }, 200, cors);
	} catch (err) {
		// Log only the status code, never the provider's message (it can echo the prompt).
		console.log(err instanceof ProviderError ? err.message : "provider error: exception");
		return json(FALLBACK, 502, cors);
	}
}
