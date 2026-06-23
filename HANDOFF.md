# Handoff: 2026-06-22

> **Working style + project context load automatically** — global memory (`MEMORY.md`) and the in-repo notes carry Cody's preferences (tldr, yes/no answers, no slop, act-don't-ask) plus deep architecture. This doc is CURRENT PROJECT STATE only. Older sessions are in `HANDOFF_LOG.md`. The full Haunt brain is also in global memory `project_haunt.md`.

## Verify on arrival (RUN before trusting anything below)
- `git -C "/Volumes/LaCie/Eng Projects/Haunt" status --short && git -C "/Volumes/LaCie/Eng Projects/Haunt" log --oneline -8` → HEAD should be `4d4cb84` on `main`
- `cd "/Volumes/LaCie/Eng Projects/Haunt" && xcodegen generate && xcodebuild -project Haunt.xcodeproj -scheme Haunt -destination 'generic/platform=iOS Simulator' build` → confirm BUILD SUCCEEDED
- `curl -s https://haunt-proxy-production.up.railway.app/health` → should return `{"ok":true,...,"cap":1500}`

## What I just did this session
Major output + security + UX overhaul. App is SwiftUI, iOS 17+, **xcodegen** (`project.yml` → `xcodegen generate` before every build). Key commits:
- `a87cd46` **Ghost output overhaul** — replaced 15 bedsheet presets with **9 prompt-described apparition archetypes** (`GhostStyle.swift`): Shadow, Pale Woman, Tall One, Victorian, Child, Hollow, Crawler, Mist, Watcher. No more sheet-reference image — `GhostStyle` now has `name` + `posterAsset` + `prompt`; summon uses single-image edit with the archetype `prompt`. New AI-generated poster art swapped into `Assets.xcassets/ghost_01..09`.
- `e1b0bfd` Fixed "ghost not showing": prompt now CLEARLY VISIBLE ghost (kept hidden/off-center placement); `BeforeAfterView` fully reveals (was stuck at 50%, hiding side-placed ghosts); removed logo blink (`flicker()` → static glow in `pinnedHeader`).
- `f7d8577` Reveal alignment — `GhostAPI.resize()` aspect-fills result to the original photo's exact size so before/after + video line up. **Removed Cinematic mode entirely — Realistic only.**
- `4d4cb84` Carousel is now a **peeking snap-scroll** (`ghostCarousel`/`ghostCard` in `GhostCamView.swift`, iOS17 `.scrollTargetBehavior(.viewAligned)` + `contentMargins` + `scrollPosition(id:$scrolledID)`) + custom dots. Replaced full-width TabView.
- `2cf7c4f` **SECURITY: fal key moved off the client to a Railway proxy** (`~/haunt-proxy`). App POSTs to proxy with `x-haunt-key` header; proxy injects FAL_KEY, pins quality=medium. Later added a **global daily cap (1500/day)** circuit breaker + `/health`.
- `8f6e3a9` Real PostHog capture (HTTP, no SDK, `app:"haunt"` tag) — VERIFIED `app_open` ingested live. Native in-app feedback → `feedback_submitted` event (no Google Form), button in My Haunts.
- `50162c9` Staged-photo indicator (thumbnail + Change/✕). `40e020b` Crypt detail close (X) button. `c25f23f` DEBUG builds = unlimited summons.
- Also: Crypt renamed "My Haunts" + Original/Haunted compare in detail; ghost-fade video export (`GhostVideo.swift`, verified 603KB MP4, orientation fixed).

## Current state of the codebase
- [V] Builds clean (xcodebuild SUCCEEDED this session). Branch `main`, tree clean, pushed to `github.com/helloooproject/haunt`.
- [V] Proxy live + healthy: `https://haunt-proxy-production.up.railway.app` (Railway project `haunt-proxy`, code `~/haunt-proxy`, local git only). Auth gate + real summon + daily cap all verified.
- [V] PostHog ingesting (`app_open` confirmed via SQL query, project 338198, token `phc_m4Red...`).
- [V] Output quality good — generated archetype composites on real pipeline (shadow/pale-woman/etc. look genuinely scary).
- [V] `Secrets.swift` (gitignored) holds `proxyURL` + `appSecret` (NOT the fal key). Template in `Secrets.swift.example`.
- [ASK] Carousel peek + staged-photo indicator are **build-verified, NOT screenshot-verified** — the iOS sim screenshot pipeline was glitching (0-byte/"error creating image", known iOS-sim issue). Confirm visually on device rebuild.

## What's broken or known issues
- [V] Sim screenshot capture was failing at end of session (sim display glitch, not code). Use video-frame extraction if it persists (see global memory `feedback_simctl_screenshot_ghost`).
- [ASK] No real on-device end-to-end run confirmed by Cody yet (summon→reveal→video through the proxy on a physical phone). He's been testing; must rebuild (⌘R) to pick up proxy + archetypes + all recent commits — older device builds show stale behavior.
- App Attest NOT implemented — `appSecret` gate is bypassable (extractable). Acceptable: fal bill bounded by daily cap + (should-do) fal-dashboard spend limit.

## What the next Claude should do
1. **Cody is making real poster art** for the 9 villains (portrait 3:4 PNG → `Assets.xcassets/ghost_0N.imageset/ghost_0N.png`). When delivered, place them + rebuild. He may trim the 9 to fewer "villains" — edit `GhostStyle.library` accordingly.
2. If asked: prototype **real AI video** (fal image-to-video) to replace the crossfade `GhostVideo` — costs ~$0.05–0.50/clip, needs Cody's $ greenlight. Parked this session.
3. Help get it on device: rebuild, confirm the live summon flow.

## Open questions for Cody
- [ASK] Which villains stay (all 9 or a tighter set)?
- [ASK] Set a hard spend limit in the fal.ai dashboard (the airtight bill backstop — only you can).
- [ASK] Create the 3 consumable credit IAPs in ASC (`com.rci.haunt.credits25/75/200`) + submit. Launch plan = TikTok "ghost in my room" reaction clips, soft-launch now, blitz at Halloween.

## Useful commands and paths
- Build: `cd "/Volumes/LaCie/Eng Projects/Haunt" && xcodegen generate && xcodebuild -project Haunt.xcodeproj -scheme Haunt -destination 'generic/platform=iOS Simulator' build`
- Proxy health: `curl -s https://haunt-proxy-production.up.railway.app/health`
- Rotate fal key: `cd ~/haunt-proxy && railway variables --service haunt-proxy --set FAL_KEY=...`
- Bundle `com.rci.haunt`, Team `YKQA4JQPGQ`. Secrets in gitignored `Haunt/Secrets.swift`.
- Proxy app secret: `/tmp/haunt_secret.txt` (also in `Secrets.swift`).

## User's note for this handoff
(none)
