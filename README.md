<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/logo/logo-dark.png">
    <img src="docs/logo/logo-light.png" width="128" alt="Skellige logo">
  </picture>
</p>

# Skellige

Skellige starts one, two, or three dummy Live Activities on a running iPhone Simulator. Use it while testing how your app's activity shares the Dynamic Island with activities from other apps. Each dummy activity belongs to a separate Skellige helper app.

Skellige installs separate helper apps from its bundled sources. Each app is a full-page button: tap to activate its Live Activity, and tap again to stop. The CLI can also start and stop activities through Apple’s Shortcuts app, then return to the app you name.

## Requirements

- macOS with full Xcode and an installed iOS Simulator runtime. The tested setup was Xcode 27.0, Swift 6.4, and iOS 27.0.
- An iPhone model with Dynamic Island support in an installed iOS 17-or-newer runtime. The installer can boot an existing Simulator or create one.
- Your test app installed on that Simulator. Start its Live Activity in the app before running Skellige if you want the comparison case.

Skellige builds unsigned Simulator apps locally. The source checkout needs Swift; the npm launcher also needs Node.js and npm. It does not need an Apple Developer account, APNs, Expo, or Metro. Physical devices and other Xcode/iOS versions have not been tested.

## Run with npx

After the npm package is published, run from any directory:

```sh
npx skellige
```

Choose an iPhone Simulator and how many helper apps to install: **1, 2, or 3**. The helper apps are named after Skellige clans: **An Craite**, **Tordarroch**, and **Drummond**. The command installs the first one, two, or all three. It leaves existing helper apps and activities alone. Open the installed apps and tap their full-page **Activate Live Activity** buttons. Each identity keeps one activity; tap **Stop Live Activity** to end it.

The Simulator list uses this order:

1. **Running**: an existing device that is already booted.
2. **Existing, stopped**: a device already created in Simulator; installation boots it.
3. **New**: a model and iOS version supported by an installed runtime; installation creates and boots a separate device named `Skellige <model>`.

Every choice shows its iOS version. Picking a device does not create or boot it until you also confirm the helper count. New choices use runtimes already installed on your Mac. To add an iOS version, [install its runtime in Xcode](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components).

The full-screen setup shows a highlighted choice and a **What this does** explanation. Use **↑/↓** or **J/K** to move and **Enter** to confirm. **Esc** goes back from helper count to Simulator selection, or cancels on the first screen. **Q** or **Ctrl+C** cancels from either screen. Piped input and terminals with `TERM=dumb` use numbered choices instead.

To install without prompts on a created Simulator, running or stopped:

```sh
npx skellige install --competitors 3 --device <simulator-udid>
```

To activate the chosen count from the terminal and return to your own app:

```sh
npx skellige start --competitors 3 --device <simulator-udid> --return-to <your-app-bundle-id>
npx skellige status --device <simulator-udid> --return-to <your-app-bundle-id>
npx skellige stop --device <simulator-udid> --return-to <your-app-bundle-id>
```

The first invocation downloads the package and builds the Swift CLI. npm may reuse the package and build on later invocations. The helper apps remain installed on the Simulator until you remove them. `install` does not activate or stop activities; `start` sets the active helper count, and `stop` ends all Skellige activities.

## Run from a source checkout

From this repository:

```sh
swift run skellige install --competitors 3 --device <simulator-udid>
swift run skellige doctor
swift run skellige start --competitors 3 --device <simulator-udid> --return-to <your-app-bundle-id>
swift run skellige status --device <simulator-udid> --return-to <your-app-bundle-id>
swift run skellige stop --device <simulator-udid> --return-to <your-app-bundle-id>
```

Use `--competitors 1`, `2`, or `3` to choose the number of other apps. `start` sets Skellige’s activity count, so running it again does not add duplicates. Starting one after three ends Tordarroch and Drummond and keeps An Craite. `stop` ends all three helpers, including when they are already stopped, and leaves your app’s activity alone. The `start`, `status`, and `stop` commands briefly open Shortcuts and launch `--return-to` afterward.

`doctor` prints booted iPhone Simulator UDIDs. For `start`, `status`, and `stop`, you can omit `--device` when exactly one eligible iPhone is booted. These commands require a running Simulator. `install` offers running, stopped, and new choices when `--device` is omitted. `--return-to` must be the bundle ID of an app already installed on that Simulator. The first start builds the required helpers and takes longer than later runs.

## What the counts mean

`status` invokes a new App Intent in each helper and reports its ActivityKit count. It cannot count your app's activities. Multiple active activities do not guarantee the same number of simultaneous compact Island items; iOS chooses what to show. On an iPhone 18 Pro Simulator with iOS 27.0, Activity Lab 3 plus two helpers were all active, while the settled Island accessibility view exposed two minimal items. The second helper's widget appeared after the first ended. See [the system findings](docs/stage-3-findings.md).

The dummy widgets show a 20-minute countdown. That display deadline does not automatically end an activity while no command runs. Call `stop` when the test is over. A later command also prunes expired Skellige activities.

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

## Easter eggs

> **Spoiler warning.** This section explains the jokes.

### Why Skellige

Skellige is an island chain in Andrzej Sapkowski's *The Witcher*. Its clans share the islands and keep fighting over one throne. Live Activities do the same in the Dynamic Island: several apps, one small island, and iOS decides who gets seen.

### The clans

The three helper apps are An Craite, Tordarroch, and Drummond, all Skellige clans. Your own app is the outsider who sailed in to see how it fares against them.

### The contested throne

When `start` or `status` finds all three clans with an active Live Activity, it adds one line: "The Skellige throne is contested."

Skellige and its clans come from *The Witcher* by Andrzej Sapkowski. This project is not affiliated with him or with CD PROJEKT.

## License

[MIT](LICENSE). Skellige's code and widget designs are original to this repository; the Gymrat Activity Lab served only as a reference test app.
