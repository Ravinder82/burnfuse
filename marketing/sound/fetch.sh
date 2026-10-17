#!/usr/bin/env bash
# Re-download the launch reel's audio sources (Mixkit music + Freesound CC0 SFX)
# and rebuild the exactly-150.000-BPM music master. Raw audio is gitignored;
# licences are logged in LICENSES.md.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p music sfx

echo "== music: Mixkit Free License =="
curl -sL --max-time 120 "https://assets.mixkit.co/music/1210/1210.mp3" \
  -o music/cant-get-you-off-my-mind-1210.mp3
# Lock to exactly 150.000 BPM (75.0 halftime) for the film's 12-frame beat grid.
# Measured native tempo 75.03 BPM -> atempo = 75.0 / 75.03 = 0.9996002.
ffmpeg -y -hide_banner -loglevel error -i music/cant-get-you-off-my-mind-1210.mp3 \
  -af atempo=0.9996002 -ar 48000 -ac 2 music/cant-get-you-off-my-mind-150-bpm.wav
ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 \
  music/cant-get-you-off-my-mind-150-bpm.wav

echo "== sfx: Freesound CC0 =="
while IFS=' ' read -r file url; do
  curl -sL --max-time 60 "$url" -o "sfx/$file"
  printf '  %-28s ok\n' "$file"
done <<'EOF'
whoosh-light-701104.mp3 https://cdn.freesound.org/previews/701/701104_13504080-hq.mp3
whoosh-deep-558826.mp3 https://cdn.freesound.org/previews/558/558826_2247456-hq.mp3
boom-802075.mp3 https://cdn.freesound.org/previews/802/802075_15956618-hq.mp3
impact-soft-728515.mp3 https://cdn.freesound.org/previews/728/728515_2393492-hq.mp3
stamp-470710.mp3 https://cdn.freesound.org/previews/470/470710_9906084-hq.mp3
flash-406614.mp3 https://cdn.freesound.org/previews/406/406614_6068748-hq.mp3
tick-a-528561.mp3 https://cdn.freesound.org/previews/528/528561_10360410-hq.mp3
tick-b-546974.mp3 https://cdn.freesound.org/previews/546/546974_12153167-hq.mp3
EOF

echo "done — now run: python3 ../videos/launch/sound/assemble.py"
