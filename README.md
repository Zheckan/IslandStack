# IslandStack

IslandStack starts one, two, or three dummy Live Activities on a running iPhone Simulator. Use it while testing how your app's activity shares the Dynamic Island with activities from other apps. Each dummy activity belongs to a separate IslandStack helper app.

IslandStack installs separate helper apps from its bundled sources. Each app is a full-page button: tap to activate its Live Activity, and tap again to stop. The CLI can also start and stop activities through Apple’s Shortcuts app, then return to the app you name.

## Requirements

- macOS with full Xcode and an installed iOS Simulator runtime. The tested setup was Xcode 27.0, Swift 6.4, and iOS 27.0.
- A booted iPhone Simulator with Dynamic Island support.
- Your test app installed on that Simulator. Start its Live Activity in the app before running IslandStack if you want the comparison case.

IslandStack builds unsigned Simulator apps locally. The source checkout needs Swift; the npm launcher also needs Node.js and npm. It does not need an Apple Developer account, APNs, Expo, or Metro. Physical devices and other Xcode/iOS versions have not been tested.

## Run with npx

After the npm package is published, run from any directory:

```sh
npx islandstack
```

Choose a booted iPhone Simulator and how many helper apps to install: **1, 2, or 3**. The command installs A, A/B, or A/B/C. It leaves existing helper apps and activities alone. Open the installed apps and tap their full-page **Activate Live Activity** buttons. Each identity keeps one activity; tap **Stop Live Activity** to end it.

Use **↑/↓** to move between menu options and **Enter** to select. **Esc** or **Ctrl+C** cancels. Piped input and terminals with `TERM=dumb` use numbered choices instead.

To install without prompts:

```sh
npx islandstack install --competitors 3 --device <simulator-udid>
```

To activate the chosen count from the terminal and return to your own app:

```sh
npx islandstack start --competitors 3 --device <simulator-udid> --return-to <your-app-bundle-id>
npx islandstack status --device <simulator-udid> --return-to <your-app-bundle-id>
npx islandstack stop --device <simulator-udid> --return-to <your-app-bundle-id>
```

The first invocation downloads the package and builds the Swift CLI. npm may reuse the package and build on later invocations. The helper apps remain installed on the Simulator until you remove them. `install` does not activate or stop activities; `start` sets the active helper count, and `stop` ends all IslandStack activities.

## Run from a source checkout

From this repository:

```sh
swift run islandstack install --competitors 3 --device <simulator-udid>
swift run islandstack doctor
swift run islandstack start --competitors 3 --device <simulator-udid> --return-to <your-app-bundle-id>
swift run islandstack status --device <simulator-udid> --return-to <your-app-bundle-id>
swift run islandstack stop --device <simulator-udid> --return-to <your-app-bundle-id>
```

Use `--competitors 1`, `2`, or `3` to choose the number of other apps. `start` sets IslandStack’s activity count, so running it again does not add duplicates. Starting one after three ends B and C and keeps A. `stop` ends all three helpers, including when they are already stopped, and leaves your app’s activity alone. The `start`, `status`, and `stop` commands briefly open Shortcuts and launch `--return-to` afterward.

`doctor` prints booted iPhone Simulator UDIDs. You can omit `--device` when exactly one eligible iPhone is booted. `--return-to` must be the bundle ID of an app already installed on that Simulator. The first start builds the required helpers and takes longer than later runs.

## What the counts mean

`status` invokes a new App Intent in each helper and reports its ActivityKit count. It cannot count your app's activities. Multiple active activities do not guarantee the same number of simultaneous compact Island items; iOS chooses what to show. On an iPhone 18 Pro Simulator with iOS 27.0, Activity Lab 3 plus A and B were all active, while the settled Island accessibility view exposed two minimal items. B's widget appeared after A ended. See [the system findings](docs/stage-3-findings.md).

The dummy widgets show a 20-minute countdown. That display deadline does not automatically end an activity while no command runs. Call `stop` when the test is over. A later command also prunes expired IslandStack activities.

## Development

```sh
swift test
```

To check arrow selection, cancellation, terminal restoration, and piped numeric input through the CLI:

```sh
swift build
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests/CLI -v
```

These terminal tests require a booted eligible iPhone Simulator; the Simulator picker test requires two. They exit before installation and leave the Simulators unchanged.

The [execution plan](docs/execution-plan.md) records the stack, tested paths, and release work that remains. The host code is in `Sources/`, the three native helper builds are in `ios/Competitor.xcodeproj`, and the Shortcuts UI driver is in `ios/ShortcutDriver.xcodeproj`.

The npm package contains these sources and a small Node launcher. To inspect what a release would ship, run `npm pack --dry-run`. Publishing to npm is a separate release step.

## License

[MIT](LICENSE). IslandStack's code and widget designs are original to this repository; the Gymrat Activity Lab served only as a reference test app.
