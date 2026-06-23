# Haunt — Handoff Log (newest first)

## 2026-06-22
- **Ghost output overhauled** (`a87cd46`): killed the 15 bedsheet presets → 9 prompt-described apparition archetypes (Shadow/Pale Woman/Tall One/Victorian/Child/Hollow/Crawler/Mist/Watcher). `GhostStyle` = name + posterAsset + prompt; summon is single-image edit (no sheet reference). New AI poster art in `ghost_01..09`.
- **Security** (`2cf7c4f` + daily-cap follow-up): fal key removed from the app, moved to Railway proxy `haunt-proxy` (`https://haunt-proxy-production.up.railway.app`). App uses `x-haunt-key` gate; proxy holds FAL_KEY, pins quality=medium, rate-limits 20/min/IP, global daily cap 1500. Verified live.
- **Analytics** (`8f6e3a9`): real PostHog over HTTP (no SDK), `app:"haunt"` tag, `app_open` verified ingested. Native in-app feedback → `feedback_submitted` event (replaces Google Form).
- **UX/output fixes**: clearly-visible-but-hidden ghost prompt + full reveal (`e1b0bfd`); reveal alignment via aspect-fill resize + removed Cinematic mode (`f7d8577`); peeking swipe carousel (`4d4cb84`); staged-photo indicator (`50162c9`); Crypt→"My Haunts" + close button (`40e020b`); legal links in paywall (`0be6323`); DEBUG unlimited summons (`c25f23f`); ghost-fade video export verified (`GhostVideo.swift`).
- **Decisions**: Realistic-only (dropped Cinematic). fal key via proxy (not embedded) because this is a viral target. App Attest deferred — daily cap bounds the bill. Video (real fal i2v) parked pending Cody $ greenlight.
- **Open**: Cody making real villain poster art (3:4 PNG → ghost_0N); may trim 9→fewer. Cody to set fal spend limit + create credit IAPs in ASC + submit. No physical-device end-to-end run confirmed yet.
