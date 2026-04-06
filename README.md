# NDPass 🎬

A movie ticket stub collector for iOS. Snap a photo of your ticket, let AI parse the details, get reminders before showtime, and build your cinema history.

## Features

- **AI Ticket Scanning** — photograph a ticket, Claude Vision extracts movie title, theater, date/time, seat, and price
- **Stub Collection** — browse all your saved tickets in a dark, cinema-inspired UI
- **Showtime Reminders** — automatic push notification 1 hour before the movie
- **Letterboxd Integration** — deep link to log/review the film on Letterboxd
- **Stats Dashboard** — track total stubs, spend, favorite theater, monthly count

## Stack

- **Expo SDK 52** + expo-router (file-based routing)
- **TypeScript**
- **expo-sqlite** for local persistence
- **Anthropic API** (Claude Sonnet) for vision-based ticket parsing
- **expo-notifications** for showtime reminders
- **expo-image-picker** for camera/library access

## Setup

### Prerequisites

- Node.js 18+
- Xcode 15+ (for iOS simulator / device builds)
- Apple Developer account ($99/yr) — needed for TestFlight & notifications
- Anthropic API key

### Install

```bash
git clone https://github.com/gi-os/NDPass.git
cd NDPass
npm install
```

### Configure

```bash
cp .env.example .env
# Add your Anthropic API key to .env
```

### Run (simulator)

```bash
# Generate native project
npx expo prebuild

# Run on iOS simulator
npx expo run:ios
```

### Run (device via dev client)

```bash
npm install -g eas-cli
eas login
eas build --platform ios --profile development
# Install the dev client on your phone, then:
npx expo start --dev-client
```

### TestFlight

```bash
eas build --platform ios --profile preview
eas submit --platform ios
```

## Roadmap

- [ ] Apple Wallet pass generation (requires server-side signing)
- [ ] TMDb poster art on ticket cards
- [ ] Share stub cards as images
- [ ] iCloud sync
- [ ] Widget for upcoming showtime

## License

MIT
