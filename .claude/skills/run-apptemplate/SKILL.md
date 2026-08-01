---
name: run-apptemplate
description: Build, run, test, and drive the AppTemplate iOS SwiftUI app in the Simulator. Use when asked to build, run, launch, screenshot, or interact with AppTemplate, or to run its test suite.
---

AppTemplate is a SwiftUI iOS app (Clean Architecture, XcodeGen-generated project).
It's driven end-to-end with `xcodebuild` (build) + `xcrun simctl` (install/launch) +
`idb` (tap/type/screenshot/accessibility) via `.claude/skills/run-apptemplate/driver.sh`.
All paths below are relative to the repo root.

## Prerequisites

macOS with Xcode installed. These were all confirmed present/working in this
container — install whichever are missing:

```bash
brew install xcodegen swiftlint idb-companion   # idb-companion ships /opt/homebrew/bin/idb_companion
pip3 install --user fb-idb                       # the `idb` CLI itself; lands in ~/Library/Python/3.9/bin
```

`idb` won't be on `PATH` after a `--user` pip install — the driver exports the right
path itself (`~/Library/Python/3.9/bin`), so you don't need to.

## Build

```bash
xcodegen generate    # regenerates AppTemplate.xcodeproj from project.yml (not committed)
.claude/skills/run-apptemplate/driver.sh build
```

`driver.sh build` runs `xcodegen generate` and then `xcodebuild` for the
`AppTemplate-Dev` scheme against whichever simulator `driver.sh` resolves (see
`SIM_NAME` below). Build output goes to `build/` at the repo root (gitignored).

## Run (agent path)

Everything goes through the driver — build it, boot a simulator, install, launch,
then drive the UI:

```bash
D=.claude/skills/run-apptemplate/driver.sh
"$D" all                        # build + boot simulator + install + launch + wait for first render
"$D" screenshot /tmp/home.png   # save a screenshot
"$D" describe                   # dump the accessibility tree (point coords, not pixels)
"$D" tap 369 83                 # tap a point — get coordinates from `describe` or a screenshot
"$D" text "New Item"            # type into whatever's focused
"$D" terminate                  # stop the app

xcrun simctl openurl booted "apptemplate://items/42"  # deep link — not a driver.sh
                                                        # subcommand, plain simctl works fine
```

Screenshot pixel dimensions are 3x the point coordinates `tap`/`describe` use
(iPhone 17 Simulator: 1206x2622px screenshot, 402x874pt UI). Divide screenshot
pixel coordinates by 3 before passing to `tap`, or just read points straight out
of `describe`.

| command | what it does |
|---|---|
| `build` | `xcodegen generate` + `xcodebuild build` for `AppTemplate-Dev` |
| `boot` | boot the simulator, open Simulator.app, connect `idb` |
| `install` | `xcrun simctl install` the built `.app` |
| `launch` / `terminate` | `xcrun simctl launch`/`terminate` the Dev bundle |
| `uninstall` | `xcrun simctl uninstall` — clears the SwiftData cache too |
| `all` | build + boot + install + launch + wait for first real render |
| `wait` | poll the accessibility tree until app content appears (post-splash) |
| `screenshot <path.png>` | `idb screenshot` |
| `describe` | `idb ui describe-all` — accessibility tree with point-coordinate frames |
| `tap <x> <y>` / `text <str>` / `key <code>` | `idb ui` input injection |

Default simulator is `"iPhone 17"` (iOS 26.5); override with `SIM_NAME="iPhone 17 Pro" "$D" all`.
`driver.sh` resolves the name to a UDID itself via `xcrun simctl list devices -j`.

## Run (human path)

```bash
xcodegen generate && open AppTemplate.xcodeproj
```

Pick the `AppTemplate-Dev` scheme and hit Run in Xcode — the Dev config uses an
in-memory mock repository, so it needs no backend.

## Test

```bash
D=.claude/skills/run-apptemplate/driver.sh
xcodebuild -project AppTemplate.xcodeproj -scheme AppTemplate-Dev -configuration Debug-DEV \
  -destination "id=$(SIM_NAME="${SIM_NAME:-iPhone 17}" python3 -c "
import json, subprocess, os
d = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))
name = os.environ['SIM_NAME']
print(next(x['udid'] for v in d['devices'].values() for x in v if x['name']==name and x['isAvailable']))
")" -derivedDataPath build test
```

