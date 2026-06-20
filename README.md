# HAUNT 👻

Summon photoreal ghosts into your photos. AI ghost-cam novelty app. v1 = Ghost Cam only.

## Architecture
- SwiftUI, iOS. One screen (`GhostCamView`): pick photo → "scanning" → Moondraft `/v1/edit` composites a ghost in → share.
- **Engine = Moondraft REST** (`MoondraftClient.swift`): `POST https://moondraft.ai/v1/edit`, body `{prompt, image(dataURI)}`, returns base64. **1 credit per ghost.** 50 free credits on a Moondraft signup; packs 100/$9.99.
- Photoreal-creepy prompts live in `GhostEngine.swift`. They deliberately avoid "demonic/blood/gore/horror" (Moondraft's filter blocks those → fail+refund); they use "eerie/hollow-eyed/liminal/translucent".

## Funnel scaffolding (already wired)
- Free limit: **2 summons**, then `PaywallView` (one-time non-consumable, no sub).
- **SKStoreReview fires after the FIRST successful ghost** (the wow), never on launch.
- PostHog stubbed in `Analytics.swift` (events: app_open, photo_chosen, ghost_summon_started, ghost_rendered, shared, paywall_shown, purchased).
- Empty/loading/error states + offline handling in the screen and client.

## SETUP — what you (Cody) do to run it
1. **Create the Xcode project:** File → New → App → name `Haunt`, SwiftUI, your bundle ID. Save into THIS folder. Add the 6 `.swift` files in `Haunt/` to the target (drag them in if Xcode didn't pick them up).
2. **Add your Moondraft API key:** in `MoondraftClient.swift`, set `apiKey = "md_..."` (from your Moondraft dashboard). Better later: move to Keychain.
3. **Camera/Photos permission:** add `NSPhotoLibraryUsageDescription` (and `NSCameraUsageDescription` when we add live capture) to Info.plist — e.g. "Haunt needs your photos to reveal the spirits inside them."
4. **Run** on a device. Pick a room photo → Summon. (Costs 1 Moondraft credit per ghost — your money, your call.)

## TODO (next, after it runs)
- Live camera capture (currently photo-picker only).
- PostHog SDK + key. StoreKit IAP product `com.rci.haunt.unlock` in ASC.
- Privacy/TOS links, Google-Form feedback.
- v1.1: Spirit Box (EVP audio) + EMF radar.

## Files
- `HauntApp.swift` — entry
- `GhostCamView.swift` — the whole loop UI
- `GhostEngine.swift` — prompts, free-limit, review trigger
- `MoondraftClient.swift` — the `/v1/edit` call
- `PaywallView.swift` — one-time unlock
- `Analytics.swift` — PostHog stub
