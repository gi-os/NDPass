# NDPass 🎬

AI-powered movie ticket stub collector for iOS. Snap a photo of your ticket, Claude parses the details, get reminders before showtime, build your cinema history.

## Features

- **AI Ticket Scanning** — photograph a ticket, Claude Vision extracts movie, theater, date/time, seat, price
- **Stub Collection** — browse saved tickets with full ticket image preview
- **Showtime Reminders** — push notification 1 hour before the movie
- **Letterboxd Integration** — deep link to log/review on Letterboxd
- **Stats Dashboard** — total stubs, spend, favorite theater, monthly count
- **In-App Settings** — API key stored locally, no server needed
- **Debug Terminal** — live scan progress visible during parsing

## Stack

- Expo SDK 52 + expo-router
- TypeScript
- expo-sqlite (local persistence + settings)
- Anthropic API (Claude Sonnet 4 vision)
- expo-notifications (showtime reminders)
- expo-image-manipulator (compression before API call)

## Setup

```bash
git clone https://github.com/gi-os/NDPass.git
cd NDPass
npm install
npx expo prebuild --clean
npx expo run:ios
```

On first launch, go to **Settings** tab and paste your Anthropic API key. Get one at [console.anthropic.com](https://console.anthropic.com/settings/keys).

## Roadmap

- [ ] Apple Wallet passes
- [ ] TMDb poster art on cards
- [ ] Share stub cards as images
- [ ] Apple Foundation Models (on-device, no API key needed)
- [ ] iCloud sync

## License

MIT
