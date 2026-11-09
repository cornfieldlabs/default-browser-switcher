# Default Browser Switcher

A tiny native macOS app for switching your default browser using only the keyboard.

Open it, pick a browser with **↑ / ↓**, press **↩**, and confirm the macOS prompt. The app then quits.

## Usage

| Key | Action |
| --- | --- |
| ↑ / ↓ (or ← / →, Tab) | Move the selection |
| 1–9 | Jump to that row |
| ↩ / Enter / Space | Set the selected browser as default |
| Esc | Quit without changing anything |

The browser that is currently the default is tagged **✓ Current**, and the list opens with it selected. You can also double-click a row.

macOS always asks you to confirm a change of default browser; there is no public API that skips that prompt.

## How browsers are detected

The app asks Launch Services (`NSWorkspace.urlsForApplications(toOpen:)`) for every app that can open `http://` links and every app that can open `https://` links, then keeps the apps that appear in both. Duplicate copies of an app (same bundle ID) are collapsed. Browsers you install later show up the next time you open the app.

## Build

Requires macOS 13+ and the Xcode command-line tools (`xcode-select --install`).

```bash
./build.sh
mv "Default Browser Switcher.app" /Applications/
```

`build.sh` compiles `main.swift` with `swiftc`, generates the app icon on first run (`make_icon.swift` → `AppIcon.icns`), writes `Info.plist` and ad-hoc signs the bundle.

## Files

- `main.swift` — the whole app
- `make_icon.swift` — draws the app icon
- `build.sh` — builds `Default Browser Switcher.app`
