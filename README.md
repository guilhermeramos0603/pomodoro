# Pomodoro

A floating pomodoro timer for macOS. Native Swift (AppKit + SwiftUI), no dependencies.

- **Always on top** — a non-activating panel that stays above every other window, on all
  Spaces and over full-screen apps. Clicking it never steals focus from what you are doing.
- **Black, translucent, blurred** — black opacity, blur strength (off → five system materials)
  and overall window opacity.
- **Resizable, up to the whole screen** — drag the grip in the bottom-right corner or any edge,
  or use *Fill screen* from the menu bar. Width and height are free.
- **Window size and timer size are independent** — expanding the panel gives the timer more empty
  room around it, it does not inflate the digits. The *Timer size* slider (50–300%) is what
  scales the content, and it is redrawn at real point sizes, so text stays sharp.
- **Monochrome** — no colour at all; the phases read as brightness tiers.
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

- Drag the panel anywhere by its background; position and size are remembered.
- ▶ / ⏸ start and pause, ⏭ skips to the next block, ↺ restarts the current block,
  ⚙︎ opens Settings.
- The strip is the whole sequence — a wide bright tick is focus, a short dim one is a short
  break, a medium one is a long break. Click any segment to jump to it.
- Right-click the panel for Settings / Hide / Quit, or use the menu bar item, which also has
  *Fill screen* and *Reset size*.
- *Fill screen* stops at the menu bar and the Dock on purpose: a full-screen panel swallows
  clicks, so the menu bar item stays reachable to shrink it back.
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
| `Sources/Pomodoro/Snapshot.swift` | dev helper: `Pomodoro --snapshot out.png [width] [height]` |

## Notes

- The countdown runs off a deadline (`Date`), not off tick accumulation, so it does not
  drift and survives the machine sleeping.
- Preferences decode leniently (`decodeIfPresent` with defaults), so a build that adds a
  setting does not throw away the ones already saved.
- The blur is `NSVisualEffectView` with public materials only. macOS has no public API for a
  free-form blur radius, so the "blur" slider picks between five materials of increasing
  density rather than a continuous radius.
- The app is ad-hoc signed by `build.sh`. It is not notarised, which is fine for local use.
