# BurnFuse launch plan

Everything is prepared. This file is the master board: what exists, where it posts, and
what still needs a human account.

## The kit

| Asset | Path | Format |
|---|---|---|
| Launch film (story) | `marketing/renders/story.mp4` | 16:9 · 34s · sound |
| Product tour | `marketing/renders/tour.mp4` | 16:9 · 21s · light |
| Reel (IG/YT/TikTok) | `marketing/renders/reel.mp4` | 9:16 · 18s |
| Hero card | `marketing/stills/out/launch-16x9.png` | 3200×1800 |
| Square / portrait | `launch-square.png` · `launch-portrait.png` | 2160² / 2160×2700 |
| Quote cards | `quote-key` · `quote-number` · `quote-local` | 2160² |
| States / trip / providers | `states-16x9` · `trip-flow-16x9` · `providers-16x9` | 3200×1800 |
| Reel cover | `reel-cover.png` | 2160×3840 |
| YouTube thumbs | `yt-thumb-a.png` · `yt-thumb-b.png` | 2560×1440 |
| Link card (OG) | `og-card.png` | 2400×1260 |
| Copy | `marketing/copy/*.md` | per platform |

All stills come from `marketing/stills/cards.html` via `./render.sh` (headless Chrome @2x).
All videos come from `marketing/videos/<name>/` via `npx hyperframes render`.

## Venues

### Live now (done in this pass)

| # | Venue | What | Status |
|---|---|---|---|
| 1 | GitHub release | v1.0.0 with DMG + videos | ✅ published |
| 2 | Repo | `marketing/` committed so everything is public | ✅ committed |

### Ready to post — needs your account (copy is written)

| # | Venue | Asset | Copy file | Best time |
|---|---|---|---|---|
| 3 | X / Twitter | thread + story.mp4, then singles | `copy/twitter.md` | launch morning |
| 4 | Hacker News (Show HN) | repo link + first comment | `copy/hacker-news.md` | weekday 8–10 AM ET |
| 5 | Product Hunt | gallery + maker comment | `copy/product-hunt.md` | 12:01 AM PT |
| 6 | Reddit r/macapps | states still + body | `copy/reddit.md` | any weekday |
| 7 | Reddit r/SideProject | story.mp4 | `copy/reddit.md` | day 2 |
| 8 | Reddit r/LLMDevs | repo + body | `copy/reddit.md` | day 3–4 |
| 9 | YouTube (main) | story.mp4 + yt-thumb-a | `copy/youtube-instagram.md` | alongside X |
| 10 | YouTube Shorts | reel.mp4 + cover | `copy/youtube-instagram.md` | alongside X |
| 11 | Instagram Reel + feed | reel.mp4 + carousel | `copy/youtube-instagram.md` | alongside X |
| 12 | TikTok | reel.mp4 | `copy/youtube-instagram.md` | alongside X |
| 13 | LinkedIn | launch-16x9 + post | `copy/social-short.md` | day 1–2 |
| 14 | Bluesky · Mastodon · Threads | reel or states still | `copy/social-short.md` | launch morning |
| 15 | dev.to + Hashnode article | outline in copy file | `copy/directories.md` | day 3 |
| 16 | AlternativeTo · MacUpdate · Softpedia | DMG + stills | `copy/directories.md` | day 4–7 |
| 17 | Uneed · Peerlist · MicroLaunch · Indie Hackers | PH copy reuse | `copy/directories.md` | day 5+ |
| 18 | awesome-mac / awesome-macos PRs | link additions | `copy/directories.md` | day 7 |
| 19 | Newsletters (TLDR, Swift Weekly…) | 2-line pitch | `copy/directories.md` | day 3 |
| 20 | MacStories / 9to5Mac tips | email pitch | `copy/directories.md` | day 4 |

### Suggested order

1. **Day 0:** GitHub release (done) → X thread with story.mp4 → Bluesky/Mastodon/Threads.
2. **Day 1:** Show HN in the 8–10 AM ET window → reply all day.
3. **Day 2:** Product Hunt at 12:01 AM PT → cross-post to LinkedIn & YT/Shorts/IG/TikTok.
4. **Day 3:** r/macapps → dev.to article.
5. **Day 4:** r/SideProject → r/LLMDevs.
6. **Day 5+:** directories, newsletters, awesome-list PRs, press tips.
7. Any day: X singles A–D from `copy/twitter.md` spread over two weeks.

### Not for us (deliberately)

- Paid ads, engagement pods, vote requests. The product's whole pitch is trust; the
  launch shouldn't start by faking it.

## What needs you

- Accounts/credentials for rows 3–20 above (I stopped at the GitHub door because it is the
  only one with creds in this machine).
- A human pass on the HN comment and PH maker comment — they're written in your voice but
  you should own them.
- Product Hunt scheduling (12:01 AM PT) and thumbnail/icon uploads.
