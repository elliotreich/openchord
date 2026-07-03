# OpenChord

OpenChord is a clean-room macOS Apple Music companion built as an original replacement path rather than a trial bypass or code clone.

## What is here

- SwiftUI macOS app shell
- Apple Music authorization hooks
- Catalog search and library search
- Application queue playback controls
- Customizable home sections
- Theme selection

## Build

```bash
cd OpenChord
swift build
```

## Package as an app

```bash
cd OpenChord
bash scripts/package-app.sh
open dist/OpenChord.app
```
