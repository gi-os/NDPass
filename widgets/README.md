# NDPass Widget Setup

The widget is a SwiftUI WidgetExtension that shows your next upcoming movie.

## How it works

1. **React Native app** saves the next showing data to a shared App Group (`group.com.gios.ndpass`) via `react-native-shared-group-preferences`
2. **SwiftUI widget** reads from the same App Group and displays poster + title + theater + time
3. Widget refreshes every 30 minutes

## Manual setup (after `npx expo prebuild`)

The widget target needs to be added manually in Xcode since Expo doesn't support widget extensions natively yet:

### 1. Open the Xcode project

```bash
open ios/NDPass.xcworkspace
```

### 2. Add Widget Extension target

- File → New → Target → Widget Extension
- Product Name: `NextShowingWidget`
- Bundle ID: `com.gios.ndpass.NextShowingWidget`
- Check "Include Configuration App Intent" = NO
- Finish

### 3. Replace the generated Swift file

Delete the auto-generated Swift file in the new target, and add:
- `widgets/NextShowingWidget/NextShowingWidget.swift`

### 4. Set up App Group

For BOTH the main app target AND the widget target:
- Select target → Signing & Capabilities → + Capability → App Groups
- Add: `group.com.gios.ndpass`

### 5. Build and run

Select the main app scheme and run. The widget should appear in the widget gallery on the home screen.

## What the widget shows

- **Small**: Movie poster + title + time
- **Medium**: Movie poster + title + theater + date + time
- Color-matched gradient background from the poster's dominant color
- Empty state when no upcoming showings
