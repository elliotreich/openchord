# Task: Surface the Library Browser + add detail screens in OpenChord

You are continuing a clean-room macOS Apple Music companion app called **OpenChord**
(SwiftUI + MusicKit). The repo is at `/Users/elliot.reich/MEGA/Projects/OpenChord`.
`swift build` currently passes. Keep it passing — build after every meaningful change.

## Hard constraints
- macOS 14+, SwiftUI, Swift 6 tools. `@preconcurrency import MusicKit` is used to keep
  concurrency checks manageable — keep that pattern.
- Do NOT add third-party dependencies. Stdlib + SwiftUI + MusicKit only.
- Do NOT copy any Soor code/assets. Original UI only.
- Do NOT touch git history. Do NOT modify `AppModel`'s persistence format in a
  backwards-incompatible way.
- All UI work is in `Sources/OpenChord/`. Build with `swift build` from that dir.

## Current state (already done — do not redo)
`AppModel.swift` already has a working library-browser data layer:
- `@Published var libraryBrowse = LibraryBrowseSnapshot()` (fields: songs, albums,
  playlists, artists — each `[SearchHit]` — plus `downloadedOnly`, `isLoading`, `lastUpdated`, `totalCount`)
- `@Published var libraryBrowseDownloadedOnly = false`
- `func loadLibraryBrowse() async` — loads the four kinds via `MusicLibraryRequest`
- `func setLibraryBrowseDownloadedOnly(_ newValue: Bool)` — toggles + reloads
- `SearchHit` enum cases: `.song/.album/.playlist/.artist(_, source:)`, each exposing
  `title`, `subtitle`, `artworkURL`, `symbolName`, `playableDescription`, `isPlayable`, `id`.
- Playback helpers on AppModel: `play(_:)`, `playNext(_:)`, `addToQueue(_:)`.

**The gap:** NOTHING in `Views.swift` or `RootView.swift` references `libraryBrowse`.
The data loads into the model and is never shown. The Library screen today only shows
library *search* results (`libraryResults` via `performLibrarySearch`).

## What to build

### 1. Library browser UI (primary)
In the Library section (find the Library view in `Views.swift`), ABOVE or alongside the
existing library-search field, add a browse experience driven by `model.libraryBrowse`:
- A "Downloaded only" toggle bound through `model.libraryBrowseDownloadedOnly` /
  `model.setLibraryBrowseDownloadedOnly(_:)`.
- Four horizontal-scrolling rows (Songs / Albums / Playlists / Artists), each showing the
  items from the matching `libraryBrowse` array as artwork cards (use `AsyncImage` on
  `hit.artworkURL`, falling back to `hit.symbolName`). Reuse existing card/row styling in
  `Views.swift` if a suitable component exists — match the surrounding style, don't invent
  a new visual language.
- A loading indicator when `libraryBrowse.isLoading`, and an empty/needs-auth message when
  `libraryBrowse.totalCount == 0`.
- A refresh affordance that calls `model.loadLibraryBrowse()`.

### 2. Detail screens
Add tappable navigation so selecting an album/playlist/artist opens a detail view:
- **Album detail**: load the album's tracks via MusicKit
  (`album.with([.tracks])`) and list them; each track row offers Play / Play Next / Add to Queue
  (reuse `model.play/playNext/addToQueue`).
- **Playlist detail**: same pattern via `playlist.with([.tracks])` (or `.entries` if that's
  what the local SDK exposes — verify against the installed MusicKit swiftinterface before
  guessing).
- **Artist detail**: load `artist.with([.albums, .topSongs])` where available; show albums +
  top songs. If a relationship isn't available in the local SDK, omit it gracefully rather
  than failing the build.
- Song rows just play / queue; no separate detail screen needed.

Wire navigation with `NavigationStack`/`NavigationLink` (or the app's existing navigation
pattern in `RootView.swift` — check first and match it).

### 3. Verify MusicKit surface before using it
Before calling any relationship/property, confirm it exists in the locally installed SDK:
```
find /Applications/Xcode*.app /Library/Developer -name "MusicKit.swiftinterface" 2>/dev/null
```
grep that file for `tracks`, `entries`, `topSongs`, `albums`, `with(` to confirm exact
signatures. Do not invent APIs from memory — the SDK version here is authoritative.

## Definition of done
- `swift build` passes with no errors and no new warnings.
- Launching the Library section shows the four browse rows + downloaded-only toggle.
- Album/playlist/artist items navigate to a working detail screen with play/queue actions.
- Run `bash scripts/package-app.sh` and confirm it still produces `dist/OpenChord.app`
  and that `plutil -lint dist/OpenChord.app/Contents/Info.plist` passes.

## Output
End with a MANIFEST: every file changed, what changed in each, the final `swift build`
output line, and the `package-app.sh` + `plutil` results. If you had to omit any MusicKit
relationship because the local SDK lacked it, say which and why.
