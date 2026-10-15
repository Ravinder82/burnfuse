# BurnFuse marketing kit

Everything here is marketing: the long-form pitch, the provider detail, the copy blocks and
the asset inventory. The [README](README.md) carries only what someone needs to decide,
install and run the app — everything else that used to live there lives here now.

Every asset is rendered from the shipping SwiftUI views by
[`scripts/screenshots.sh`](scripts/screenshots.sh), so the marketing can never drift from
the product. Run `./scripts/screenshots.sh` to regenerate the whole set.

---

## The story

A retry loop, a missing `try/catch`, a stuck job. It happens on a Friday night when
nobody is watching. Your AI provider keeps answering, the meter keeps running, and the
billing email shows up in the morning — hours after the money is gone.

BurnFuse watches the meter. When a key burns past the cap you set, or jumps far above
its normal rate, it **trips**: the key is marked, the minute is logged, and you are told
— menu bar red, a notification, and a webhook if you added one. Hearing about it in a
minute instead of in the morning is the whole product.

It is not a dashboard you have to remember to open. It lives in your menu bar as a
single colour block that reads at a glance — green when settled, amber as burn climbs,
red the moment the breaker trips. Click it and you get a miniature of the app: the same
live number, the same watch list, without leaving what you were doing.

The menu bar isn't a menu — it's the app, shrunk. Live burn, the trend, every watched provider
and the one action that matters, all in one small panel. It opens as a panel that does not
take your focus: clicking the item shows the burn over whatever you are doing, without
activating BurnFuse and without pulling its window in front of your work. Nothing moves
except the panel — the app opens only when you ask it to, from the panel's own
**Open BurnFuse**.

<p align="center">
  <img src="assets/mini-panel-dark.png" width="300" alt="The BurnFuse menu-bar panel: a miniature of the app with live burn and watched providers">
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

- **Shows the burn.** One colour block in your menu bar that reads at a glance: green when
  settled, amber as it climbs, red when tripped — the number is inside.
- **Uses the key you already have.** You create the providers you watch, paste the key you
  already use, and BurnFuse watches that same key — no second key to create, no list to
  reconcile, nothing to register first. Where a provider needs a particular *kind* of key to
  read spend, the row says so in one line instead of leaving you to guess.
- **Shows what the tokens say.** Where a provider counts them (OpenAI and Anthropic do),
  Overview reads today's input, output and cached tokens next to the dollars — because a
  runaway loop is a token count before it is a bill.
- **Catches the spike.** It learns each key's normal rate and trips when the rate jumps —
  even if you never set a cap.
- **Respects the cap.** Set an hourly ceiling per provider. Cross it and the breaker trips.
- **Tells you inside a minute.** Menu bar red, a desktop notification, and — if you add one
  — a Slack or Discord ping. Not a billing email you read tomorrow.
- **Switches a key off, where it is allowed to.** Reading spend and disabling a key are
  different permissions, and BurnFuse is exact about which it has. OpenAI and Anthropic hand
  out the key list to the same Admin key the cost read needs, so there the app can delete a
  key or set it inactive, with a second press first. Anywhere else it says why not and names
  the console page instead of pretending.
- **States its own limits.** It never claims to have cut a key it cannot cut, and it never
  claims a key is stopped until the provider says so.
- **Tells you after.** Spending is only half the story. Insights shows every trip and what
  it was on track to spend.

## Your providers

**Settings holds the providers you created, and every one of them is yours.** There is no
catalogue to pick from and no list of providers to learn first — you name one, paste the key
you already use, and say which pile its spend belongs to. The add-a-provider form sits at
the foot of the list.

Keys are grouped under the thing you use them for — *Coding & chat*, *Images*, *Video* — and
inside a group every provider is its own card, so a provider is a thing you can look at
rather than a line in a form. Each card leads with the letters of the name you gave it, in
that name's own colour, so *OpenAI prod* and *OpenAI test* are two different squares rather
than one, and so is everyone else. The category is a menu on the card, so a provider filed
in the wrong group can be moved without re-adding it; colour never carries the meaning on
its own, and the name is always written beside its tile.

