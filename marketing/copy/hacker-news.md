# Hacker News — Show HN

**Status:** needs your account. Post the text, attach nothing — HN prefers a link + comment.

- **Title:** `Show HN: BurnFuse – a spend breaker for AI API keys in your menu bar`
- **URL:** https://github.com/Ravinder82/burnfuse

## First comment (post immediately after submitting)

> Author here. I built this after waking up to a bill that one alert would have stopped.
>
> Some implementation notes, since HN usually asks:
>
> — It's native SwiftUI, no dependencies, no project file. The menu bar item is a real
> nonactivating panel, not a popover on an activating app — click it and it appears over
> what you're doing, on the Space you're on, without becoming the front app. There's a
> check in ./scripts/verify.sh that fails if showing the panel ever activates the app.
>
> — Cost reads: OpenAI, Anthropic and OpenRouter publish cost endpoints an admin key can
> read, so BurnFuse pulls the provider's own figure every minute. Two gotchas handled
> explicitly: count-up endpoints (running totals, not rates) take a baseline and show the
> first real hourly figure on the second read, saying so instead of inventing a number; and
> some endpoints return a total that isn't a rate at all, so the row says what it is.
>
> — Providers that publish nothing readable aren't hidden — the row names where the number
> lives and takes it from you. Thirty by name.
>
> — The breaker: you set a cap per key. Crossing it marks the key, logs the minute, sets
> the menu bar red, fires a notification and optional Slack/Discord webhook. With OpenAI
> and Anthropic the same admin key can also remove a key, so the trip offers that switch-off
> — labeled, second press. With OpenRouter the app says exactly what's missing (a management
> key) instead of failing with a 403.
>
> — No account, no telemetry, no server. Keys live in ~/.burnfuse/keys.json and are sent
> only to the provider you named. MIT.
>
> Happy to answer anything about the cost-endpoint quirks — that's where most of the work
> went.

## Notes

- Best windows: weekday 8–10 AM ET. Avoid Friday afternoon.
- If it gains traction, reply fast; HN threads punish drive-bys.
- Alternative if flagged: `Show HN: I made a macOS menu-bar breaker for runaway AI spend`.
