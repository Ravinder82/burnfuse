# Launch reel — audio licences

Every sound in the launch reel is a ready-made, licensed file: real music +
ready-made SFX, no code-synthesised score (house standard — see
`~/.agents/skills/app-launch-kit/rules/sound-pass.md`).

## Music

| Track | Artist | Source | Licence | Modifications |
|---|---|---|---|---|
| "Can't Get You Off My Mind" — Future Bass, 90.7 s | Michael Ramir C. | [Mixkit — Future Bass](https://mixkit.co/free-stock-music/future-bass/) · asset `assets.mixkit.co/music/1210/1210.mp3` | Mixkit Free License — free for commercial projects, no attribution required, no standalone redistribution | Locked to exactly 150.000 BPM (−0.04 % `atempo`); two excerpts spliced (22.022 s→38.022 s and 74.822 s→82.822 s, seam crossfaded) |

## Sound effects — all CC0 (public domain, no attribution required)

| File | Original name | Author | Source |
|---|---|---|---|
| `whoosh-light-701104.mp3` | Whoosh stereo light (transition) | xkeril | [freesound.org/s/701104](https://freesound.org/s/701104/) |
| `whoosh-deep-558826.mp3` | Deep Whoosh #6 | Kinoton | [freesound.org/s/558826](https://freesound.org/s/558826/) |
| `boom-802075.mp3` | Drama Boom 02 | modusmogulus | [freesound.org/s/802075](https://freesound.org/s/802075/) |
| `impact-soft-728515.mp3` | Impact Hit at soft but big material | doudar41 | [freesound.org/s/728515](https://freesound.org/s/728515/) |
| `stamp-470710.mp3` | traditional stamp.wav | I.fekry | [freesound.org/s/470710](https://freesound.org/s/470710/) |
| `flash-406614.mp3` | Camera Flash_Crackle_Near_Mono | _stubb | [freesound.org/s/406614](https://freesound.org/s/406614/) |
| `tick-a-528561.mp3` | Soft UI Button Click | Jummit | [freesound.org/s/528561](https://freesound.org/s/528561/) |
| `tick-b-546974.mp3` | UI_Click.wav | finix473 | [freesound.org/s/546974](https://freesound.org/s/546974/) |

Raw music files stay out of git (`fetch.sh` re-downloads them); the SFX
previews are small and committed. The finished mix ships inside the film
(`sound/launch-score.m4a`), which all of the above licences permit.
