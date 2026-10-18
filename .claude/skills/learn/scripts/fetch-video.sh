#!/usr/bin/env bash
# usage: fetch-video.sh <url> <out-dir> <name>
# Downloads a short video to a temp dir, writes <name>.txt (local Whisper transcript) and <name>-frames.jpg
# (one frame every 3 s, tiled) into <out-dir>, then deletes the video. <name> must not contain dots
# (mlx_whisper cuts the output name at the first dot). Uses mlx_whisper on a Mac, else openai-whisper.
set -euo pipefail
url=$1; out=$2; name=${3//./-}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out"
yt-dlp -q --no-warnings -o "$tmp/v.%(ext)s" "$url"
v=$(ls "$tmp"/v.*)
if command -v mlx_whisper >/dev/null; then
  mlx_whisper "$v" --model mlx-community/whisper-large-v3-turbo --output-dir "$tmp" --output-format txt >/dev/null 2>&1
else
  whisper "$v" --model turbo --output_dir "$tmp" --output_format txt >/dev/null 2>&1
fi
cp "$tmp/v.txt" "$out/$name.txt"
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$v")
n=$(python3 -c "import math;print(max(1,math.ceil($dur/3)))")
cols=$(( n < 7 ? n : 7 )); rows=$(( (n + cols - 1) / cols ))
ffmpeg -loglevel error -y -i "$v" -vf "fps=1/3,scale=300:-1,tile=${cols}x${rows}" -frames:v 1 "$out/$name-frames.jpg"
echo "$name: ${dur%.*} s, $(wc -w < "$out/$name.txt" | tr -d ' ') words, $n frames"
