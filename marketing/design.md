# BurnFuse — marketing design system

Brand source of truth for every launch asset (videos, cards, reels).
Derived from the shipping app: `macos/Sources/BurnFuseUI/DesignSystem.swift`,
`FuseMark.swift`, and the rendered screenshots in `assets/`.

## Voice

Quiet, honest, exact. The product's own line: *"Built to be quiet, honest, and
right the one time it matters."* Copy claims only what the app can prove — no
hype superlatives, no invented numbers, no exclamation marks. Short sentences.
Numbers mean what they say.

## Canvas

- **Dark canvas is the home ground** — deep graphite, lit from above, one
  glowing thing at a time. `#101013` base, `#1B1C20` panels (`#262626` if a
  surface needs to read lighter, e.g. glass panel).
- **Light canvas is reserved for the product tour** (the app follows the
  system). Use `#F5F5F7` base, `#FFFFFF` surfaces, primary text `#1D1D1F`.
  Light frames need structure (rules, borders 2px, strong type), not pastel.

## Palette

| Token   | Hex       | Use |
|---------|-----------|-----|
| bg      | `#101013` | film base, dark canvas |
| panel   | `#1B1C20` | cards, chips, chart wells |
| ink     | `#F5F5F7` | primary text on dark |
| ink-2   | `#A2A2AB` | secondary text on dark |
| ink-3   | `rgba(255,255,255,0.42)` | mono metadata |
| hair    | `rgba(255,255,255,0.10)` | hairlines, borders |
| calm    | `#57DB94` | settled / green state (exact app value) |
| warm    | `#FCCB47` | climbing / amber state (exact app value) |
| hot     | `#FA5426` | tripped / red state (exact app value) |
| accent  | `#F59E17` | brand accent amber (exact app value) |
| tile-1  | `#363636` | mark tile gradient top |
| tile-2  | `#141414` | mark tile gradient bottom |

State colour is never alone: it always travels with a word (settled /
climbing / tripped) or the number itself.

## Type

- **Display & UI:** SF Pro Rounded — `ui-rounded, "SF Pro Rounded", -apple-system`.
  Weights 200–900. Hero type is 300-vs-900 contrast, tracking −0.03em.
- **Data & metadata:** SF Mono — `ui-monospace, "SF Mono", Menlo, monospace`.
  It carries stamps, times, dollar figures, paths, labels. 16–24px at video
  scale, `font-variant-numeric: tabular-nums` everywhere numbers stack.
- Body copy never below 28px in 1920-wide frames, 22px in 1080-wide frames.

## Motifs

- **The filament with the break** — one wire, green tail → amber → red past the
  break, with the spark. Drawn from shapes, not shipped as a logo image.
- **The menu-bar block** — a rounded pill carrying glyph + number, in the state
  colour. The product in one shape.
- **Monospace stamps** — times (`11:47 PM`), figures (`$2.45/hr`), paths
  (`~/.burnfuse/keys.json`). Small, dim, always lowercase or uppercase — never
  Title Case.
- **Hairline rules and 8pt structure** — layouts anchor to edges, never float
  centered with air around them.

## Motion

- Mood: precise, patient, then decisive. Slow builds; fast, exact punches at
  the moment something trips.
- Eases: entrances `power3.out`/`expo.out`; dramatic objects `power4.out`;
  ambient motion `sine.inOut`; exits (`power2.in`) only inside transitions.
- Transitions: zoom-through for scene changes into machinery; one hard smash
  cut for the wake-up moment; push-up between related beats; blur-through to
  resolve. Red is allowed to bloom.
- Numbers are animated as tabs-style counters, never random glitch.

## Don'ts

- No emoji. No stock photography. No generic AI-blue gradients (`#3b82f6`).
- No invented stats, no "10×", no fake dashboards — every claim matches the
  README's own wording.
- No pure black `#000` backgrounds and no fully flat `#000` — use `#101013`.
- Never show a zero the app has not measured; never claim a key was stopped
  when the provider has not said so.
