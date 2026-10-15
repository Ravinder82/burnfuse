<div align="center">

<img src="assets/icon_512.png" width="128" alt="BurnFuse app icon">

# burnfuse

**A spend breaker for your AI keys.**

Watch burn rate. Cap the damage. Cut the power before a runaway loop drains your card.

A real macOS app. Sits in your Dock and your menu bar.

[The app](#the-app) · [How it works](#how-it-works) · [Insights](#insights) · [Privacy](#privacy)

<img src="assets/social-card.png" alt="BurnFuse — a spend breaker for your AI keys, shown in one macOS window">

</div>

---

## The problem

A retry loop, a missing `try/catch`, a stuck job. It happens on a Friday night when
nobody is watching. Your AI provider keeps answering, the meter keeps running, and the
billing email shows up in the morning — hours after the money is gone.

BurnFuse watches the meter. When a key burns past the cap you set, or jumps far above
its normal rate, it **trips** — the key is marked and held before it can keep draining.

It is not a dashboard you have to remember to open. It lives in your menu bar as a
single colour block that reads at a glance — green when settled, amber as burn climbs,
red the moment the breaker trips. Click it and you get a miniature of the app: the same
live number, the same watch list, without leaving what you were doing.

The menu bar isn't a menu — it's the app, shrunk. Live burn, the trend, every watched key
and the one action that matters, all in one small panel:

<p align="center">
  <img src="assets/mini-panel-dark.png" width="300" alt="The BurnFuse menu-bar panel: a miniature of the app with live burn and watched keys">
  &nbsp;
  <img src="assets/mini-panel-breach-dark.png" width="300" alt="The BurnFuse menu-bar panel when a key has tripped">
</p>

And the colour block itself, in each state:

<p align="center">
  <img src="assets/menubar-dark.png" width="480" alt="BurnFuse in the macOS menu bar — green, settled">
  <br>
  <img src="assets/menubar-climbing-dark.png" width="480" alt="BurnFuse in the macOS menu bar — amber, climbing">
  <br>
  <img src="assets/menubar-breached-dark.png" width="480" alt="BurnFuse in the macOS menu bar — red, tripped">
</p>

## What it does

- **Shows the burn.** One number in your menu bar, in a colour block that reads at a glance: green when settled, amber as it climbs, red when tripped.
- **Catches the spike.** It learns each key's normal rate and trips when the rate jumps — even if you never set a cap.
- **Respects the cap.** Set an hourly ceiling per key. Cross it and the breaker trips.
- **Cuts the power.** One click pauses everything. Auto-cut is there for when you are asleep.
- **Tells you after.** Spending is only half the story. Insights shows what the breaker stopped.

## The app

BurnFuse is a single window. Everything lives behind the sidebar — your keys, what the
breaker saved, and how the app keeps itself current. No scattered windows, no submenus.

<p align="center">
  <img src="assets/window-overview-dark.png" width="720" alt="The BurnFuse window on Overview, showing live burn rate, trend and watched keys">
</p>

Light and dark follow the system:

<p align="center">
  <img src="assets/window-overview-light.png" width="720" alt="The BurnFuse window on Overview in light appearance">
</p>

### Keys

Add a key, give it an hourly cap, and choose whether it should auto-cut when it trips.

<p align="center">
  <img src="assets/window-settings-dark.png" width="600" alt="BurnFuse Settings showing per-key caps, live data, readings and sensitivity">
</p>

### Keeping it current

BurnFuse reads spend straight from your provider — no scripts, no terminal:

1. **Provider keys → OpenAI, OpenRouter.** Paste a read-only key. BurnFuse asks the
   provider's own cost endpoint every minute. Keys are stored on your Mac only,
   owner-readable, and are sent nowhere except that provider.
2. **Log a reading.** For any key — a provider without a public spend endpoint,
   or a number you read somewhere else — type what it is spending per hour. That
   is all a reading is: one dollar figure per hour.
3. **Custom endpoint.** Any URL that returns a dollar amount. Name where the
   figure sits in the JSON, and say whether it counts up.

A key you paste is checked before BurnFuse uses it: something that looks like a
standard OpenAI key instead of an Admin one, or an OpenAI key pasted into the
OpenRouter row, gets told to you where you typed it rather than failing silently
a minute later. A provider that has since moved its cost endpoint is tried at its
other address before BurnFuse will suggest anything is wrong.

Some providers count money up instead of reporting an hourly figure. Those need
two reads — the first saves a baseline, the next one gives you a rate — and the
app says so while it is measuring, rather than showing a number it cannot back up.

Providers without a live endpoint (Anthropic, Replicate, Groq, AWS) work fully
through a logged reading. The settings list says plainly which providers read
themselves and which need a number from you, so nothing is a dead end.

## How it works

Two rules, both easy to reason about:

1. **The cap.** You set `$5/hr`. Spend `$5.01` and the breaker trips.
2. **The spike.** BurnFuse keeps your recent hourly readings and works out your normal
   rate. A reading far above that trips the breaker on its own — so a key you never
   capped is still protected. The interface shows this as a multiple ("4× usual"), not a
   statistic.

You control how easily a key trips. Slide toward *Calm* to catch small jumps, or *Only
big* to hear from BurnFuse only when something is genuinely on fire.

A reading has to be both clearly abnormal *and* worth your attention. Quiet keys with
tiny numbers are not allowed to cry wolf.

When something trips, the window says so plainly and gives you the one action that matters:

<p align="center">
  <img src="assets/window-breach-dark.png" width="720" alt="The BurnFuse window with the breaker tripped, showing the one action that matters">
</p>

## Insights

What did the breaker actually save you? Insights adds it up — every trip, what it would
have cost, and the honest framing that billing emails arrive late.

<p align="center">
  <img src="assets/window-insights-dark.png" width="720" alt="BurnFuse Insights showing averted spend and the log of trips">
</p>

## Providers

| Provider | Live spend | How |
|---|---|---|
| OpenAI | ✅ | Organization costs API (needs an Admin key) |
| OpenRouter | ✅ | Reads your credit usage with a standard key |
| Custom endpoint | ✅ | Point it at any URL that returns a dollar amount |
| Anthropic · Replicate · Groq · AWS | — | Log a reading per hour |

Everything else in BurnFuse reads its spend from one number you type. The only
front-end BurnFuse provides to that is Settings → **Watch a key**, and the only
thing it asks for is a name and a dollar-an-hour cap.

## Install

### Requirements

macOS 14+ and the Xcode command line tools. No dependencies, no project file.

```bash
git clone https://github.com/Ravinder82/burnfuse.git
cd burnfuse
./scripts/install.sh
```

That builds BurnFuse, drops it in **/Applications**, and opens it. From then on it is a
normal macOS app — launch it from Launchpad, Spotlight (⌘-Space) or the Dock, no terminal
needed:

<p align="center">
  <img src="assets/icon_512.png" width="96" alt="BurnFuse app icon">
</p>

Prefer to do it by hand? Build the bundle and copy it wherever you like:

```bash
./scripts/build-app.sh
open macos/build/BurnFuse.app        # or drag it into /Applications
```

### Using it

BurnFuse opens to the full window — Overview, Insights and Settings behind the sidebar,
exactly like any other Mac app. It also keeps a live item in your menu bar:

- **Click the colour block** for a panel: live burn, the trend, every watched key.
- **Right-click it** for the quick actions: open the window, cut all power, quit.
- `⌘,` opens Settings, `⌘I` opens Insights, `⌘W` closes the window (BurnFuse keeps
  running in the menu bar; click the Dock icon to bring it back).

## Privacy

BurnFuse is built to be boring about your secrets.

- **Nothing leaves your machine.** No account, no analytics, no telemetry, no server of ours.
- **Your keys stay local.** Provider keys live in `~/.burnfuse/keys.json`, owner-readable,
  and are sent only to the provider you named, over TLS. Nothing is proxied anywhere.
- **One file holds your data.** `~/.burnfuse/state.json` is the whole product's memory:
  your keys, their readings, and every trip. Delete it and BurnFuse forgets everything.

## Design

Native SwiftUI, following Apple's Human Interface Guidelines: semantic system colours
that respect light and dark, real Dynamic Type, status conveyed by icon *and* colour,
and motion that yields to Reduce Motion.

Every image in this README is a render of the shipping UI — see
[`scripts/screenshots.sh`](scripts/screenshots.sh).

## Development

```bash
./scripts/verify.sh               # tests + app build + launch smoke test
./scripts/build-app.sh            # build the app bundle
./scripts/build-app.sh debug      # faster debug build
./scripts/install.sh              # build + install into /Applications + launch
./scripts/package.sh              # build a double-clickable BurnFuse.dmg
./scripts/screenshots.sh          # regenerate the README and marketing images
```

Tests individually:

```bash
swift test --package-path macos   # burn engine + app model + state contract
```

Run the app from source:

```bash
swift run --package-path macos BurnFuse
```

Layout:

```
macos/               Swift package: the app
  Sources/BurnFuse/       entry point, menu-bar item
  Sources/BurnFuseUI/     window, panel, design system, burn engine, live spend
  Sources/burnfuse-shots/ icon + screenshot + marketing renderer
scripts/             build, install, package, verify and screenshot scripts
assets/              app icon, window screenshots and the marketing card
```

> Building under `~/Desktop` or `~/Documents`? Those folders are iCloud-synced, and
> iCloud writing to build artifacts mid-build makes SwiftPM fail intermittently. The
> scripts already build into `~/Library/Caches/burnfuse-build` to avoid it. Override with
> `BURNFUSE_SCRATCH` if you want it somewhere else.

## License

[MIT](LICENSE) © Ravinder Poonia

<div align="center">
<sub>Built to be quiet, honest, and right the one time it matters.</sub>
</div>