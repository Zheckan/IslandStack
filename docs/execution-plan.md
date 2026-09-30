# IslandStack research and staged execution plan

Research snapshot: 28 September 2026. `IslandStack` and `islandstack` are working names. The native helpers and source-checkout CLI now exist in this repository.

The initial probes in [stage-0-findings.md](stage-0-findings.md) established native widget rendering and intent execution through saved Shortcuts, but keyboard-driven setup stalled on fresh simulators. A later route invokes each app's built-in App Shortcut directly through the Shortcuts Apps library. A fresh iPhone 15 Pro accepted one `islandstack start` command with no saved workflows or manual setup. The helper app UIs stayed closed; Shortcuts opened and the CLI restored the target app. See [stage-2-findings.md](stage-2-findings.md) for the CLI run. The iPhone 18 Pro trial had three active activities across three identities, but its stable accessibility view exposed two minimal items.

## Job to be done

With another app's Live Activity already running, one CLI command should create a repeatable test with one or two competing Live Activities on a selected, already running iOS Simulator. The user should not have to open helper apps or navigate their screens. A separate command should report the tool's activities and end only those activities. Gymrat is the first test app, not a dependency.

| Case | Target app | Helper identities | Total intended activities |
| --- | --- | ---: | ---: |
| Baseline | One target activity | 0 | 1 |
| One competitor | One target activity | 1 | 2 |
| Two competitors | One target activity | 2 | 3 |

