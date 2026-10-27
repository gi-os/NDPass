# NDPass

Ticket stubs on iPhone (films, games, concerts, travel): photograph, import or share a ticket and
NDPass reads it on device, sorts by showtime, and shows its barcode at the door. Native SwiftUI, at
parity with BrightPasses on the Light Phone III. The house rules, pipeline and skills come from the
gi-os kit, loaded at session start (`.gios/`, read-only here).

- Code: `NDPass/` app (App, Logic, Model, Services, UI), `NDPassShare/` share extension,
  `NDPassWidgets/` widget + countdown Live Activity, `Shared/` (App Group `group.com.gios.ndpass`),
  `NDPassTests/` (Swift Testing), `NDPassUITests/` screenshot tests.
- Reading tickets: Vision text recognition plus Apple Intelligence (FoundationModels) when available,
  patterns otherwise; Claude Haiku only with the user's own key, after consent.
- App Store: `release.yml` is this app's own (it has an in-app purchase toggle); screenshots come from
  the `NDPassScreenshots` scheme; `ci/iap.py` keeps Gold and Gold Plus in App Store Connect.
