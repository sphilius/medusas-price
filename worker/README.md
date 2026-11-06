# Medusa's Price: AI Worker

A Cloudflare Worker that sits between the game and the AI providers. It is the **only** place API keys live. The Godot project only knows the Worker URL (`Balance.WORKER_URL`).

- Text and vision: Anthropic `claude-haiku-5-5`
- Images: Google Gemini `gemini-3.1-flash-image`

## Files

| File | What it does |
|---|---|
| `wrangler.toml` | Plain settings: allowed origins, rate limit, daily cap, cost estimates, models. **No secrets.** |
| `src/index.ts` | Router and guard order. Endpoints `POST /test` and `POST /vase`. |
| `src/vase.ts` | `/vase`: sanitizes the run summary, asks the LLM for one frieze description, paints the amphora. |
| `src/guards.ts` | Origin allowlist, CORS, 16 KB body limit, per-IP rate limit, daily spend cap. |
| `src/providers.ts` | **The only file that calls providers.** Swap a provider by editing this file alone. |
| `src/letter_check.ts` | Asks the vision model "does this image contain any writing?" Returns `true` when unsure. |
| `test/` | Unit tests with fake KV and a fake provider. No network needed. |

## 1. First-time setup 🛠️

Run these in PowerShell from the `worker` folder.

1. Install packages:
   ```bash
   npm install
   ```
2. Log in to Cloudflare (this opens a browser):
   ```bash
   npx wrangler login
   ```
3. Create the KV namespace that stores the rate limit and spend counters:
   ```bash
   npx wrangler kv namespace create LIMITS
   ```
   It prints an `id`. Paste it into `wrangler.toml`, replacing `PASTE_KV_NAMESPACE_ID_HERE`.
4. Set the two secrets. Each command asks you to paste the key, and the key never touches a file:
   ```bash
   npx wrangler secret put ANTHROPIC_API_KEY
   ```
   ```bash
   npx wrangler secret put GEMINI_API_KEY
   ```
5. Deploy:
   ```bash
   npx wrangler deploy
   ```
   It prints the URL, like `https://medusas-price-worker.<your-subdomain>.workers.dev`.
6. Put that URL in `autoload/balance.gd` as `WORKER_URL`.

## 2. Local development 💻

1. Create `worker/.dev.vars` (already gitignored, never commit it) with your keys:
   ```
   ANTHROPIC_API_KEY=...
   GEMINI_API_KEY=...
   ```
2. Start the local Worker on port 8787:
   ```bash
   npx wrangler dev
   ```
3. Point `Balance.WORKER_URL` at `http://localhost:8787` while testing, and set it back before a release build.

`http://localhost` and `http://127.0.0.1` on any port are always allowed, so the Godot web preview (port 8060) and desktop editor runs both work. Desktop Godot sends `Origin: http://localhost` itself, because only browsers add an Origin header on their own.

## 3. Tests ✅

```bash
npm test
```
```bash
npm run check
```

## 4. Try `/test` with curl 🐍

The Worker refuses requests without an allowed `Origin`, so curl has to send one:

```bash
curl -X POST http://localhost:8787/test -H "Origin: http://localhost" -H "Content-Type: application/json" -d "{}"
```

Add the letter check (costs one extra vision call):

```bash
curl -X POST http://localhost:8787/test -H "Origin: http://localhost" -H "Content-Type: application/json" -d "{\"check_letters\": true}"
```

Success looks like `{"ok":true,"image":"<base64>","mime":"image/png"}` (plus `"letters":false` when checked). In-game, press **F10** in a debug build of the test room to call `/test` and see the image.

## 4b. `/vase`: the end-of-run amphora 🏺

The game sends `RunLedger.summary()` and gets back a black-figure amphora painted with the story of the run.

```bash
curl -X POST http://localhost:8787/vase -H "Origin: http://localhost" -H "Content-Type: application/json" -d "{\"summary\": {\"petrified_by_enemy\": {\"hoplite\": 3, \"leaper\": 1}, \"deaths\": 1, \"pools_used\": 2, \"level\": 2}}"
```

Success is `{"ok":true,"image":"<base64 png>","mime":"image/png"}`, a 768x1024 portrait image. What happens inside:

