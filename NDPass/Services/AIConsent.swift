import SwiftUI

/// Reading a ticket sends its photo to Anthropic. App Review guidelines (5.1.2) ask for a
/// plain statement of which AI service gets the data and permission before it goes. Asked
/// once, before the first scan; changeable in Settings.
enum AIConsent {
    private static let key = "aiConsent"
    static var asked: Bool { UserDefaults.standard.object(forKey: key) != nil }
    static var granted: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct AIConsentSheet: View {
    var onDone: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Read tickets with Claude?").font(Theme.serif(34)).foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 12) {
                row("photo", "When you scan a stub, its photo is sent to Anthropic's Claude API, using your own API key, to read the film, theater, date, time, seat, price and booking code.")
                row("lock", "Nothing else leaves your phone. Your tickets are stored on this device only. NDPass has no account and no server of its own.")
                row("hand.raised", "Anthropic's handling of API data is covered by its privacy policy at anthropic.com/legal/privacy.")
                row("pencil", "Say no and NDPass still works: you type the ticket details yourself. You can change this in Settings.")
            }
            Spacer(minLength: 0)
            Button { onDone(true) } label: {
                Text("Allow").font(Theme.sans(17, .semibold)).foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 52).background(Theme.accent, in: Capsule())
            }
            Button { onDone(false) } label: {
                Text("Not now, I'll type them").font(Theme.sans(16)).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
        }
        .padding(28)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(Theme.amber)
            Text(text).font(Theme.sans(15)).foregroundStyle(Theme.ink.opacity(0.88)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
