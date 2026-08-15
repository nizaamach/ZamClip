# ZamClip

Compact, local-only macOS clipboard manager with a glass-style floating panel.

## Requirements

- macOS 14+
- Swift 6 toolchain

## Build

```sh
swift build
```

To create a runnable menu bar app bundle:

```sh
sh Scripts/build-app.sh
open dist/ZamClip.app
```

The app stores its history in `~/Library/Application Support/ZamClip`.
Direct paste may require enabling ZamClip under System Settings > Privacy & Security > Accessibility.

## Features

- Text and image clipboard history
- File and folder clipboard history, including multi-file selections
- File history stores references only; moved or deleted files are marked missing
- 500-item default retention limit
- Pinned items survive retention cleanup
- Duplicate items move to the top instead of creating a second entry
- Spotlight-style floating search palette
- Menu bar utility with `Command-Shift-V` global shortcut
- Live search across clipboard text, file names, paths, and source apps
- Full-text preview for selected long text items
- Larger preview for selected image items
- Image files such as PNG screenshots show a thumbnail and selected preview
- File rows use category icons for folders, media, documents, code, archives, and more
- Every item has a visible pin toggle; clicking selects, double-clicking pastes, and the context menu also exposes `Paste`
- Arrow keys move the selection; `Enter` pastes the selected item; `Escape` or `X` closes the panel
- Local JSON metadata and local image files
- Configurable sensitive-app exclusions
