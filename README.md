# OpenChord

OpenChord is a clean-room macOS Apple Music companion built with SwiftUI and MusicKit. It is an original replacement path—not a trial bypass or code clone—designed for dense desktop browsing, search, playback, and personal library control.

## Features

- **Catalog Search** — Search Apple Music's full catalog (songs, albums, playlists, artists)
- **Library Search** — Search your personal Apple Music library
- **Playback Controls** — Play, pause, skip, shuffle, repeat via `ApplicationMusicPlayer`
- **Queue Management** — View and control the upcoming queue
- **Library Browse** — Browse downloaded songs, albums, playlists, and artists
- **Configurable Music Home** — Independently loading library/chart sections with persisted order, layout, item limit, and artwork shape
- **Detail Screens** — Album and playlist tracks plus artist albums/top songs with play and queue actions
- **Customizable Dashboard** — Normalize and drag-reorder Spotlight, Quick Actions, Queue Peek, Library Snapshot, and Status cards; the order persists locally
- **Themes** — Midnight (dark), Paper (light), Ember (dark) with custom gradients
- **Recent Searches** — Quick access to previous search terms
- **Authorization** — Handles MusicKit authorization flow
- **Original App Icon** — The source SVG and packaged macOS ICNS are included under Resources/
- **Artwork Loading** — MusicKit artwork is rendered through Apple’s native `ArtworkImage` view, including local macOS library artwork

## Requirements

- macOS 14+ (Sonoma or later)
- Xcode 16+ or Swift 6
- Active Apple Music subscription

OpenChord does not ship with a personal Apple Music token or API key. Each user authorizes the app through MusicKit on their own device. Developers building from source must configure MusicKit for their own Apple Developer team; no credentials belong in this repository.

For a signed build, register the bundle identifier with your own team and enable the MusicKit App Service for that App ID in Apple Developer. The package includes the required `NSAppleMusicUsageDescription`; it does not include a developer token, user token, private key, or entitlement tied to Elliot’s account.

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

The packaged app includes the original OpenChord icon from Resources/OpenChordIcon.svg and Resources/OpenChord.icns. On Home, drag a card by its handle and drop it on the upper or lower half of another card to place it before or after that card.

The local package is ad-hoc signed for smoke testing. It is not a notarized release; sign it with your own team before distributing it to other users.

To package for your own registered App ID, set the bundle identifier and signing identity without placing credentials in the repository:

```bash
OPENCHORD_BUNDLE_IDENTIFIER=com.example.OpenChord \
OPENCHORD_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" \
bash package-app.sh
```

The ad-hoc default is useful for local UI smoke tests, but Apple Music catalog relationships and some MusicKit requests require the signed App ID to be registered by the builder's team.

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
  AppModel.swift       — Application state and v2 environment integration
  Views.swift          — Root view, section views, search, library, queue, settings
  RootView.swift       — Main window layout with sidebar navigation
  Core/
    Models/             — Stable media, playback, home, and search value types
    Services/           — MusicKit implementations plus preview/mock services
    Persistence/        — Backward-compatible settings boundary
    Support/            — Typed errors and feature flags
Tests/OpenChordTests/   — Pure model, persistence, and preview-service tests
```

The v2 architecture is being migrated incrementally toward injected MusicKit services, mockable previews/tests, typed errors, and versioned local persistence. Authorization, catalog search, library search/browse, detail loading, playback, and configurable Home sections now run through the environment boundary. The existing settings payload remains backward-compatible; v2 Home configuration is an additive optional field.

## Design Philosophy

OpenChord was built as a **clean-room implementation** — no reverse-engineered APIs, no private frameworks, no trial exploitation. It uses only Apple's public MusicKit framework, which requires an active Apple Music subscription. The goal is a native, performant companion that respects platform conventions.

OpenChord makes no network calls beyond Apple Music and explicitly configured optional integrations. It does not use private Apple Music endpoints, scrape credentials, download audio, or include analytics by default.

## License

MIT License — see [LICENSE](LICENSE).
