# NDPass

Movie ticket stubs on iPhone. Photograph a stub or pick a screenshot, and Claude Haiku reads the
title, theater, date, time, seat, price and booking reference. NDPass keeps the collection sorted
by showtime, moves a ticket to the archive once the film ends, and shows the ticket's own barcode
full screen at the door.

v2 is a native SwiftUI rewrite at parity with [BrightPasses](https://github.com/gi-os/BrightPasses)
on the Light Phone III. The Expo version lives on the `expo` branch (tag `expo-final`).

- Claude Haiku parse with a tight crop around the paper; the full photo stays one tap away.
- A date with no year is read as upcoming (same rule and tests as BrightPasses).
- The real barcode is read off the photo (QR, PDF417, Aztec, Code 128). If there isn't one, a code is drawn from the booking reference and labelled as generated.
- Full-screen code on white at full brightness.
- TMDb posters and film search; crests for games (ESPN), art for concerts.
- Tickets for the same showing group together; merge the ones that didn't match.
- Reminders at 9 AM on the day, 2 hours before and 30 minutes before.
- Calendar and stats.
- On the iPhone Duo's inner display, the list and the ticket sit side by side.

Keys (Settings): Anthropic (required for automatic reading), TMDb (optional). Stored in the Keychain.

## Build

```sh
brew install xcodegen && xcodegen generate && open NDPass.xcodeproj
```

CI: `check.yml` on every branch; a push to `main` ships to TestFlight via fastlane match.
