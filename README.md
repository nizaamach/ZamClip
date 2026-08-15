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
- 500-item default retention limit
- Pinned items survive retention cleanup
- Duplicate items move to the top instead of creating a second entry
- Compact floating glass panel
- Menu bar utility with `Command-Shift-V` global shortcut
- Selecting an item restores the previous app and sends `Command-V`
- Arrow keys move the selection; `Enter` pastes the selected item; `Escape` or `X` closes the panel
- Local JSON metadata and local image files
- Configurable sensitive-app exclusions
