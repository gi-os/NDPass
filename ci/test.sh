#!/bin/bash
set -euo pipefail
source ci/app.env
DEV=$(bash ci/sim.sh)
echo "Testing on simulator $DEV"
xcodebuild test -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -destination "id=$DEV" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|failed|XCTAssert|\*\* TEST|Executed" | head -80
exit ${PIPESTATUS[0]}
