# BurnFuse marketing kit

Every asset here is rendered from the shipping SwiftUI views by
[`scripts/screenshots.sh`](scripts/screenshots.sh), so the marketing can never drift
from the product. Run `./scripts/screenshots.sh` to regenerate the whole set.

## Assets

| File | Size | Use |
|---|---|---|
| `assets/icon_1024.png` | 1024×1024 | App Store / store listing, press kit |
| `assets/icon_512.png` | 512×512 | README header, GitHub social preview |
| `assets/social-card.png` | 1200×630 | Social cards, Product Hunt, README hero |
| `assets/menubar-dark.png` | 640×34 | Menu-bar item, settled (green) |
| `assets/menubar-climbing-dark.png` | 640×34 | Menu-bar item, climbing (amber) |
| `assets/menubar-breached-dark.png` | 640×34 | Menu-bar item, tripped (red) |
| `assets/menubar-light.png` | 640×34 | Menu-bar item in light appearance |
| `assets/mini-panel-dark.png` | 320 wide | The menu-bar panel, healthy |
| `assets/mini-panel-breach-dark.png` | 320 wide | The menu-bar panel, tripped |
| `assets/window-overview-dark.png` | 900×930 | Primary product shot — README, landing page |
| `assets/window-overview-light.png` | 900×930 | Light-mode shot |
| `assets/window-breach-dark.png` | 900×1010 | "The moment it matters" — the trip |
| `assets/window-insights-dark.png` | 900×581 | What the trips were on track to spend |
| `assets/window-settings-dark.png` | 900×1180 | Feature shot — one list of keys, each saying how its number gets in |
| `assets/window-settings-light.png` | 900×1180 | Light-mode feature shot |
| `assets/window-switchoff-dark.png` | 900×1300 | Switching a key off at the provider, from the key's own row |

## Where each one is used

- **README** — icon, social card, the colour-coded menu bar, the panel, and the window shots, in context.
- **Social / Product Hunt** — `social-card.png` (1200×630 is the standard card ratio).
- **Press kit** — `icon_1024.png` plus the window shots.
- **App Store** — `icon_1024.png` for the listing icon.
- **Menu-bar colour** — the three menu-bar items show one product idea in three states;
  use them together to explain the at-a-glance colour in a single image.

## One line

> **BurnFuse — a spend breaker for your AI keys.** Watch the burn rate. Cap the damage.
> Know within a minute, not in the morning.

## Three lines

- It lives in your menu bar as a colour block: green when settled, amber as burn climbs,
  red when a breaker trips — the number is inside.
- Click it and you get a miniature of the app — live burn, the trend, every watched key —
  without leaving what you were doing.
- Native macOS, everything on your Mac. No account, no telemetry, no server.
- It tells you inside a minute, and it is exact about what it can do next: where the
  provider lets the key it already holds switch a key off (OpenAI, Anthropic), the trip
  offers to do it, with a second press; everywhere else it names the console page, because
  that is what stops the spend.

## What to lead with

- **"The key you already use is the key it watches."** Paste one key and BurnFuse names
  the provider from the shape of the key itself, files it under what you use it for, and
  says in one line what it will be able to do — before anything is saved. No second key to
  create, no list to reconcile, nothing to register first.
- **"Every row says where its number comes from."** *Reads itself* — BurnFuse pulls the
  provider's own cost figure every minute (OpenAI, Anthropic, OpenRouter, or any endpoint
  of your own). *You type it* — that provider publishes no cost figure a key can read, so
  the row says so plainly, names where the number lives, and takes it. Thirty providers by
  name across coding, images, video, voice, scraping and hosting, and not one of them is a
  dead end.
- **"It reads the number itself."** Paste a read-only key for OpenAI, Anthropic or
  OpenRouter and BurnFuse pulls spend from the provider's own cost endpoint every minute.
  No scripts, no terminal, no pasting a number by hand every hour.
- **"A glance costs you nothing."** The menu-bar panel is a real nonactivating panel, not
  a popover bolted to an activating app: click the item and it appears over what you are
  doing, on the Space you are on, without becoming the front app and without dragging the
  BurnFuse window over your work. The window opens only when you ask for it. Verify it
  yourself — `./scripts/verify.sh` includes a check that fails if showing the panel so
  much as activates the app.
- **"A no is explained where you typed it."** If OpenAI turns a standard project key down
  for cost reads, the same row offers the way out in place — type this key's spend by hand
  instead — instead of sending you to a second list that never worked for you anyway.
- **"It never blames the wrong key."** A shell variable holding the sample value from a
  quick-start file is named and ignored rather than sent, and a key saved in the app is
  the one used whatever the environment says. So when a provider does say "this key is not
  valid", it is talking about a key that was really sent — the only kind of error message
  worth acting on.
- **"Press Test and know now."** A key you paste can be tried against the provider on the
  spot — before you commit to saving it. It says what came back in plain words, and a
  read-only test never moves a burn figure. Each stored key shows only its two ends, so
  you can tell which one is in there.
- **"It tells you the two things that break a key."** The row that takes your OpenAI key
  knows the difference between an Admin key and a standard project key, and says so where
  you typed it — before a failing read a minute later. Anthropic says out loud that only
  an organization account has an Admin API at all. A provider that has moved its cost
  endpoint is tried at its other address before BurnFuse blames anything.
- **"It never shows a zero it has not measured."** A key whose spend has never been read or
  typed says *no reading yet* rather than `$0.00/hr`. Small thing, but it is the same rule
  as everywhere else in the app: the number on screen means what it says.
- **"Count-up providers tell you they are measuring."** Some endpoints return a running
  total rather than a rate, so BurnFuse takes a baseline and shows your first real hourly
  figure on the second read, saying so while it works it out instead of inventing a number.
- **"It tells you what it cannot do — and does the rest."** The hardest claim to make in
  this category, and the one worth leading with to anyone technical: reading spend and
  disabling a key are different permissions, and BurnFuse is exact about which it has. With
  OpenAI and Anthropic the cost report is Admin-only and the same Admin key can list the
  account's keys and remove one, so the trip banner offers it directly — and labels the key
  the readings come from before you touch it. With OpenRouter, changing keys needs a
  management key, so the app says exactly that and points at the console instead of failing
  with a 403. No other spend watcher is that specific about its own limits, and it is the
  reason to trust the number it does report.
- **"It shows why, not just how fast."** Overview counts today's input, output and cached
  tokens where the provider reports them — OpenAI and Anthropic, over the same day the
  dollars cover — and says *"about $2.56 per million tokens, from today's $15.90 on the keys
  these counts came from"* instead of quoting a price list. A runaway loop is a token count
  before it is a bill.
- **"One glance tells you whose key it is."** Keys are grouped by what you use them for,
  and every row leads with its provider's own tile — the same square for every key from
  that provider, a different colour from the next. Colour never carries the fact alone; the
  provider's name sits beside it.