1. **Sanitize.** Only these fields are read, as whole numbers clamped to 0..99: `petrified_by_enemy.{hoplite, leaper, archer, mirror_bearer, perseus}` (or the `petrified` list if that is missing), `deaths`, `pools_used`, `level` (1..4), `counts.{hit, pit, reflect, statue_shattered}`. Everything else, including every string, is ignored. A body without a `summary` object gets 400 before a rate slot is used.
2. **Facts.** The numbers become short sentences made only of the Worker's own words ("Medusa turned three hoplite spearmen to stone. She fell once and rose again.").
3. **Text call.** The LLM turns the facts into one frieze description (at most about 50 words). Its system prompt forbids text, letters, numbers or inscriptions. The reply is stripped of digits and symbols and capped at 320 characters. If it is unusable or mentions writing (a sign, scroll, inscription, label...), a built-in description is used instead.
4. **Image call.** The image model paints the amphora: dark `#1A1410` background, terracotta `#C8643B` body, one frieze band of black-figure silhouettes, marble-white `#F2EFE8` statues, meander bands, no text.
5. **Letter check.** If the vision model sees any writing, the image is thrown away.

Cost reserved up front: `COST_TEXT_USD + COST_IMAGE_USD` ($0.072), plus `COST_VISION_USD` for the letter check. Any refusal or failure returns `{fallback:true}` (400, 413, 429 or 502), and the game shows its pre-made vase.

## 5. Change the cap, limit or costs 💰

Edit `[vars]` in `wrangler.toml`, then run `npx wrangler deploy` again.

| Var | Default | Meaning |
|---|---|---|
| `DAILY_CAP_USD` | `10` | Daily spend cap in USD, per UTC day. Over it, generations return 429 `{fallback:true}`. |
| `RATE_LIMIT_PER_HOUR` | `3` | Generation requests per IP per clock hour. |
| `COST_IMAGE_USD` | `0.07` | Estimate charged per image. |
| `COST_VISION_USD` | `0.002` | Estimate charged per letter check. |
| `COST_TEXT_USD` | `0.002` | Estimate charged per text call (the /vase description). |
| `ALLOWED_ORIGINS` | `https://*.itch.zone` | Comma-separated. `*.` allows any subdomain. |
| `LLM_MODEL`, `IMAGE_MODEL` | see file | Model IDs. |
| `MAX_BODY_BYTES` | `16384` | Largest accepted request body. |

Prices behind the estimates, checked Monday, November 02, 2026: Haiku 5.5 is $0.10 per million input tokens and $0.50 per million output tokens. Gemini 3.1 Flash Image is $0.045 per 512 px image and $0.067 per 1K image. The estimates round up on purpose.

To see today's spend, look up the key `spend:YYYY-MM-DD` in the KV namespace (Cloudflare dashboard > Storage > KV), or run:

```bash
npx wrangler kv key get --binding LIMITS --remote "spend:2026-11-02"
```

## 6. Confirm itch.io's iframe origin 🔍

itch.io runs HTML5 games inside an iframe on an `*.itch.zone` subdomain (normally `https://html-classic.itch.zone`). `*.itch.zone` is allowed by default. To check the real value:

1. Run `npx wrangler tail` while you play the uploaded build.
2. Rejected requests log one line: `rejected origin: <value>`.
3. If your game's origin shows up there, add it to `ALLOWED_ORIGINS` and redeploy.

## How the guards work

Every request goes through these steps, in this order:

1. **Origin allowlist.** Unknown origins get 403 and no CORS headers. The origin is logged. Nothing else is logged: no bodies, prompts or keys.
2. **CORS preflight.** `OPTIONS` requests get a 204 and don't count against the limits.
3. **Body limit.** Bodies over 16 KB get a 413.
4. **Per-IP rate limit.** The KV key is `rl:<hashed IP>:<hour>`. The IP is SHA-256 hashed, so raw addresses are never stored. Keys expire after 2 hours.
5. **Daily spend cap.** The estimated cost is added to `spend:<date>` **before** the provider call. A failed call stays counted, which errs on the safe side.

Every refusal or failure returns JSON `{fallback:true}`: 429 for the limit or cap, 403, 400 for a bad body, 413, or 502 for a provider error or an image with letters. The game treats all of them as "use the non-AI fallback."

**Caveats**

- The Origin check is a courtesy, not security. Anyone can fake it with curl. The real protection is the per-IP limit plus the daily cap.
- KV is not atomic. A burst of simultaneous requests can overshoot the limit or cap by a call or two, which is fine at jam scale.
- Gemini picks resolution in tiers (`512`, `1K`, `2K`). If it ever returns a larger image than asked, the game scales the sprite down.