57 tests in 10 suites, ~1s runtime, all pass. (The device-resolution one-liner above
duplicates `driver.sh`'s internal `udid()` helper since `xcodebuild test` needs a
`-destination` flag the driver doesn't expose as a subcommand — simplest to inline it.)

## Gotchas

- **The app is on a blank splash frame for a variable stretch right after `launch`
  returns** — `xcrun simctl launch` returns as soon as the process spawns, well before
  SwiftUI renders past `SplashViewModel`'s `Task.sleep(for: .seconds(0.6))` and the
  tab-switch transition. A `tap`/`describe` fired too early hits an empty
  `AXApplication` with no children. A fixed sleep is unreliable — a warm relaunch
  clears the splash in ~2s but a cold install (fresh `simctl install`) measured longer
  than that; a 2s fixed sleep still showed the splash frame in one run. `driver.sh all`
  now runs `wait` after `launch`, which polls `idb ui describe-all` until more than 3
  accessibility elements are present (timeout 15s, override with `WAIT_TIMEOUT`)
  instead of guessing a duration. The same applies after any navigation that presents a
  sheet (e.g. `+` → New Item form) — tap `describe`/`wait` for the new content before
  tapping fields inside it; a real run reproduced a swallowed `Save` tap when a field
  tap landed before the sheet had finished presenting, so `text` hit nothing and `Save`
  fired on a still-empty, validation-disabled form.
- **`idb install`/`idb launch` reject the build with "Targets architecture x86_64 not
  in the bundles supported architectures: (arm64)"** — this `idb` build (fb-idb 1.1.7,
  from 2022) misreports this Apple Silicon Mac's simulator target as x86_64 and refuses
  to install genuinely arm64-only iOS 17+ builds. It fails *silently as a non-zero exit*
  without installing anything — don't trust an apparent past success unless you check
  `idb list-apps` for the bundle ID with a `pid`. The driver sidesteps this entirely by
  using `xcrun simctl install`/`launch`/`terminate`/`uninstall` instead; `idb` is used
  only for `ui tap`/`ui text`/`screenshot`/`describe-all`, which don't hit this check.
- **No on-screen keyboard appears when `idb ui text` types into a field** — input
  injection goes straight to the responder, bypassing the software keyboard. The text
  still lands correctly; don't wait for a keyboard screenshot as a readiness signal.
- **Tapping by eyeballing screenshot pixel coordinates is unreliable** — screenshots are
  3x scale (iPhone 17: 1206x2622px vs 402x874pt) and SwiftUI corner radii/padding make
  visual center-guessing error-prone. Use `driver.sh describe` to get exact point-space
  `frame` rectangles for labeled elements (`Title`, `Detail`, list rows) instead.
  Unlabeled elements (the `+` toolbar button, `Cancel`/`Save` nav bar buttons) don't
  show up in `describe-all` at all — for those, screenshot, divide pixel coords by the
  scale factor, and tap.
- **A stale `idb_companion` process can persist across unrelated sessions** — if `idb`
  commands report a nonsensical target architecture or hang, `pkill -f idb_companion &&
  rm -f /tmp/idb/*.sock` and let `driver.sh boot` (via `idb connect`) spawn a fresh one.
- **The first `xcrun simctl openurl` for a given install shows an "Open in AppTemplate
  (Dev)"? system confirmation dialog** before the app actually receives the URL — tap
  Open (a screenshot's button coordinates work; this dialog isn't in `describe-all`'s
  accessibility tree, being a system alert not app content). Subsequent links in the same
  install don't re-prompt.

## Troubleshooting

- **`xcodebuild: error: missing value for key 'id' of option 'Destination'`**: the
  `udid()` shell function returned nothing — usually means `SIM_NAME` doesn't match an
  available simulator (`export SIM_NAME=` wasn't set, or was shadowed by a *local* shell
  var instead of an *exported* one, which silently hides it from the python subprocess
  that resolves the name).
- **`KeyError: 'SIM_NAME'` from the udid-resolution python snippet**: same root cause —
  the variable was assigned but not `export`ed before the subprocess read it from
  `os.environ`.
