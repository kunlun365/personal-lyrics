# Product Requirements Document — Mac Spotify Lyrics

## Summary
A macOS app that shows a floating, always-on-top lyrics overlay synced line-by-line to whatever is currently playing in the Spotify desktop app. Install and it works — no login, no API credentials, no configuration required to get started.

## Goals
- Floating lyrics window that tracks the current Spotify track in real time.
- Line-by-line (karaoke-style) highlighting synced to playback position, not just static/plain lyrics.
- Zero setup: no Spotify Developer account, no OAuth, no API keys, no user-supplied credentials for the default experience.
- Lightweight: small install size, low idle memory/CPU, native macOS feel.

## Non-Goals (v1)
- No lyrics editing/contribution features.
- No support for other music players (Apple Music, YouTube Music, etc.) — Spotify desktop app only.
- No mobile/iOS version.
- No bundled paid/token-gated lyrics providers by default.

## Users
Mac users who use the Spotify desktop app and want a persistent, unobtrusive lyrics overlay without going through any account linking or setup flow.

## Core Requirements

### 1. Playback detection
- Detect currently playing track (title, artist, duration, playback position, play/pause state) from the local Spotify desktop app.
- No network calls to Spotify's API, no user authentication.
- Must handle: Spotify not running, Spotify paused, no track loaded.

### 2. Lyrics retrieval
- Fetch synced (timestamped) lyrics automatically based on track metadata (artist/title/duration).
- Default lyrics source requires no account, token, or credentials from the user.
- Graceful degradation per track:
  - Synced lyrics available → line-by-line highlight.
  - Only plain-text lyrics available → static/scrolling display.
  - No match found → clear "no lyrics found" state, not a crash or blank screen.

### 3. Line-by-line sync
- Highlight/advance the current lyric line in step with actual audio playback position.
- Sync should feel smooth (interpolated), not stepped/laggy.

### 4. Extensible lyrics sources (v1.1+, not blocking v1)
- Users may optionally add additional lyrics sources beyond the default.
- Any source requiring a token/credential is supplied and owned by the user, never bundled by the app.
- Default out-of-box experience never requires this step.

### 5. Floating overlay UI
- Always-on-top floating panel, unobtrusive.
- Menu bar control to show/hide, and access settings.

## Success Criteria
- User can download, open, and see synced lyrics for a currently playing mainstream track with zero configuration steps.
- App handles missing/partial lyrics coverage without breaking the experience.
- Install size and idle resource usage stay well below typical Electron-based alternatives.

## Known Constraints / Risks
- Lyrics coverage depends on the free/default lyrics source (community-maintained); obscure tracks, remixes, live versions, or non-English catalogs may lack synced or any lyrics. Mitigated by graceful degradation and the future optional-source extension point.
- Relies on Spotify desktop app's local scripting interface; behavior may shift with Spotify app updates.
