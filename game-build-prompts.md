# Flipside — Build Prompts (run in Claude Code, in order)

One prompt per session. Ship each step working before the next.

---

## Prompt 1 — Core gravity-flip gameplay
```
Create a new iOS game "Flipside" with SpriteKit + SwiftUI. Endless
gravity-flip runner:
- Player auto-runs right through a horizontal corridor with a floor
  and ceiling. Tapping flips gravity: player arcs to the opposite
  surface in ~0.25s. Cannot flip again until landed.
- Flip triggers on tap-DOWN (touchesBegan), not tap-up — input latency
  must be imperceptible.
- Obstacles spawn on both surfaces: floor spikes, ceiling spikes, and
  "pinch" patterns (obstacles on both sides forcing a well-timed flip
  through the gap). One collision = death.
- Difficulty: scroll speed +5% every 10 seconds, capped at 2.2x base.
  Pattern pool widens with distance.
- Score = distance traveled, shown during play. Coins spawn as
  occasional pickups on either surface.

Requirements:
- SwiftUI app shell hosting SKScene via SpriteView
- GameScene only renders and handles input; game state (score, coins,
  difficulty, run lifecycle) lives in a GameModel class
- All tuning numbers (speeds, spawn rates, flip duration, difficulty
  curve) in one Tuning.swift file
- Placeholder shapes (SKShapeNode) — no art yet; 60fps target
- Instant restart, no scene-reload lag

Tune so a new player's first death lands around 20-40 seconds.
```

## Prompt 2 — Game flow & juice
```
Add the full game loop around Flipside's core gameplay:
- Main menu: title, Play, high score, total coins
- Game-over screen: score, best score, coins earned, Retry, Menu
- High score + coin total persisted in UserDefaults
- Juice: haptic on flip-land and death, particle burst on death and
  coin pickup, subtle screen shake on death, simple SFX
- Smooth camera/world feel: slight player trail or squash-and-stretch
  on landing
- Pause on backgrounding, clean resume; instant retry preserved
```

## Prompt 3 — Game Center & settings
```
Add Game Center leaderboard for best distance: quiet authentication at
launch (no blocking UI if offline or declined), score submitted after
each run, leaderboard button on menu and game-over. Must work fine
when Game Center is unavailable.
Add settings: sound on/off, haptics on/off (persisted).
```

## Prompt 4 — AdMob with offline-safe wrapper (the critical one)
```
Integrate Google AdMob (SPM) with ALL ad logic behind a single
AdManager service. Flipside is offline-first: ads must NEVER block,
delay, or break gameplay.

AdManager requirements:
- Preloads one interstitial + one rewarded ad whenever connected
  (NWPathMonitor); reloads after each show
- isRewardedReady / isInterstitialReady flags the UI reads — if not
  ready, the ad option simply doesn't appear. No spinners, ever.
- Rewarded placements: (1) "Continue run" on death, max once per run;
  (2) "Double coins" on game-over
- Interstitial rules enforced INSIDE AdManager: never before 3 total
  runs, min 60s between shows, max 1 per 2 deaths, never within 5s of
  a rewarded ad
- Adaptive banner on menu + game-over only, never in gameplay; space
  collapses when no fill
- ATT: request after first game-over (not at launch); denied →
  non-personalized ads
- Google TEST ad unit IDs for now; real IDs in one config struct
- SKAdNetwork IDs in Info.plist; PrivacyInfo.xcprivacy for AdMob
- Unit-test the frequency-cap logic with an injected fake clock

Acceptance test: airplane mode → 10 runs → zero ad UI, zero errors,
zero delays.
```

## Prompt 5 — Remove Ads IAP
```
Add a $3.99 non-consumable "Remove Ads" via StoreKit 2:
- Removes banner + interstitials; rewarded ads REMAIN available
- Buy + Restore in settings; entitlement from
  Transaction.currentEntitlements at launch
- AdManager reads one adsRemoved flag — single source of truth
- Handle purchase success, cancel, pending, restore, and refund
  (entitlement revoked)
```

## Prompt 6 — Pre-release audit
```
Audit Flipside before App Store submission:
1. Full bug scan: force unwraps, retain cycles, main-thread violations,
  frame drops in obstacle-heavy moments, memory growth over 20 runs
2. Offline verification: every screen and flow in airplane mode
3. Ad compliance: ATT flow, privacy manifest vs AdMob docs, and the
  exact App Privacy label answers for App Store Connect
4. Generate: App Store description draft, keyword list (gravity, flip,
  runner, arcade, dodge...), and screenshot shot-list
Then walk me through the release checklist.
```

---

## Tips
- Create a new Claude Project "Flipside"; upload game-plan.md + this
  file as project knowledge
- Iterate on Tuning.swift constantly — feel is everything in this genre
- No ads until the game is fun without them; retention first
```
