# Stage 2 CLI and trigger findings

Date: 28 September 2026. Host: Xcode 27.0, Swift 6.4, iOS 27.0 Simulator runtime.

## Implemented path

The [Swift package](../Package.swift) builds the `islandstack` CLI and a host library. The host selects one booted iPhone Simulator by UDID, validates that the `--return-to` app is installed, builds and installs two native helper variants as needed, and drives their built-in App Shortcuts through a no-host XCUITest project. Start and Stop are `LiveActivityIntent`; Status is an `AppIntent`. The helper UI does not open during these actions. Shortcuts opens visibly; the host launches the return app at the end, including after a command error.

The host reads `Documents/intent-last.json` from each helper's Simulator data container. It requires a new request ID and checks command, bundle identity, source `intent`, error, count, and ActivityKit IDs. A cached receipt alone cannot pass. Built helper products are cached under ignored `.build/islandstack-xcode/`, keyed by source and Xcode version. The CLI never installs the target app or ends its activity.

From the source checkout:

```sh
swift run islandstack doctor
swift run islandstack start --competitors 2 --device <udid> --return-to <target-bundle-id>
swift run islandstack status --device <udid> --return-to <target-bundle-id>
swift run islandstack stop --device <udid> --return-to <target-bundle-id>
```

`--device` may be omitted only when exactly one eligible iPhone Simulator is booted. The target bundle ID is required so the CLI can return to it after Shortcuts. The first call builds and installs local apps, so it takes longer than later calls. Each action also runs an XCUITest method; this is a simulator test tool, not an instant background API.

## Observed command sequence

| Trial | Result |
| --- | --- |
| Existing iPhone 15 Pro trial `7D8AF314-14ED-4428-8DE7-713D7EBAF03F`, A/B already installed | Direct Shortcuts Apps-library Start, Stop, and Status actions all wrote fresh `source: intent` receipts. No saved workflow or keyboard search was needed. |
| `start --competitors 2` on that trial, return to Safari | A and B each reported one active activity; Safari returned to foreground. |
| `status`, repeat `start --competitors 2`, then `start --competitors 1` | Status reported A1/B1. Repeat start retained the same A and B ActivityKit IDs. Starting one retained A's ID and stopped B. |
| `stop` twice on that trial | Both calls reported A0/B0. |
| Fresh iPhone 15 Pro `EA3D9505-3113-49E6-8CD6-0DA311C9AED2`, no IslandStack app or saved shortcut | One `swift run islandstack start --competitors 2 --device ... --return-to com.apple.mobilesafari` built and installed both helpers, ran their built-in actions, reported A1/B1, and restored Safari. Subsequent `status` reported A1/B1; `stop` reported A0/B0. This is the clean first-run proof on one iOS 27.0 Simulator. |
| iPhone 18 Pro `70A4DAE4-7928-4A47-BD0D-B66E1B895C2E` with Activity Lab 3 | CLI start reported A1/B1 and returned to Lab 3. After stop reported A0/B0, a separate Lab UI test found `Running: 1`, then used Lab's own End all control to reach zero. |
| Two other booted iPhones, no `--device` | The CLI exited before builds or installs with `More than one eligible iPhone Simulator is booted; pass --device with a UDID.` |

## Navigation failure and fix

The first CLI cleanup on the iPhone 18 Pro failed in the Shortcuts driver. The XCUITest recording showed B's expanded Live Activity banner at the top while Shortcuts displayed a `Library` back control. Tapping that control opened IslandStack B instead of navigating Shortcuts, so the driver could not find the A category. The host still restored Lab 3. The driver now uses a left-edge back gesture halfway down the screen and bounds navigation attempts. A subsequent CLI stop passed with A0/B0. The stop command also now attempts both helpers independently and reports partial failures, so one failed action will not skip the other; that partial-failure branch has not been injected and tested yet.

## Checks and limits

Swift package tests cover device choice, including custom-named iPhones, and receipt validation. Simulator checks establish actual intent execution and ActivityKit counts. More work is needed before a public release: test the Shortcuts accessibility route on other iOS/Xcode versions, improve large `xcodebuild` failure summaries, test missing or disabled Live Activity support, and exercise partial-failure recovery. The 20-minute display deadline is not an automatic activity end; users must call `stop` unless a later supported expiry mechanism is added.

No Gymrat source was edited. The three IslandStack trial simulators were shut down after cleanup; they were not erased or deleted.
