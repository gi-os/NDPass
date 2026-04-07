# NDPass 🎬

AI-powered movie ticket stub collector for iOS. Snap a photo of your ticket, Claude parses the details, get reminders before showtime, build your cinema history.

## Features

- **AI Ticket Scanning** — Claude Vision extracts movie, theater, date/time, seat, price
- **TMDb Posters** — movie posters and backdrop art on ticket cards
- **Liquid Glass UI** — iOS 26-inspired translucent panels and blur effects
- **Stub Collection** — full ticket images, grouped by showing
- **Calendar View** — monthly calendar with showing dots
- **Showtime Reminders** — 9AM day-of, 2hrs before, 30min before
- **Fullscreen Tickets** — tap to show ticket at box office
- **Edit Tickets** — fix any field after scanning
- **Auto-Archive** — past showings move to archive
- **Stats Dashboard** — total stubs, spend, favorite theater
- **Share Extension** — share screenshots directly to NDPass
- **Home Screen Widget** — next showing with poster (SwiftUI)
- **Debug Terminal** — live scan progress

## Stack

- Expo SDK 52, React Native, TypeScript
- expo-sqlite, expo-blur, expo-linear-gradient
- Anthropic API (Claude Sonnet 4), TMDb API
- SwiftUI widget + Share Extension

## Setup

```bash
git clone https://github.com/gi-os/NDPass.git
cd NDPass
npm install
npx expo prebuild --clean
npx expo run:ios
```

Settings tab → add Anthropic API key (required) and TMDb API key (optional, for posters).

## TestFlight

```bash
npm install -g eas-cli
eas login
eas build --platform ios --profile preview
eas submit --platform ios
```

EAS will prompt for Apple Developer credentials on first run.

## Extensions

See `extensions/README.md` for Share Extension setup.
See `widgets/README.md` for Home Screen Widget setup.

## Roadmap

- [ ] Home screen widget (SwiftUI code ready, needs Xcode target)
- [ ] Share extension (Swift code ready, needs Xcode target)
- [ ] Apple Wallet passes
- [ ] Gmail/email integration for auto-import
- [ ] Apple Foundation Models (on-device, no API key)
- [ ] iCloud sync
- [ ] Letterboxd deep links

## License

MIT
