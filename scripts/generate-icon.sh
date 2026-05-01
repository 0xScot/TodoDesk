#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$ROOT_DIR/Assets/AppIcon.svg"
ICONSET="$ROOT_DIR/Assets/AppIcon.iconset"
ICNS="$ROOT_DIR/Assets/AppIcon.icns"
TMP_DIR="$ROOT_DIR/.build/icon"
BASE_PNG="$TMP_DIR/AppIcon.png"

rm -rf "$ICONSET" "$TMP_DIR"
mkdir -p "$ICONSET" "$TMP_DIR"

qlmanage -t -s 1024 -o "$TMP_DIR" "$SVG" >/dev/null 2>&1
THUMBNAIL="$TMP_DIR/$(basename "$SVG").png"

if [[ ! -f "$THUMBNAIL" ]]; then
    echo "Unable to render $SVG" >&2
    exit 1
fi

mv "$THUMBNAIL" "$BASE_PNG"

python3 - "$BASE_PNG" <<'PY'
from collections import deque
from pathlib import Path
import sys

from PIL import Image

path = Path(sys.argv[1])
image = Image.open(path).convert("RGBA")
pixels = image.load()
width, height = image.size
queue = deque([(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)])
seen = set()

def is_white(pixel):
    red, green, blue, alpha = pixel
    return alpha > 0 and red >= 180 and green >= 180 and blue >= 180

while queue:
    x, y = queue.popleft()
    if x < 0 or y < 0 or x >= width or y >= height or (x, y) in seen:
        continue
    seen.add((x, y))
    if not is_white(pixels[x, y]):
        continue
    pixels[x, y] = (255, 255, 255, 0)
    queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

image.save(path)
PY

sips -z 16 16 "$BASE_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$BASE_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BASE_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$BASE_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$ICNS"

echo "Generated $ICNS"
