# NDPass

Ticket stubs on iPhone: films, games, concerts, shows, any other admission, and trains,
flights, buses and ferries. Photograph a stub, pick a screenshot, share an e-ticket, PDF or
confirmation email from any app, or type a ticket in. NDPass reads the title, venue, date, time,
seat, price and booking reference, keeps the collection sorted by showtime, moves a ticket to the
past once it's over, and shows the ticket's own barcode full screen at the door.

v2 is a native SwiftUI rewrite at parity with [BrightPasses](https://github.com/gi-os/BrightPasses)
on the Light Phone III. The Expo version lives on the `expo` branch (tag `expo-final`).

- Read on the device: Vision text recognition plus Apple Intelligence (FoundationModels) when
  available, patterns otherwise. Optional: Claude Haiku with the user's own Anthropic key, after
  consent.
- A date with no year is read as upcoming; a printed year is kept (old stubs keep theirs).
- The real barcode is read off the photo (QR, PDF417, Aztec, Code 128). No codes are drawn from
  booking references; without a code the stub photo goes to the door.
- Art: TMDb posters and logos (optional key); games in their teams' colors (bundled list, colors
  only) with TheSportsDB crests if a key is added; concert artist photos from Deezer (exact name
  matches only).
- Tickets for the same showing group together; merge the ones that didn't match; edit a showing
  and each ticket's seat, price and reference.
- Trips: route, departure and arrival (overnight shown as +1), carrier and number, track or gate,
  car and seat. Early-morning times are kept as printed.
- Lock Screen / Dynamic Island Live Activity from 30 minutes out (90 for flights), scheduled ahead
  on iOS 26; the ticket's own code on the Lock Screen, tap a seat to switch.
- Reminders 3 hours and 30 minutes before (1 hour for flights), one pair per showing.
- Automatic calendar events (opt-in, Settings > Calendar), skipping showings already in the calendar.
- Share extension reads and adds tickets without opening the app.
- Calendar tab and stats (streaks, venues map, habits).
- On the iPhone Duo's inner display, the list and the ticket sit side by side.

Keys (Settings, all optional, Keychain): Anthropic, TMDb, TheSportsDB.

## Build

```sh
brew install xcodegen && xcodegen generate && open NDPass.xcodeproj
```

CI: `check.yml` on every branch; a push to `main` ships to TestFlight via fastlane match.
