# NDPass Extensions Setup

## Share Extension

The share extension lets you share ticket screenshots directly to NDPass from any app (Photos, Safari, Messages, etc.) without opening NDPass first.

### Setup in Xcode (after `npx expo prebuild`)

```bash
open ios/NDPass.xcworkspace
```

1. **Add Share Extension target**
   - File → New → Target → Share Extension
   - Product Name: `NDPassShare`
   - Bundle ID: `com.gios.ndpass.NDPassShare`
   - Language: Swift
   - Don't activate the scheme when prompted

2. **Replace generated files**
   - Delete the auto-generated `ShareViewController.swift` and storyboard
   - Drag in `extensions/ShareExtension/ShareViewController.swift`
   - Drag in `extensions/ShareExtension/Info.plist` (replace existing)

3. **Add App Group to BOTH targets**
   - Select main `NDPass` target → Signing & Capabilities → + App Groups → `group.com.gios.ndpass`
   - Select `NDPassShare` target → Signing & Capabilities → + App Groups → `group.com.gios.ndpass`

4. **Set the URL scheme**
   - Main `NDPass` target → Info → URL Types → add `ndpass`

5. Build and run

### How it works

1. User shares an image → Share sheet shows "NDPass"
2. Extension saves image to shared App Group container
3. Extension opens NDPass via `ndpass://scan/shared` URL scheme
4. App detects the shared image and auto-starts scanning

---

## Widget (Next Showing)

See `widgets/README.md` for widget setup instructions.
