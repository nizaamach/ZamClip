# ZamClip Spotlight UI Redesign

## Status

Approved direction: Apple Spotlight Classic.

## Goal

Make the clipboard palette feel like a native macOS search surface: search is the first visual priority, results are compact and scannable, selection is keyboard-first, and richer content appears only when useful.

## Layout

- Use a centered 620 x 520 floating panel.
- Replace the title/header block with one primary search bar containing search, clear, actions, and close controls.
- Replace the heavy segmented picker with quiet All and Pinned filter pills.
- Use one consistent result row language for text, images, and files.
- Give file rows category-specific icons for folders, media, documents, code, archives, and mixed selections.
- Keep the selected preview below the result list so the list remains the primary navigation surface.
- Render image files such as PNG screenshots as image thumbnails and selected previews when the referenced file is available.
- Keep a small keyboard hint row at the bottom: navigation, paste, click selection, and close.

## Visual Treatment

- Use regular macOS material and a restrained shadow on the panel.
- Use a 20-point outer radius and 10- to 12-point row radii.
- Use system typography without rounded display styling.
- Use the accent color for selection and focus only.
- Show source app and relative capture time as secondary metadata.
- Use smaller, consistent image thumbnails so all result rows share a common rhythm.

## Interaction

- The global shortcut opens the panel with an empty, focused search field.
- Typing filters text, file names, paths, and source apps.
- Clicking selects an item; it does not paste immediately.
- Every row exposes a visible pin toggle; its action only pins or unpins the item.
- Double-clicking an item pastes it.
- Arrow keys move selection and keep the selected row in view.
- Enter pastes the selected item for every content type.
- Context menus expose Paste, Pin/Unpin, and Delete.
- Long text, images, and files show contextual selected previews.

## Motion

- Do not add custom animations to the palette.
- Panel entrance and exit are immediate.
- Selection, scroll, and preview changes are immediate.
- Native system behavior may animate outside the palette, but ZamClip does not add delay or easing.

## Technical Boundaries

- Keep clipboard capture and persistence unchanged except for UI-facing metadata already present in the model.
- Keep file history reference-only.
- Keep the existing AppKit panel and SwiftUI content architecture.
- Keep automatic paste and Accessibility handling unchanged behind the Enter/context-menu actions.

## Verification

- Build debug and release targets.
- Verify search focus on panel open.
- Verify click selection, arrow navigation, scroll following, and Enter paste for text, image, and file items.
- Verify reduced motion skips panel animation.
- Verify the settings window and existing persistence remain functional.