The CLI can report how many activities ActivityKit says are active in *its own* helper apps. It cannot infer the target app's activity count or guarantee which activities iOS puts in the Island. Apple's [ActivityKit presentation guidance](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) describes two minimal presentations for activities from different apps and says relevance scores order activities **within one app**. The [iOS 27 iPhone guide](https://support.apple.com/guide/iphone/view-live-activities-in-the-dynamic-island-iph28f50d10d/27/ios/27) says iPhone 18 Pro models can show up to three Live Activities and lets people swipe between them. In our iPhone 18 Pro simulator trial, three were active but only two were exposed in the stable minimal accessibility view; the third rendered after one visible helper ended. The exact three-item switching and expanded behavior still needs observation.

## What the existing prototype establishes

The Gymrat `redesign/phase-b` checkout has `apps/live-activity-lab`, a private Expo 57 app using `expo-widgets` and `@expo/ui`. Its `LAB_VARIANT` setting changes the app name, bundle ID, widget extension ID, and App Group for three builds. Each variant can start one to three colored countdown activities, but starts and ends them from React Native buttons. Its notes prescribe a Release build to avoid Metro. This is useful evidence for the required widget layouts and distinct identities, not a CLI implementation or proof that two activities from one app occupy two Island positions.

The earlier iPhone 15 Pro run described in the handoff showed Lab and Fitness as the two Island items. It did not prove a same-app pair. The prototype also lives in a repository with no tracked license file. Implement original IslandStack source rather than copying Gymrat source into a public repository until ownership and reuse terms are settled.

The user's later screenshots show `Lab 3.1` and `Lab 3.2` together in the expanded view but only `Lab 3.1` in the compact Island. A count of two active activities from one helper therefore does not satisfy the two-competitor case if the goal is two simultaneous compact/minimal Island items. Keep two distinct helper app identities and report active counts separately from visible Island positions.

## Stack decision

| Part | Choice for the first implementation | Reason |
| --- | --- | --- |
| Host command | Swift executable in a Swift Package, built with `swift run` at first | Xcode is already required for Simulator builds. This avoids a Node, Expo, Metro, or package-registry requirement for users. Use `Process` with argument arrays to call Apple tools; keep command planning and parsing testable without a simulator. |
| Simulator control | `xcrun simctl` for device discovery, install, launch, app containers, and diagnostics; `xcodebuild` for local builds | These ship with Xcode. Explicit UDIDs prevent `booted` from silently selecting one of several running simulators. |
| iOS helpers | One small native SwiftUI app and WidgetKit Live Activity extension, built under two distinct app identities from shared Swift source | Two competing apps are enough for the Gymrat plus two competitors case. `ActivityKit` owns start, enumerate, update, and end; SwiftUI owns compact, minimal, expanded, and Lock Screen layouts. No network or push capability is needed for an ordinary foreground start. |
| Build artifacts | Build both unsigned Simulator `.app` variants locally and cache by source and Xcode version | No downloaded binary trust or release hosting is needed for the first version. Rebuild when inputs change. Never overwrite another app's bundle ID. |
| Tests | Swift Testing or XCTest for host command logic, plus a small native simulator test matrix | Pure command tests catch device selection, quoting, retries, idempotence, and error reporting. Screenshots and ActivityKit counts establish actual system behavior. |
| Distribution | Source checkout first; a packaged command or signed binary is a later release decision | A copyable `swift run ...` command is feasible after checkout. The final repository and command names must be checked before publishing. |

The host seam is `start(competitors:returnTo:)`, `status(returnTo:)`, and `stop(returnTo:)` after selecting a Simulator. It owns local builds, installs, trigger delivery, receipts, and target-app restoration. Each helper owns only its own Live Activities. The CLI reports counts without exposing ActivityKit IDs in normal output.

### Trigger feasibility

Apple says an ordinary [`Activity.request`](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) start occurs while the app is foregrounded. A [`LiveActivityIntent`](https://developer.apple.com/documentation/appintents/liveactivityintent) can start one without opening the helper UI. The final helper exposes Start and Stop as Live Activity intents and Status as an App Intent. Apple's [App Shortcuts guide](https://support.apple.com/en-mo/guide/shortcuts/apd43295406d/ios) describes the built-in actions in Shortcuts' Apps library. The CLI uses a no-host XCUITest driver to select those actions directly; it neither creates nor searches for saved workflows. The fresh iPhone 15 Pro CLI start passed with no manual setup. A saved shortcut URL is a separate path and, per Apple's [URL guide](https://support.apple.com/en-az/guide/shortcuts/apd624386f42/ios), requires a saved user shortcut. The earlier attempts at provisioning that path remain documented in Stage 0.

The clean first-run gate passed on one fresh Simulator. The route still depends on public Shortcuts UI and XCTest accessibility labels, so it needs validation across supported iOS/Xcode versions. The driver now uses a left-edge back gesture because an expanded Live Activity banner intercepted a top-left Library tap in one trial. The host runs each action serially, checks a fresh intent receipt, and launches `--return-to` afterward. A normal `simctl launch` trigger remains a tested fallback, but it foregrounds the helper and is not used by the CLI.

## CLI contract

Current source-checkout syntax:

```sh
swift run islandstack doctor
swift run islandstack start --competitors 2 --device <simulator-udid> --return-to <target-bundle-id>
swift run islandstack status --device <simulator-udid> --return-to <target-bundle-id>
swift run islandstack stop --device <simulator-udid> --return-to <target-bundle-id>
```

When exactly one eligible iPhone simulator is booted, `--device` can be omitted. With zero or multiple eligible devices, the command requires a UDID. `--return-to` names an already installed target app; every action returns to it. `start` sets the tool's competitor count: repeating it keeps the same IDs, and starting one after two ends B. A failed second start reports partial state. `stop` attempts A and B independently and ends only IslandStack activities. `status` runs a new App Intent and checks a fresh receipt rather than treating cached data as proof.

Each helper acknowledges commands with a request ID, app identity, ActivityKit IDs, resulting count, source, and any error in its Simulator data container. The host rejects stale or mismatched receipts. ActivityKit IDs are kept for verification and diagnostics, not presented as Island positions.

## Execution stages

### Stage 0: prove the trigger and presentation

1. Use the verified minimal Xcode app and Widget Extension build from the iPhone 15 Pro trial as the starting point. Keep `NSSupportsLiveActivities`, an iOS 16.2 or newer deployment target for the ActivityKit calls used, an unsigned Simulator install, and a rendering check. The first hand-assembled extension crashed; a normal Xcode build rendered its compact and expanded Island content.
2. Use built-in App Shortcuts through the Shortcuts Apps library. This avoided the keyboard-driven setup that stalled in the saved-workflow trials. The CLI now restores the target app and validates fresh receipts. App Intents Testing failed in this iOS 27 simulator with `AppIntentsServicesSecurityErrorDomain Code=803`; that route is not the production trigger.
3. Reuse the two verified helper bundle identities and repeat target only, target plus one helper, and target plus two helpers with final builds. The disposable iPhone 18 Pro trial found three active IDs but two exposed minimal items; B's widget rendered when A ended. Capture the Island's switching and expanded behavior in a visible Simulator window or on device, since headless screenshots omitted the pill and the tested swipes did not establish a third view. Keep ActivityKit counts separate from visible positions.

**Gate:** Passed on a fresh iPhone 15 Pro simulator: one CLI start and subsequent status/stop produced acknowledged intents without manual UI setup. The Shortcuts UI opened and the target app was restored. The three-activity observation determines presentation wording, not whether ActivityKit can maintain three active activities.

### Stage 1: native helper and two identities

The native SwiftUI app, ActivityKit model, and widget layouts use distinct names, glyphs, colors, bundle IDs, and extensions. Each helper keeps one active activity. The current helpers display a 20-minute countdown, set `staleDate` to match, and end expired activities on the next command. That does not end an activity at 20 minutes if no command runs. Document explicit `stop` as the lifecycle contract before release, or implement and verify a supported automatic end mechanism.

**Gate:** Each identity installs independently, starts once, reports its ActivityKit state, and ends only its own activity after app relaunch. These checks passed on the iPhone 18 Pro; see [stage-1-findings.md](stage-1-findings.md). Automatic end after the countdown remains open.

### Stage 2: host CLI orchestration

The Swift Package implements `doctor`, `start`, `status`, and `stop`. `doctor` reports Xcode path/version and eligible booted iPhones; it does not yet enumerate runtimes or check Live Activity support directly. The host caches local builds, installs on the selected Simulator, invokes built-in App Shortcuts serially, validates fresh receipts, and reports partial failures. It does not erase simulators, clean up other apps, or install the target app.

**Gate:** Repeated two-competitor start retained the same two ActivityKit IDs; one-competitor start ended B; repeated stop reported zero. A fresh Simulator completed start, status, and stop without saved shortcuts. Device selection and receipt validation have package tests. Remaining hardening: clearer build/trigger error summaries, direct checks for unavailable Live Activities, additional OS versions, and a test of partial stop failure recovery. See [stage-2-findings.md](stage-2-findings.md).

### Stage 3: system verification

The iPhone 18 Pro target plus zero, one, and two competitor cases ran with final helper builds and CLI receipts. After returning to Activity Lab 3, its UI still showed `Running: 1`. Three activities were active, but the settled Island accessibility view exposed two minimal items. B appeared after A ended. After terminating both helper processes, fresh status intents still reported A1/B1. Remaining checks: Lock Screen, lock/unlock, presentation after process exit, and a visible Simulator or device capture of switching among three activities. The app's own ActivityKit count and iOS presentation must remain separate claims.

**Gate:** Partial. The iPhone 18 Pro/iOS 27.0 observations establish three active app identities and two observed minimal positions. They do not establish three simultaneous visible positions or a successful switch to the third activity. See [stage-3-findings.md](stage-3-findings.md).

### Stage 4: public release preparation

A short [README](../README.md) now gives a copyable command sequence and measured limits. A proposed [MIT license](../LICENSE) is in the local tree. The current Git remote already names a public `Zheckan/IslandStack` repository; the [release checklist](release-readiness.md) records name checks and work still needed before publication. A clean-checkout test on another Mac or account remains open. Publishing, pushing, and package-registry release require separate authorization.

## Current environment and open decisions

- The latest commit at this snapshot is `cdd2f1f`. The native project, Swift Package CLI, tests, and updated docs are uncommitted.
- Local tools report Xcode 27.0, Swift 6.4, and iOS 27.0. A fresh iPhone 15 Pro trial succeeded with no saved shortcut. Shortcuts visibly opened; the CLI restored Safari. A direct supported `simctl` App Intent command was not found.
- The iPhone 18 Pro trial established three active activities across Activity Lab 3, A, and B, but only two settled minimal positions were exposed. B's widget rendered after A stopped.
- On iOS 27.0 with an active expanded Live Activity, a top-left Shortcuts Library tap opened that activity's app. The driver now navigates back with a lower-screen edge swipe; it completed subsequent cleanup. More runtime/device coverage is needed before public release.
- Review the local MIT license and `Zheckan` copyright line before publishing. The Gymrat prototype has no tracked license to carry into this repository. The current public remote already uses `Zheckan/IslandStack`; `islandstack` remains the local CLI name.
- Keep the initial tool Simulator-only. Physical-device signing, APNs starts, prebuilt downloads, custom activity designs, and automated screenshot comparison need separate requirements and verification.
