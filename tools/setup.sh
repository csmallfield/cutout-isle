#!/usr/bin/env bash
# Link the kits into addons/ and fetch the audio kit's native core.
#   tools/setup.sh                      # kits from the vendor/ submodules
#   KITS_DIR=~/dev tools/setup.sh       # kits from sibling checkouts (kit work in progress)
# Windows: tools/setup.ps1 (directory junctions, no admin rights needed).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${KITS_DIR:-}" ]; then
  MK="$KITS_DIR/godot-motion-kit"
  AK="$KITS_DIR/godot-audio-kit"
else
  git submodule update --init --depth 1
  MK="$PWD/vendor/godot-motion-kit"
  AK="$PWD/vendor/godot-audio-kit"
fi

mkdir -p addons
for pair in "motion_kit:$MK" "audio_kit:$AK"; do
  name="${pair%%:*}"; repo="${pair#*:}"
  src="$(cd "$repo/addons/$name" && pwd)"
  rm -f "addons/$name"
  ln -s "$src" "addons/$name"
  echo "addons/$name -> $src"
done

# The audio kit's native core (LIVE sound). Built libraries aren't committed:
# take CI's artifact, or build it (cd <audio kit>/native && scons platform=<os> target=template_debug).
BIN="$AK/addons/audio_kit/native/bin"
if ls "$BIN"/libaknative.* >/dev/null 2>&1; then
  echo "native core: present"
elif command -v gh >/dev/null 2>&1; then
  run=$(gh run list -R csmallfield/godot-audio-kit --workflow native.yml --branch main --status success -L 1 --json databaseId --jq '.[0].databaseId')
  mkdir -p "$BIN"
  gh run download "$run" -R csmallfield/godot-audio-kit -n audio-kit-native -D "$BIN" && echo "native core: from CI run $run"
else
  echo "native core: missing (no gh). Build it: cd $AK/native && scons platform=<os> target=template_debug"
fi