Everything else is worked out from what you gave, in order of how loud it is:

1. **An address you gave** — one explicit instruction, so it wins: the provider reads from
   that address rather than from whatever the key looks like.
2. **The shape of the key you pasted** — `sk-or-…` is OpenRouter, `sk-ant-…` is Anthropic,
   and BurnFuse says what it is, files it under what you use it for, and tells you in one
   line what it will be able to do *before anything is saved*.
3. **The name you gave it** — BurnFuse knows about thirty providers by name, so typing
   *fal* tells it where fal's number lives, which pile it belongs in, and where the key is
   revoked, even when the key itself says nothing. Nothing lists those names: it is
   knowledge the app consults, not a menu you read.

The name is the row's identity — the thing trips, notifications and the watch list call the
provider by. The form shows a default from what it recognised (or from the address's host,
or *New provider*), numbered when the name is taken: *OpenRouter*, then *OpenRouter 2*.

A finished row says where its own number comes from:

| On the row | What it means |
|---|---|
| **reads itself** | BurnFuse reads a dollar figure every minute — from the provider's own cost API where it has one, or from an address you gave |
| **you type it** | Nothing can be read there, so the row takes a number from you and names where to read it |

A pasted key is kept with the provider you made: it is what reads the provider the moment an
address exists, and removing the provider removes the key it was using. Any provider can be
pointed at an address of your own — your own script, a cloud billing export, a page behind a
token — and then it reads itself, every minute, with the same key you already pasted.

<p align="center">
  <img src="assets/window-settings-dark.png" width="600" alt="BurnFuse Settings: your providers grouped by category, one card each leading with the letters of its own name, saying how its spend arrives, with the add-a-provider form below and a recognised key pasted">
</p>

### Tokens

The burn figure says how fast the money is going. The tokens card says **why**: models are
priced per token and differ by orders of magnitude, so "$9.90/hr" becomes something you can
act on the moment it reads next to "it pushed four million tokens".

Today's input, output and cached tokens, where the provider reports them — OpenAI and
Anthropic do, with the same Admin key the cost read already uses, over the same day the
dollars cover. A few things it is careful about:

- **Cached is a part of In, not an addition to it.** Input counts every input token; the
  cached figure is the slice that was served from the provider's cache, and the card says so
  rather than letting the three numbers look like they should add up.
- **The day is the provider's day** — midnight to midnight UTC, the same hours its bill
  covers — and a figure from yesterday is never shown under today's heading.
- **Only real numbers.** Nothing is estimated from a price list: a provider that publishes
  no token counts shows none. OpenRouter reports credits rather than tokens, so its keys
  have no counts and the card says exactly that.
- **One derived figure, and it says where it came from:** today's spend on the keys that
  reported, divided by what they used — *about $2.56 per million tokens* — an average over
  whatever mix of models actually ran, written as an average.

Each watched key shows its own line in the watch list (*47L in · 1.8L out today*), so a key
that is feeding tokens in is visible without opening anything. Token counts are the one
number here that follows your Mac's own number style.

### Keeping it current

BurnFuse gets a provider's spend one of three ways, and the row always says which:

