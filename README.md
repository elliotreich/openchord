# OpenChord

A clean-room macOS Apple Music companion app built with SwiftUI and MusicKit. OpenChord is an original replacement path — not a trial bypass or code clone — designed for browsing, searching, and controlling your Apple Music library from a native interface.

## Features

- **Catalog Search** — Search Apple Music's full catalog (songs, albums, playlists, artists)
- **Library Search** — Search your personal Apple Music library
- **Playback Controls** — Play, pause, skip, shuffle, repeat via `ApplicationMusicPlayer`
- **Queue Management** — View and control the upcoming queue
- **Library Browse** — Browse downloaded songs, albums, playlists, artists
- **Customizable Home** — Reorder/configure home screen sections (Spotlight, Quick Actions, Queue Peek, Library Snapshot, Status)
- **Themes** — Midnight (dark), Paper (light), Ember (dark) with custom gradients
- **Recent Searches** — Quick access to previous search terms
- **Authorization** — Handles MusicKit authorization flow

## Requirements

- macOS 13+ (Ventura or later)
- Xcode 15+ or Swift 5.9+
- Active Apple Music subscription

## Build & Run

```bash
# Clone and build
git clone <repo-url> OpenChord
cd OpenChord
swift build -c release

# Run from terminal
swift run OpenChord

# Or package as .app bundle
bash scripts/package-app.sh
open dist/OpenChord.app
```

## Tech Stack

- **Language**: Swift 5.9
- **UI**: SwiftUI
- **Music**: Apple MusicKit (`MusicCatalogSearchRequest`, `MusicLibrarySearchRequest`, `ApplicationMusicPlayer`)
- **Persistence**: `UserDefaults` (settings, home sections, theme, recent searches)
- **Minimum OS**: macOS 13 (Ventura)

## Architecture

```
Sources/OpenChord/
  OpenChordApp.swift   — App entry point, window + settings scenes
  AppModel.swift       — Main observable state (search, playback, library, settings)
  Models.swift         — Data models (SearchHit, CanonicalProduct, QueueSnapshot, etc.)
  Views.swift          — Root view, section views, search, library, queue, settings
  RootView.swift       — Main window layout with sidebar navigation
```

## Design Philosophy

OpenChord was built as a **clean-room implementation** — no reverse-engineered APIs, no private frameworks, no trial exploitation. It uses only Apple's public MusicKit framework, which requires an active Apple Music subscription. The goal is a native, performant companion that respects platform conventions.

## License

MIT License — see [LICENSE](LICENSE).
