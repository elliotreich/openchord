# OpenChord

OpenChord is a clean-room macOS Apple Music companion built with SwiftUI and MusicKit. It is an original replacement path—not a trial bypass or code clone—designed for dense desktop browsing, search, playback, and personal library control.

## Features

- **Catalog Search** — Search Apple Music's full catalog (songs, albums, playlists, artists)
- **Library Search** — Search your personal Apple Music library
- **Playback Controls** — Play, pause, skip, shuffle, repeat via `ApplicationMusicPlayer`
- **Queue Management** — View and control the upcoming queue
- **Library Browse** — Browse downloaded songs, albums, playlists, and artists
- **Customizable Home** — Reorder/configure home screen sections (Spotlight, Quick Actions, Queue Peek, Library Snapshot, Status)
- **Themes** — Midnight (dark), Paper (light), Ember (dark) with custom gradients
- **Recent Searches** — Quick access to previous search terms
- **Authorization** — Handles MusicKit authorization flow

## Requirements

- macOS 14+ (Sonoma or later)
- Xcode 16+ or Swift 6
- Active Apple Music subscription

OpenChord does not ship with a personal Apple Music token or API key. Each user authorizes the app through MusicKit on their own device. Developers building from source must configure MusicKit for their own Apple Developer team; no credentials belong in this repository.

## Build & Run

```bash
# Clone and build
git clone <repo-url> OpenChord
cd OpenChord
swift build -c release

# Run from terminal
swift run OpenChord

# Or package as an app bundle
bash package-app.sh
open dist/OpenChord.app
```

## Tech Stack

- **Language**: Swift 6
- **UI**: SwiftUI
- **Music**: Apple MusicKit (`MusicCatalogSearchRequest`, `MusicLibrarySearchRequest`, `ApplicationMusicPlayer`)
- **Persistence**: `UserDefaults` (settings, home sections, theme, recent searches)
- **Minimum OS**: macOS 14 (Sonoma)

## Architecture

```
Sources/OpenChord/
  OpenChordApp.swift   — App entry point, window + settings scenes
  AppModel.swift       — Current application state and MusicKit integration
  Views.swift          — Root view, section views, search, library, queue, settings
  RootView.swift       — Main window layout with sidebar navigation
```

The v2 architecture is being migrated incrementally toward injected MusicKit services, mockable previews/tests, typed errors, and versioned local persistence. The existing settings format remains backward-compatible during that migration.

## Design Philosophy

OpenChord was built as a **clean-room implementation** — no reverse-engineered APIs, no private frameworks, no trial exploitation. It uses only Apple's public MusicKit framework, which requires an active Apple Music subscription. The goal is a native, performant companion that respects platform conventions.

OpenChord makes no network calls beyond Apple Music and explicitly configured optional integrations. It does not use private Apple Music endpoints, scrape credentials, download audio, or include analytics by default.

## License

MIT License — see [LICENSE](LICENSE).
