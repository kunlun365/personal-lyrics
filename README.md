# Floating Lyrics — Synced Spotify Lyrics for macOS

**A free, open-source macOS menu bar app that shows real-time synced lyrics for whatever is playing
in Spotify — as a floating desktop overlay, in your menu bar, and on the MacBook Pro Touch Bar.**

No login. No Spotify API keys. No account. It reads playback locally from the Spotify desktop app
and fetches time-synced lyrics from [LRCLib](https://lrclib.net), a free, no-auth lyrics database.

[![Download](https://img.shields.io/github/v/release/malemalice/floating-lyrics?label=Download&style=for-the-badge)](https://github.com/malemalice/floating-lyrics/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=for-the-badge&logo=apple)](https://github.com/malemalice/floating-lyrics/releases/latest)
[![Ko-fi](https://img.shields.io/badge/Support%20me%20on-Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/malemalice)

---

## What it does

Spotify's desktop app has no always-on-top lyrics window, no menu bar lyrics, and no Touch Bar
lyrics. Floating Lyrics adds all three, so you can follow along while you work in another app.

| Where | What you get |
| --- | --- |
| **Floating overlay** | A borderless, always-on-top window with the current line highlighted and the next line dimmed below. Drag it anywhere, resize it, restyle it. It never steals focus while you type. |
| **Menu bar** | The current lyric line right in the macOS menu bar, next to the clock. |
| **Touch Bar** | Lyrics on the Control Strip *and* a wide readable bar — visible no matter which app is frontmost. |

### Features

- **Real-time synced lyrics** — line-by-line, timed to the track position, not a static lyric dump
- **Karaoke-style transitions** — the current line slides and fades up as the next one rises
- **Works with the free Spotify tier** — no Premium and no developer account required
- **Fully customizable overlay** — background color, text color, opacity, font family, text size
- **Resizable and draggable** — position and size persist across restarts
- **Touch Bar support** — for MacBook Pro 2016–2020, persistent across apps
- **Custom lyrics sources** — add your own lyrics API endpoint with `{artist}`, `{title}`,
  `{duration}` placeholders; sources are tried in order
- **Private by design** — everything runs locally; the app has no analytics, no accounts, and
  bundles no credentials
- **Lightweight** — a native Swift/SwiftUI menu bar app with no Dock icon

## Install

### Download the app (recommended)

1. Download the latest `FloatingLyrics.zip` from
   **[Releases](https://github.com/malemalice/floating-lyrics/releases/latest)**
2. Unzip it and drag **MacSpotifyLyrics.app** into your **Applications** folder
3. Because the app is ad-hoc signed rather than notarized, macOS Gatekeeper will block the first
   launch. To open it: **right-click the app → Open → Open**, or run once:

   ```bash
   xattr -dr com.apple.quarantine /Applications/MacSpotifyLyrics.app
   ```

4. On first launch macOS asks for permission to control Spotify — this is the AppleScript access
   used to read the current track. Click **OK**. (If you miss it: System Settings → Privacy &
   Security → Automation.)

The download is a **universal binary** — it runs natively on both Apple Silicon and Intel Macs.

### Build from source

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/malemalice/floating-lyrics.git
cd floating-lyrics

# Fast inner loop (raw binary, not a bundle)
swift run

# Build a real .app bundle
./Scripts/build-app.sh                # this machine's architecture
./Scripts/build-app.sh --universal    # Intel + Apple Silicon, release build
open build/MacSpotifyLyrics.app
```

## How to use

1. Open **Spotify** and play a song.
2. Launch **Floating Lyrics**. It lives in the menu bar as a ♫ icon — there's no Dock icon and no
   main window.
3. Lyrics appear in the floating overlay automatically. Drag it where you want it and drag its edge
   to resize.

From the menu bar icon you can:

| Menu item | What it does |
| --- | --- |
| **Show/Hide Overlay** | Toggle the floating lyrics window |
| **Show Lyrics in Menu Bar** | Put the current line in the menu bar itself |
| **Show Lyrics in Control Strip** | Show lyrics on the Touch Bar (Touch Bar Macs only) |
| **Settings…** | Appearance and lyrics sources |
| **Support on Ko-fi ☕** | Buy me a coffee |

### Customizing the look

**Settings → Appearance** controls background color, text color, background opacity, font family,
and text size. **Reset to Defaults** restores the original look and re-centers the overlay.

### Touch Bar lyrics

On a Touch Bar MacBook Pro, enable **Show Lyrics in Control Strip**. You get a compact item in the
Control Strip plus a wide, readable lyrics bar in the main Touch Bar region — and unlike the app
region, it stays visible while you're in Spotify, a browser, or any other app. Tap the Control
Strip item to collapse or restore the wide bar.

> Note: this uses private macOS APIs (the same approach Pock and BetterTouchTool use), because
> Apple provides no public way for a menu bar app to put custom content on the Touch Bar. The app
> checks for these APIs at runtime and simply skips the feature if a future macOS removes them.

### Adding a custom lyrics source

**Settings → Sources → +** lets you add your own endpoint. Use `{artist}`, `{title}`, and
`{duration}` as placeholders, and optionally supply an API key header. Sources are tried top to
bottom and the first match wins. LRCLib is the default and needs no configuration.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| **"App is damaged / can't be opened"** | Gatekeeper quarantine — right-click → Open, or run the `xattr` command above |
| **"No track playing"** | Make sure the Spotify **desktop app** is running and playing. The web player isn't supported. |
| **Nothing happens / no lyrics** | Grant Automation permission: System Settings → Privacy & Security → Automation → enable Spotify for this app |
| **"No lyrics found"** | LRCLib has no synced lyrics for that track. Try another song, or add a custom source. |
| **Touch Bar toggle is greyed out** | Your Mac has no Touch Bar, or macOS removed the private APIs |
| **Touch Bar item vanishes when I expand the Control Strip** | Expected — macOS hides third-party items to show all system buttons |

## How it works

- **Playback** — polls the Spotify desktop app via AppleScript for track, artist, duration, and
  position. No Spotify Web API, so no OAuth and no Premium requirement.
- **Lyrics** — fetches `.lrc` timed lyrics from LRCLib, parses the timestamps, and caches results
  per track.
- **Sync** — maps the current playback position onto the parsed lines to pick the active line.
- **Overlay** — a borderless non-activating `NSPanel`, so it floats above other windows without
  ever taking keyboard focus.

See [docs/PRD.md](docs/PRD.md) and [docs/TRD.md](docs/TRD.md) for full product and technical detail.

## Requirements

- macOS 13 (Ventura) or later
- Spotify desktop app (free or Premium)
- Apple Silicon or Intel Mac

## Support this project

Floating Lyrics is free and open source. If it's useful to you, consider buying me a coffee:

[![Ko-fi](https://img.shields.io/badge/Support%20me%20on-Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/malemalice)

## Credits

- Lyrics from [LRCLib](https://lrclib.net) — free, open, no-auth
- Built by [@malemalice](https://github.com/malemalice)

Not affiliated with or endorsed by Spotify AB. Spotify is a trademark of Spotify AB.

---

<sub>**Keywords:** Spotify lyrics macOS · synced lyrics Mac app · floating lyrics overlay ·
desktop lyrics Mac · real-time lyrics Spotify · macOS menu bar lyrics · Touch Bar lyrics ·
karaoke lyrics Mac · LRC lyrics viewer · always on top lyrics · Spotify lyrics widget</sub>
