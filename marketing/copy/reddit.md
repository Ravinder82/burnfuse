# Reddit

**Status:** needs your account. Check each sub's current self-promo rules before posting —
some require flair or specific days. Post one sub per day, not all at once. Reply to every
comment with specifics, never with the link again.

---

## r/macapps

**Flair:** usually "Promotion" required.

**Title:** `BurnFuse — a menu-bar spend breaker for AI API keys (native SwiftUI, MIT, no account)`

**Body:**
> I built the thing I wanted after a runaway job cost me a night's sleep: a menu-bar item
> that is one colour block — green settled, amber climbing, red tripped — with the live
> burn rate inside.
>
> Click it and a real nonactivating panel drops over what you're doing (it doesn't activate
> the app or switch Spaces). No account, no telemetry, no server: keys live in
> ~/.burnfuse/keys.json, readable by you alone.
>
> It reads the provider's own cost figure every minute for OpenAI / Anthropic / OpenRouter
> (or any endpoint of your own), and where a provider publishes nothing readable, the row
> says so and takes the number from you — 30 providers by name, no dead ends.
>
> The breaker part: set a cap per key; when it trips you get menu-bar red, a notification
> and an optional Slack/Discord webhook inside a minute — not a morning dashboard. At
> OpenAI/Anthropic the trip also offers to disable the key itself (second press).
>
> macOS 14+, MIT. github.com/Ravinder82/burnfuse — DMG on the releases page.
>
> Feedback welcome, especially on the panel behaviour and what else you'd want watched.

---

## r/SideProject

**Title:** `I built a spend breaker for AI API keys — green/amber/red in your Mac's menu bar`

**Body:**
> Solo build, ~all of it native SwiftUI. The insight I kept coming back to: every spend tool
> is a dashboard, but what I needed at 2 AM was a breaker. Dashboards tell you yesterday.
>
> So: one colour block in the menu bar. Green settled, amber climbing, red tripped. It reads
> your provider's own cost figure every minute, caps per key, and tells you inside a minute
> when something trips — with a one-press switch-off at OpenAI/Anthropic.
>
> Local-first: no account, no telemetry, no server. MIT.
> github.com/Ravinder82/burnfuse
>
> Would love feedback from other builders — particularly what would make you trust a number
> like this: I ended up refusing to show anything it hasn't measured ("no reading yet"
> instead of $0.00). Thoughts?

---

## r/LLMDevs

**Title:** `Show: menu-bar spend breaker for LLM API keys — reads provider cost endpoints every minute`

**Body:**
> If you run agents/loops overnight, the failure mode is real: a runaway loop is a token
> count before it is a bill. I built a small macOS app that watches the cost endpoints your
> key already can read (OpenAI, Anthropic, OpenRouter admin keys, or your own endpoint) and
> trips a per-key cap.
>
> The interesting engineering bits: distinguishing running-total endpoints from rate
> endpoints and taking a baseline for the former ("working it out" instead of inventing a
> number); treating admin vs project keys honestly; showing "no reading yet" rather than
> $0.00; and only claiming switch-off where the API can actually do it (OpenAI, Anthropic),
> pointing at the console where it can't.
>
> Token counts (in/out/cached, same day as the dollars) are shown where the provider
> reports them, so you can see a loop in tokens before it reaches dollars.
>
> MIT, no account/telemetry. github.com/Ravinder82/burnfuse — happy to go deep on the
> endpoint quirks in the comments.

---

## r/LocalLLaMA — optional, read rules first

**Title:** `Made a local-only macOS spend watcher for API keys (no account, no telemetry, no server)`

**Body:**
> Not a local-inference tool, but this community is the strictest about data hygiene, so I
> figure you'd want to know: it's a native macOS menu-bar app that watches API spend (for
> the hosted endpoints you use alongside local models). Keys live in one file on your Mac
> (~/.burnfuse/keys.json readable by you alone), sent only to the provider you named. No
> analytics, nothing proxied. MIT.
>
> Reads provider cost endpoints every minute where allowed; where a provider publishes
> nothing readable it says so and takes the number from you — 30 providers by name.
>
> github.com/Ravinder82/burnfuse

---

## r/ClaudeAI and r/OpenAI — optional, rules vary

Use the r/LLMDevs body trimmed to 3 lines + link. These subs often restrict promotion;
post only as a comment in relevant "how do you track spend" threads if a direct post is
not allowed.