1. **It reads itself.** A key BurnFuse recognises is read at the provider's own cost
   endpoint. OpenRouter answers a standard key with its own credit usage; OpenAI and
   Anthropic answer with your organization's costs, which their cost APIs accept only from
   an Admin key — the row says so in one line. That same Admin key is also the one that can
   list the account's keys and switch one off, which is why those two rows can revoke as
   well as read (see [what a trip cannot do](#what-a-trip-cannot-do)). A failed read gives
   the provider's own reason rather than a status code: a standard OpenAI key instead of an
   Admin one, or an OpenAI key pasted into the OpenRouter provider, is named where you typed
   it rather than failing silently a minute later. A value that is really the placeholder
   from a sample file is called out as one. Keys are stored on your Mac only, owner-readable,
   and are sent nowhere except that provider, or the address you pointed it at; the row shows
   just the two ends of the key (`sk-o…0000`), so you can tell which one is stored without
   it being usable. **Test** asks the provider right then, instead of waiting a minute to
   find out.
2. **You type it.** Most providers publish no spend figure at all. Their rows say so in
   plain words and take a number from you — what that provider is spending per hour. That is
   all a reading is: one dollar figure per hour. A typed row is a first-class way to use the
   app, not a failure state.
3. **Your own endpoint.** Any URL that returns a dollar amount. Name where the figure sits
   in the JSON, how to send the key, and whether it counts up.

If a provider turns the key down for cost reads — the common case being a standard OpenAI
key, which can use the API but cannot see spend — the same row offers the way out in place:
**Type this key's spend by hand instead**. The provider stays watched either way; only where
the number comes from changes. And a key you have never pasted is never reported as invalid:
the app says it has nothing to read with, which is a different problem from a key that was
turned down. Saving an empty field will not quietly delete a key you already have — removing
one is its own button, on purpose.

A key you paste into a provider is the one BurnFuse uses, full stop. If a variable of the
same name exists in the shell that launched the app, the saved key wins and the row says
what it is ignoring; a variable holding the stand-in from a sample file is named and ignored
rather than sent. That matters because a shell can be lying around for months: a 401 from a
provider is always about a key that was really sent.

Some providers count money up instead of reporting an hourly figure. Those need two reads —
the first saves a baseline, the next one gives you a rate — and the app says so while it is
measuring, rather than showing a number it cannot back up.

A provider whose spend has never been measured shows **no reading yet** rather than
`$0.00/hr`. Printing a zero it has not measured would be telling you something it does not
know.

## What a trip cannot do

Worth being exact about, because "spend breaker" suggests more than any watcher can do:

| On a trip | |
|---|---|
| Marks the key, logs the minute, shows it in the list | yes |
| Menu bar red, desktop notification, optional Slack/Discord ping | yes |
| Stops reading the key, if you asked it to | yes — the number freezes as evidence |
| Switches the key off at OpenAI or Anthropic | **yes** — where the app already holds the Admin key those accounts require |
| Switches a key off anywhere else | **no** — and it says why, and where, rather than implying otherwise |

The distinction is real and the app is built around it. Reading a cost figure and disabling
a credential are different permissions, and BurnFuse can only do the second where the
provider puts both behind one key:

- **OpenAI and Anthropic.** Your organisation's cost report is Admin-only, and the same
  Admin key can list the account's keys and remove one. So the trip banner offers it
  directly — **Switch a key off at OpenAI…** — and Settings has it on every provider's row.
  The panel shows your keys exactly as the provider describes them (name plus the provider's
  own redaction, `sk-admin…3H6`), labels the one the readings come from, and asks for a
  second press before anything happens.
- **OpenRouter.** Changing keys needs a *management* key, and BurnFuse reads with an
  ordinary one. So the panel says exactly that, and points at *OpenRouter → Settings → Keys*
  instead of failing with a 403. What it can read is OpenRouter's own ceiling on the key —
  *"the provider caps this key at $6.50, and it is spent"* — which is the fact that answers
  "can this key still spend?" without anybody's help.
- **Everyone else.** There is no such endpoint, so the console is the only door, and the row
  names the page: *Replicate → Account → API tokens*, *ElevenLabs → Profile → API keys*,
  *OpenRouter → Settings → Keys*, and so on.

Two things it will never do: offer a switch-off its credential cannot perform, and claim a
key is stopped before the provider has said so. And if you switch off the very key BurnFuse
reads with, it tells you in that row, because the readings stop with it.

The money is saved when the key is switched off. BurnFuse's job is to make that happen in a
minute rather than tomorrow morning.

<p align="center">
  <img src="assets/window-switchoff-dark.png" width="720" alt="BurnFuse Settings with the switch-off panel open: the account's OpenAI keys, each with the provider's own redaction, and the key BurnFuse reads with labelled">
</p>

## Insights

What did the breaker actually save you? Insights adds up what each trip was on track to
spend — the rate it tripped at, held for the next four hours — and frames it as an estimate
rather than money in the bank. The honest framing that billing emails arrive late is the
reason the app exists.

<p align="center">
  <img src="assets/window-insights-dark.png" width="720" alt="BurnFuse Insights showing what each trip was on track to spend, and the log of trips">
</p>

## What the app knows

Categories are how the app talks about your spend: the bands your providers appear under,
and the breakdown on Overview — *Coding & chat $1.94/hr · Images $0.51/hr*. They organise;
they never decide what BurnFuse can read. That is a fact about the provider, and the
provider says it in one line.

Nothing lists the providers below — you create your own in Settings, and this is the
knowledge used behind the scenes when a key's shape or a name tells the app something
useful:

| Category | Reads itself | You type it |
|---|---|---|
| Coding & chat | OpenAI · Anthropic | Google Gemini · xAI · Mistral · DeepSeek · Groq · Together · Fireworks · Perplexity |
| Images | — | Stability AI · fal.ai |
| Video | — | Runway · Luma |
| Voice & audio | — | ElevenLabs · Deepgram |
| Scraping & search | — | Firecrawl · Apify · Browserbase · Exa · Tavily |
| Hosting & storage | — | AWS · Google Cloud · Azure · Cloudflare · Vercel · Supabase |
| Model aggregators | OpenRouter | Replicate · Hugging Face |
| Something else | Your own endpoint | any provider — name it and type its spend |

That is thirty providers by name, and BurnFuse can read spend for three of them — plus any
endpoint of your own. The rest genuinely publish no cost figure that a key can read, and
no amount of wanting changes that. So each row says so, names where the number lives
instead, and takes it. Nothing here is ever a dead end, and none of it is a list anybody has
to read.

The same rule runs through everything else the app can do. Token counts are read where a
provider counts them (OpenAI and Anthropic) and nowhere else; disabling a key is offered
where the provider's own API allows the key BurnFuse holds to do it (OpenAI and Anthropic),
and explained everywhere else. What the app can do at a provider is a fact about that
provider, and each row says it in one line.

## Design

Native SwiftUI, following Apple's Human Interface Guidelines: semantic system colours that
respect light and dark, real Dynamic Type, status conveyed by icon *and* colour, and motion
that yields to Reduce Motion.

The mark is the app's own idea drawn in the app's own colours: the filament of a fuse that
has just given way — calm green at the tail, climbing amber, and the red past the break —
with the spark the break throws. Like everything else here it is drawn from shapes rather
than shipped as an image, so the Dock icon, the mark in the sidebar, the menu-bar panel and
the marketing card are one drawing at different sizes, and cannot drift apart.

Every image in this kit and in the README is a render of the shipping UI — see
[`scripts/screenshots.sh`](scripts/screenshots.sh).

## Assets

All renders are @2x (retina), so each is twice the point size shown.

| File | Size | Use |
|---|---|---|
| `assets/icon_1024.png` | 1024×1024 | App Store / store listing, press kit |
| `assets/icon_512.png` | 512×512 | README header, GitHub social preview |
| `assets/social-card.png` | 1200×630 | Social cards, Product Hunt, README hero |
| `assets/menubar-dark.png` | 640×34 | Menu-bar item, settled (green) |
| `assets/menubar-climbing-dark.png` | 640×34 | Menu-bar item, climbing (amber) |
| `assets/menubar-breached-dark.png` | 640×34 | Menu-bar item, tripped (red) |
| `assets/menubar-light.png` | 640×34 | Menu-bar item in light appearance |
| `assets/mini-panel-dark.png` | 324×397 | The menu-bar panel, healthy |
| `assets/mini-panel-breach-dark.png` | 324×425 | The menu-bar panel, tripped |
| `assets/window-overview-dark.png` | 900×884 | Primary product shot — README, landing page |
| `assets/window-overview-light.png` | 900×884 | Light-mode shot |
| `assets/window-breach-dark.png` | 900×1024 | "The moment it matters" — the trip |
| `assets/window-insights-dark.png` | 900×581 | What the trips were on track to spend |
| `assets/window-settings-dark.png` | 900×1323 | Feature shot — your providers, each saying how its number gets in, with the add form |
| `assets/window-settings-light.png` | 900×1323 | Light-mode feature shot |
| `assets/window-switchoff-dark.png` | 900×1527 | Switching a key off at the provider, from the provider's own row |

## Where each one is used

- **README** — icon, social card, the window shots on Overview, the panel, and the trip and
  switch-off shots in context.
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
- Click it and you get a miniature of the app — live burn, the trend, every watched provider
  — without leaving what you were doing.
- Native macOS, everything on your Mac. No account, no telemetry, no server.
- It tells you inside a minute, and it is exact about what it can do next: where the
  provider lets the key it already holds switch a key off (OpenAI, Anthropic), the trip
  offers to do it, with a second press; everywhere else it names the console page, because
  that is what stops the spend.

## What to lead with

- **"You create your own providers."** There is no catalogue to pick from and no list to
  learn first: you name one, paste the key you already use, and say which pile its spend
  belongs to. BurnFuse works out the rest — what the key is, where its number lives, whether
  it can be read at all — and says it in one line before anything is saved. You can add any
  key for anything, and the screen holds only what you made.
- **"The key you already use is the key it watches."** Paste it once and BurnFuse names the
  provider from the shape of the key itself, files it under what you use it for, and says in
  one line what it will be able to do — before anything is saved. No second key to create, no
  list to reconcile, nothing to register first.
- **"Every row says where its number comes from."** *Reads itself* — BurnFuse pulls the
  provider's own cost figure every minute (OpenAI, Anthropic, OpenRouter, or any address of
  your own). *You type it* — that provider publishes no cost figure a key can read, so the
  row says so plainly, names where the number lives, and takes it. Thirty providers by name
  across eight piles — coding, images, video, voice, scraping, hosting, aggregators and
  something else — and not one of them is a dead end.
- **"It reads the number itself."** Paste a read-only key for OpenAI, Anthropic or
  OpenRouter and BurnFuse pulls spend from the provider's own cost endpoint every minute. No
  scripts, no terminal, no pasting a number by hand every hour.
- **"A glance costs you nothing."** The menu-bar panel is a real nonactivating panel, not a
  popover bolted to an activating app: click the item and it appears over what you are doing,
  on the Space you are on, without becoming the front app and without dragging the BurnFuse
  window over your work. The window opens only when you ask for it. Verify it yourself —
  `./scripts/verify.sh` includes a check that fails if showing the panel so much as activates
  the app.
- **"A no is explained where you typed it."** If OpenAI turns a standard project key down
  for cost reads, the same row offers the way out in place — type this key's spend by hand
  instead — instead of sending you to a second list that never worked for you anyway.
- **"It never blames the wrong key."** A shell variable holding the sample value from a
  quick-start file is named and ignored rather than sent, and a key saved in the app is the
  one used whatever the environment says. So when a provider does say "this key is not
  valid", it is talking about a key that was really sent — the only kind of error message
  worth acting on.
- **"Press Test and know now."** A key you paste can be tried against the provider on the
  spot — before you commit to saving it. It says what came back in plain words, and a
  read-only test never moves a burn figure. Each stored key shows only its two ends, so you
  can tell which one is in there.
- **"It tells you the two things that break a key."** The row that takes your OpenAI key
  knows the difference between an Admin key and a standard project key, and says so where you
  typed it — before a failing read a minute later. Anthropic says out loud that only an
  organization account has an Admin API at all. A provider that has moved its cost endpoint
  is tried at its other address before BurnFuse blames anything.
- **"It never shows a zero it has not measured."** A key whose spend has never been read or
  typed says *no reading yet* rather than `$0.00/hr`. Small thing, but it is the same rule as
  everywhere else in the app: the number on screen means what it says.
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
- **"One glance tells you whose provider it is."** Providers are grouped by what you use
  them for, and every card leads with the letters of the name you gave it — *OP* for *OpenAI
  prod*, *CB* for *Claude batch* — in that name's own colour, so two providers of even the
  same kind are two different squares. Colour never carries the fact alone; the name sits
  beside it.
