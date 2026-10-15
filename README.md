# IslandStack

IslandStack starts one or two dummy Live Activities on a running iPhone Simulator. Use it while testing how your app's activity shares the Dynamic Island with activities from other apps. Each dummy activity belongs to a separate IslandStack helper app.

The CLI builds and installs the helpers from this checkout. It opens Apple's Shortcuts app to run their built-in App Shortcuts, then returns to the app you name. You do not need to open either helper app or create a saved shortcut.

## Requirements

- macOS with full Xcode and an installed iOS Simulator runtime. The tested setup was Xcode 27.0, Swift 6.4, and iOS 27.0.
- A booted iPhone Simulator with Dynamic Island support.
- Your test app installed on that Simulator. Start its Live Activity in the app before running IslandStack if you want the comparison case.

This source-checkout tool builds unsigned Simulator apps locally. It does not need an Apple Developer account, APNs, Expo, or Metro. Physical devices and other Xcode/iOS versions have not been tested.

## Run a comparison

From this repository:

```sh
swift run islandstack doctor
swift run islandstack start --competitors 2 --device <simulator-udid> --return-to <your-app-bundle-id>
swift run islandstack status --device <simulator-udid> --return-to <your-app-bundle-id>
swift run islandstack stop --device <simulator-udid> --return-to <your-app-bundle-id>
```

Use `--competitors 1` for one other app. `start` sets IslandStack's activity count, so running it again does not add duplicates. Starting one after two ends B and keeps A. `stop` ends IslandStack A and B, including when they are already stopped. It leaves your app's activity alone. Every action briefly opens Shortcuts and launches `--return-to` afterward.

`doctor` prints booted iPhone Simulator UDIDs. You can omit `--device` when exactly one eligible iPhone is booted. `--return-to` must be the bundle ID of an app already installed on that Simulator. The first start builds the required helpers and takes longer than later runs.

## What the counts mean

`status` invokes a new App Intent in each helper and reports its ActivityKit count. It cannot count your app's activities. Three active activities do not guarantee three simultaneous compact Island items; iOS chooses what to show. On an iPhone 18 Pro Simulator with iOS 27.0, Activity Lab 3 plus A and B were all active, while the settled Island accessibility view exposed two minimal items. B's widget appeared after A ended. See [the system findings](docs/stage-3-findings.md).

The dummy widgets show a 20-minute countdown. That display deadline does not automatically end an activity while no command runs. Call `stop` when the test is over. A later command also prunes expired IslandStack activities.

## Development

```sh
swift test
```

The [execution plan](docs/execution-plan.md) records the stack, tested paths, and release work that remains. The host code is in `Sources/`, the two native helper builds are in `ios/Competitor.xcodeproj`, and the Shortcuts UI driver is in `ios/ShortcutDriver.xcodeproj`.

## License

[MIT](LICENSE). IslandStack's code and widget designs are original to this repository; the Gymrat Activity Lab served only as a reference test app.
