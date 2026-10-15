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
| `assets/mini-panel-dark.png` | 300 wide | The menu-bar panel, healthy |
| `assets/mini-panel-breach-dark.png` | 300 wide | The menu-bar panel, tripped |
| `assets/window-overview-dark.png` | 900×620 | Primary product shot — README, landing page |
| `assets/window-overview-light.png` | 900×620 | Light-mode shot |
| `assets/window-breach-dark.png` | 900×700 | "The moment it matters" — the trip |
| `assets/window-insights-dark.png` | 900×620 | What the breaker saved you |
| `assets/window-settings-dark.png` | 900×980 | Feature shot — caps, live data, sensitivity |
| `assets/window-settings-light.png` | 900×980 | Light-mode feature shot |

## Where each one is used

- **README** — icon, social card, the colour-coded menu bar, the panel, and the window shots, in context.
- **Social / Product Hunt** — `social-card.png` (1200×630 is the standard card ratio).
- **Press kit** — `icon_1024.png` plus the window shots.
- **App Store** — `icon_1024.png` for the listing icon.
- **Menu-bar colour** — the three menu-bar items show one product idea in three states;
  use them together to explain the at-a-glance colour in a single image.

## One line

> **BurnFuse — a spend breaker for your AI keys.** Watch burn rate. Cap the damage. Cut
> the power before a runaway loop drains your card.

## Three lines

- It lives in your menu bar as a colour block: green when settled, amber as burn climbs,
  red when a breaker trips — the number is inside.
- Click it and you get a miniature of the app — live burn, the trend, every watched key —
  without leaving what you were doing.
- Native macOS, everything on your Mac. No account, no telemetry, no server.