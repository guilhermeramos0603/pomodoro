# Pomodoro

A floating pomodoro timer for macOS. Native Swift (AppKit + SwiftUI), no dependencies.

- **Always on top** — a non-activating panel that stays above every other window, on all
  Spaces and over full-screen apps. Clicking it never steals focus from what you are doing.
- **Black, translucent, blurred** — three sliders: black opacity, blur strength (off →
  five system materials) and overall window opacity.
- **Two sequence modes** — *Classic* (focus / short break / long break + rounds before a long
  break) and *Custom* (any list of blocks, drag to reorder, loops forever).
- **Menu bar** item with the live countdown; no Dock icon.

## Build

```sh
./build.sh            # builds dist/Pomodoro.app
./build.sh --install  # builds, copies to /Applications and launches it
```

Requires the Xcode command line tools (Swift 5.9+). macOS 13 or later.

## Using it

- Drag the panel anywhere by its background; the position is remembered.
- ▶ / ⏸ start and pause, ⏭ skips to the next block, ↺ restarts the current block,
  ⚙︎ opens Settings.
- The coloured strip is the whole sequence — coral is focus, mint is a short break,
  blue is a long break. Click any segment to jump to it.
- Right-click the panel for Settings / Hide / Quit, or use the menu bar item.
- Settings are saved to `UserDefaults` as soon as you change them.

## Layout

| File | What it holds |
|---|---|
| `Sources/Pomodoro/main.swift` | entry point |
| `Sources/Pomodoro/AppDelegate.swift` | panel, menu bar item, settings window, appearance |
| `Sources/Pomodoro/Panel.swift` | the floating `NSPanel`, blur backdrop, drag handling |
| `Sources/Pomodoro/Engine.swift` | the timer: sequence, countdown, auto-start, chime |
| `Sources/Pomodoro/Model.swift` | blocks, sequence modes, all persisted settings |
| `Sources/Pomodoro/AppSettings.swift` | persistence to `UserDefaults` |
| `Sources/Pomodoro/TimerView.swift` | the panel UI |
| `Sources/Pomodoro/SettingsView.swift` | the three settings tabs |
| `Sources/Pomodoro/Snapshot.swift` | dev helper: `Pomodoro --snapshot out.png` |

## Notes

- The countdown runs off a deadline (`Date`), not off tick accumulation, so it does not
  drift and survives the machine sleeping.
- The blur is `NSVisualEffectView` with public materials only. macOS has no public API for a
  free-form blur radius, so the "blur" slider picks between five materials of increasing
  density rather than a continuous radius.
- The app is ad-hoc signed by `build.sh`. It is not notarised, which is fine for local use.
