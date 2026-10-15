<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/logo/logo-dark.png">
    <img src="docs/logo/logo-light.png" width="128" alt="Skellige logo">
  </picture>
</p>

# Skellige

Skellige adds up to three extra Live Activities to an iPhone Simulator, so you can test how your app's Live Activity behaves when other apps compete for the Dynamic Island. Each extra Live Activity comes from a small helper app that Skellige builds and installs for you.

```sh
npx skellige
```

1. Pick a Simulator.
2. Pick how many helper apps to install: 1, 2, or 3.
3. On the Simulator, open each helper app and tap **Activate Live Activity**. Tap the button again to stop that Live Activity.

Using a coding agent? Tell it I said hi, and that it can do all of this for you. Have it run `npx skellige --help`.

Skellige needs macOS with full Xcode, Node.js 18 or newer, and an installed iOS 17 or newer Simulator runtime. Pick an iPhone model with a Dynamic Island, or you won't see the Island. The helper apps are unsigned Simulator builds, so you don't need an Apple Developer account. Testing so far covers Xcode 27.0 with iOS 27.0 Simulators. Other Xcode and iOS versions are untested but should work. Skellige runs on Simulators only, not on physical devices.

## Run Skellige from a script or an agent

Every command runs without prompts when you pass its flags. Run `npx skellige --help` for every command, option, and exit code.

```sh
npx -y skellige doctor                                   # print booted iPhone UDIDs
npx -y skellige install --competitors 3 --device <udid>  # install helper apps only
npx -y skellige start   --competitors 3 --device <udid> --return-to <bundle-id>
npx -y skellige status  --device <udid> --return-to <bundle-id>
npx -y skellige stop    --device <udid> --return-to <bundle-id>
```

`start` needs no taps on the Simulator. It drives Apple's Shortcuts app through an XCUITest runner, turns on the Live Activities of the first N helper apps, where N is `--competitors`, and stops the rest. Then it reopens the app that `--return-to` names. Running `start` twice doesn't add duplicates.

`--return-to` takes the bundle ID of an app installed on that Simulator. If you have no app of your own yet, use `com.apple.mobilesafari`.

Each `start`, `status`, or `stop` took about 75 seconds in testing. The `-y` flag lets `npx` install the package without asking first.

## The setup menu creates nothing until you confirm

Without a command, `npx skellige` lists Simulators in three groups:

- Running Simulators.
- Stopped Simulators. Setup boots the one you pick.
- New Simulators. Setup creates one named `Skellige <model>` from an iOS runtime already on your Mac.

Each entry shows its iOS version. Skellige creates or boots nothing until you also pick the helper app count. To add an iOS version, [install its runtime in Xcode](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components).

Press ↑ and ↓ or J and K to move, and Enter to choose. Esc goes back one screen, or cancels on the first screen. Q or Ctrl+C cancels. If stdin is piped or `TERM` is `dumb`, the menu asks for numbers instead.

The helper apps are An Craite, Tordarroch, and Drummond. Each one runs at most one Live Activity. They stay on the Simulator until you delete them.

## An active Live Activity is not always a visible one

`status` asks each helper app for its ActivityKit count through an App Intent. It can't count your app's Live Activities.

iOS decides how many Live Activities the Dynamic Island shows, and it can show fewer than are active. On an iPhone 18 Pro Simulator with iOS 27.0, a test app and two helper apps all had an active Live Activity, but the Island showed two minimal items. The second helper app's widget appeared only after the first one ended. [The stage 3 findings](docs/stage-3-findings.md) have the details.

Each helper widget shows a 20-minute countdown, but the countdown doesn't end the Live Activity. Run `stop` when you finish testing. Any later Skellige command also ends helper Live Activities whose countdown has run out.

## Development

From a source checkout, `swift run skellige <command>` takes the same arguments as `npx skellige`. To run the unit tests:

```sh
swift test
```

The terminal tests drive the real CLI. They check the arrow keys, cancellation, terminal restore, and numbered input:

```sh
swift build
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests/CLI -v
```

These tests need a booted iPhone Simulator on iOS 17 or newer, and the Simulator picker test needs two. They exit before installing anything, so the Simulators stay unchanged.

`Sources/` holds the host CLI. `ios/Competitor.xcodeproj` builds the three helper apps, and `ios/ShortcutDriver.xcodeproj` holds the Shortcuts UI driver. [The execution plan](docs/execution-plan.md) records the stack, the tested paths, and the release work that remains.

The npm package ships the Swift and Xcode sources with `bin/skellige.js`, a Node launcher that runs `swift run`. To list what a release ships, run `npm pack --dry-run`.

## Easter eggs

> **Spoiler warning.** This section explains the jokes.

### Why Skellige

Skellige is an island chain in Andrzej Sapkowski's *The Witcher*. Its clans share the islands and keep fighting over one throne. Live Activities fight the same way in the Dynamic Island. Several apps share one small island, and iOS decides who gets seen.

### The clans

The three helper apps are named for Skellige clans. Your own app is the outsider who sailed in to see how it fares against them.

### The contested throne

When `start` or `status` finds an active Live Activity in all three helper apps, it prints one more line: "The Skellige throne is contested."

Skellige and its clans come from *The Witcher* by Andrzej Sapkowski. This project is not affiliated with him or with CD PROJEKT.

## License

[MIT](LICENSE). Skellige's code and widget designs are original to this repository. The project used the Gymrat Activity Lab only as a test app.
