# Directory submissions & long-tail

One blurb, many doors. Copy-paste kit below, then per-site notes.

## The blurb

**Short (1–2 lines):**
> BurnFuse — a spend breaker for your AI keys. One colour block in the macOS menu bar;
> reads the provider's own cost figure every minute and trips your cap inside one.

**Medium (a paragraph):**
> BurnFuse lives in the macOS menu bar as a colour block: green settled, amber climbing,
> red tripped — with the live burn rate inside. It reads the provider's own cost figure
> every minute for OpenAI, Anthropic, OpenRouter or your own endpoint, and where a provider
> publishes nothing readable, the row names where the number lives and takes it from you —
> thirty providers, no dead ends. When a key trips a cap you set, you hear about it inside a
> minute: menu bar, notification, optional Slack/Discord webhook, and — at OpenAI and
> Anthropic — a one-press switch-off through the provider's own API. No account, no
> telemetry, no server. Keys live in ~/.burnfuse/keys.json. Native SwiftUI, macOS 14+, MIT.

**Tags:** macOS, menu bar, AI, API costs, spend monitoring, developer tools, SwiftUI, open source

---

## Direct submissions (manual, need your account)

| Site | What to submit | Notes |
|---|---|---|
| AlternativeTo | App listing, alt to "OpenAI API cost dashboards" | alt-to slots: Dashboards → "API cost monitors" |
| MacUpdate | App listing (needs the DMG + screenshots) | use `stills/out/launch-16x9.png`, states, trip-flow |
| Uneed | Launch card (name, tagline, icon, URL) | daily launch list; free queue |
| Peerlist Launchpad | Launch post | reuses PH copy |
| MicroLaunch | Launch card | reuses PH copy |
| Indie Hackers | Product page + milestone post "Launch day numbers" | post milestone after 48h |
| BetaList | Queue submission | for early adopters; optional |
| Softpedia Mac | Submit for review | needs the DMG |
| Product Hunt | see `copy/product-hunt.md` | schedule the day |
| Lobsters | link post to the repo, tag `macos`/`release` | invite-only; needs your account |

## PRs / lists (link additions only)

- `awesome-mac` (jaywcjlove) — "Developer Utilities" or "Menu Bar Tools"
- `awesome-macos` (iCHAIT) — "Utilities"
- `awesome-openai` style lists — "Monitoring & cost tracking" where such a section exists
- Raycast/Homebrew taps: only if there is a brew formula/cask — don't invent one.

## dev.to / Hashnode article (outline)

**Title:** `I built a smoke detector for AI API spend — here is what the cost endpoints actually do`

Hooks: the overnight run that motivated it; the three kinds of cost endpoints (rate,
running total, none-readable) and what honest UI means for each; why "no reading yet" beats
$0.00; how the trip works (and the switch-off permissions that differ per provider); the
local-only architecture. End with the repo link.

Publish on dev.to AND Hashnode (cross-post), canonical URL to dev.to.

## Newsletters (email, low volume)

- **TLDR** (tldr.tech) — tip by email, one line + link.
- **Swift Weekly** — submit PR to their list or email; frame as "native SwiftUI, no deps".
- **iOS Dev Weekly** — "industry news" submission form.
- **MacStories / 9to5Mac tips** — email a 2-line pitch: menu-bar app, MIT, local-only,
  reads provider cost endpoints; offer the DMG + screenshots.

## YouTube & Instagram

See `copy/youtube-instagram.md`.
