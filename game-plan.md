# Game Plan — Flipside (Gravity-Flip Endless Arcade, iOS, Offline, Ad-Monetized)

## Concept
- **Genre:** endless arcade runner. One-thumb play, sessions of 30s–3min.
- **Core loop:** play → die → see score → retry instantly (or watch rewarded ad to continue) → chase high score.
- **Hook — Gravity Flip:** player auto-runs through a horizontal corridor; one tap flips gravity so the player falls to the ceiling (and back). Obstacles spawn on floor AND ceiling; gaps force well-timed flips. Mid-air you can't flip again until you land — that constraint is where the skill lives.
- **Working title:** Flipside (check App Store availability first; backups: Gravvy, Upside)

## Mechanic details
- Flip triggers on tap-DOWN (not tap-up) — responsiveness is everything
- Flip arc ~0.25s; player is vulnerable mid-flip; no double-flip until landed
- Obstacle patterns: floor spike, ceiling spike, both-sides pinch (thread it mid-flip), moving blocks unlocked later
- Difficulty: scroll speed +5% every 10s, capped at 2.2x; pattern pool widens with distance
- Score = distance; coins as optional pickups (feeds "double coins" rewarded ad)
- Target feel: first death at ~20–40s for a new player; visible skill growth by session 3

## Tech stack
- **Engine:** SpriteKit (native, free, ideal for 2D arcade; no Unity bloat)
- **Language:** Swift; SwiftUI for menus/UI around the SKScene
- **Persistence:** UserDefaults for high score/settings/coins; no backend
- **Extras:** Game Center leaderboard, CoreHaptics

## Offline-first design (the important part)
100% playable with no connection:
- All assets bundled; no remote config needed to boot
- Ads are an enhancement layer, never a dependency:
  - No connection → no banner (space collapses), no interstitials, "continue" option hidden (or costs coins instead)
  - Never show a loading spinner for an ad. Preload when connected; if none ready, skip silently
- Connectivity check (NWPathMonitor) gates every ad opportunity; preloaded rewarded ads can still play offline
- Game Center syncs scores when back online

## Ad strategy (AdMob, all formats)
- **SDK:** Google AdMob (largest fill, simplest). AppLovin mediation later if revenue justifies it.
- **Rewarded (highest eCPM, player-positive):**
  - "Continue run" after death — max 1 per run
  - "Double coins" on game-over
  - Preload next rewarded immediately after one plays
- **Interstitial:**
  - Only on game-over screen, never mid-gameplay
  - Caps: not before 3 total runs, max 1 per 2–3 deaths, min 60s apart, never within 5s of a rewarded ad
- **Banner:**
  - Menu + game-over screens ONLY; adaptive, anchored bottom, collapses on no-fill
- **Remove Ads IAP:** $3.99 one-time. Removes banner + interstitials, KEEPS rewarded. Often 20–40% of revenue — don't skip.

## Compliance checklist
- ATT prompt before personalized ads (ask after first game-over, not at launch); denied → non-personalized ads
- SKAdNetwork IDs in Info.plist (AdMob's published list)
- PrivacyInfo.xcprivacy declaring AdMob data collection; App Privacy labels to match
- If kids could be the audience: age-gate or contextual-only ads (COPPA / guideline 1.3)
- Ads clearly closable, no trick-taps (guideline 4.x)

## Metrics that matter
- D1 retention > 30% and 3+ runs/session BEFORE investing in ads
- Rewarded engagement target: 20%+ of eligible players
- ARPDAU once live; interstitial frequency is the lever, churn is the cost

## Build order (matches game-build-prompts.md)
1. Core gravity-flip gameplay — fun BEFORE monetization
2. Menus, game over, high score, juice (haptics, particles, screen shake)
3. Game Center + settings
4. AdMob behind an offline-safe AdManager
5. Remove Ads IAP
6. Pre-release audit, store listing, screenshots
7. TestFlight → release checklist
