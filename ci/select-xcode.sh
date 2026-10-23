#!/bin/bash
# The Xcode named in $XCODE (e.g. 27.1) when set, otherwise the newest non-beta one on the
# runner. Symlinks are resolved first: on the xcode-27 image Xcode_27.2.app points at a beta.
set -euo pipefail
if [ -n "${XCODE:-}" ]; then
  X="/Applications/Xcode_${XCODE}.app"
  [ -d "$X" ] || { echo "::error::Xcode $XCODE isn't on this runner"; ls -d /Applications/Xcode_*.app; exit 1; }
else
  X=$(for a in /Applications/Xcode_*.app; do [[ "$(readlink -f "$a")" == *[Bb]eta* ]] || echo "$a"; done | sort -V | tail -1)
fi
sudo xcode-select -s "$X/Contents/Developer"
xcodebuild -version
echo "iOS SDK $(xcrun --sdk iphoneos --show-sdk-version)"
