# Technical Requirements Document — Mac Spotify Lyrics

## Platform & Stack
- **Language/UI**: Swift, SwiftUI (overlay content) + AppKit (`NSPanel` for the floating window, menu bar item).
- **Distribution**: Compiled, signed `.app` bundle. No bundled runtime (rules out Electron, Python, Node) — chosen specifically to keep install size and idle memory low and avoid any user-side runtime setup.
- **Rationale**: Native Swift gives the smallest shipped artifact (~5-15MB vs. 150-300MB for Electron) and lowest idle memory (~20-40MB vs. 150-300MB), at the cost of somewhat more boilerplate to write than a scripting/web-based approach. This tradeoff is correct given the product's zero-setup, lightweight requirement.

## Architecture

### Data flow
```
SpotifyPoller (AppleScript, timer loop)
  → PlaybackSnapshot (title, artist, duration, position, isPlaying)
  → AppState (published state)
      → on track change: LyricsSourceChain.resolve(artist, title, duration)
          → LyricsCache (check first)
          → LRCLibProvider (default, no-auth)
          → LyricsResult: .synced([LyricLine]) | .plain(String) | .none
      → LyricsSyncEngine (interpolates position between polls, emits current line index)
          → LyricsOverlayView (renders in FloatingPanel)
```

## Module / File Breakdown

```
MacSpotifyLyrics/
├── App/
│   ├── MacSpotifyLyricsApp.swift        # @main, menu bar item + floating panel lifecycle
│   └── AppState.swift                    # ObservableObject: current track, position, current line index
│
├── Playback/
│   ├── SpotifyPoller.swift               # AppleScript bridge: track name/artist/duration/position, timer loop
│   └── PlaybackSnapshot.swift            # struct { title, artist, duration, position, isPlaying }
│
├── Lyrics/
│   ├── LyricsProvider.swift              # protocol: fetch(artist:title:duration:) -> LyricsResult
│   ├── LyricsResult.swift                # enum: synced([LyricLine]), plain(String), none
│   ├── LyricLine.swift                   # struct { timestamp: TimeInterval, text: String }
│   ├── Providers/
│   │   └── LRCLibProvider.swift          # default, no-auth implementation (lrclib.net)
│   ├── LyricsSourceChain.swift           # tries providers in user-configured order, first hit wins
│   └── LyricsCache.swift                 # in-memory + disk cache keyed by (artist, title, duration)
│
├── Sync/
│   └── LyricsSyncEngine.swift            # interpolates position + [LyricLine] → current line index
│
├── UI/
│   ├── FloatingPanel.swift               # NSPanel subclass: borderless, floating level, click-through toggle
│   ├── LyricsOverlayView.swift           # SwiftUI view: current + next line, highlight animation
│   └── MenuBarView.swift                 # menu bar icon: toggle overlay, pick sources, quit
│
└── Settings/
    ├── SettingsStore.swift               # UserDefaults-backed: provider order, custom sources, window prefs
    └── SettingsView.swift                # add/reorder lyrics sources, appearance
```

## Component Details

### SpotifyPoller
- Uses AppleScript (`tell application "Spotify"`) to read `player state`, `player position`, `current track {name, artist, duration}`.
- Polls on a timer (~200-300ms) — balances smoothness against AppleScript call overhead.
- Must detect and expose: Spotify not running, paused, no track loaded — consumers should not assume an active track.

### LyricsSourceChain / LyricsProvider
- `LyricsProvider` protocol is the only seam needed for v1: `fetch(artist:title:duration:) -> LyricsResult`.
- v1 ships with a single concrete provider (`LRCLibProvider`, calls lrclib.net's public no-auth API). The chain/protocol exists so a second source can be added later without refactoring, but no second provider is built until actually needed.
- Any future user-added source (e.g. token-gated) stores its credential in `SettingsStore`, supplied and owned by the user — never bundled or required by the app.

### LyricsSyncEngine
- Interpolates between poll ticks rather than only updating on each AppleScript call, since raw `player position` sampling is coarse/laggy — this is what makes line-by-line highlighting feel smooth instead of stepped.
- On each tick: compute interpolated elapsed time, find current line via binary search over `[LyricLine]` timestamps, emit index if changed.

### FloatingPanel
- `NSPanel` with `.borderless`, `.nonactivatingPanel` style, floating window level, positioned/persisted via `SettingsStore`.
- Optional click-through mode so the overlay doesn't intercept clicks meant for underlying apps.

## Non-Functional Requirements
- Idle memory target: comparable to other small native menu bar utilities (~20-40MB).
- No network calls beyond the configured lyrics provider(s) — no telemetry, no Spotify API calls.
- Graceful failure at every external boundary (Spotify not running, lyrics provider unreachable/no match) — never a crash or stuck UI state.

## Open Questions
- Multi-space/full-screen behavior for the floating panel (join all spaces vs. per-space) — to be decided during UI grooming.
- Local LRC cache eviction policy (size/age limits) — not blocking v1, revisit once real usage patterns are known.
