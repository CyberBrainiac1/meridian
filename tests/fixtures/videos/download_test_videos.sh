#!/usr/bin/env bash
# Downloads the real-world test videos used by tools/smoke_test_video.py.
# Not committed to git (repo convention gitignores *.mp4) -- run this to
# fetch them locally. Source: intel-iot-devkit/sample-videos (public,
# permissively licensed, purpose-built for exactly this kind of
# person-detection testing).
set -e
DIR="$(dirname "$0")"
BASE_URL="https://raw.githubusercontent.com/intel-iot-devkit/sample-videos/master"

for name in people-detection.mp4 one-by-one-person-detection.mp4; do
  echo "Downloading $name..."
  curl --ssl-no-revoke -sL -o "$DIR/$name" "$BASE_URL/$name"
done
echo "Done. Videos are in $DIR"
