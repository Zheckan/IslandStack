# IslandStack research and staged execution plan

Research snapshot: 27 September 2026. `IslandStack` and `islandstack` are working names. This document plans a public, free simulator tool; it does not claim that the CLI or helper apps exist yet.

The iPhone 15 Pro and iPhone 18 Pro simulator probes are recorded in [stage-0-findings.md](stage-0-findings.md). They confirmed native Swift widget rendering, `LiveActivityIntent` start and stop through saved Shortcuts workflows, and three active activities across three app identities. With all three active, the iPhone 18 Pro's stable accessibility view exposed two minimal items. XCUITest created the required Shortcuts workflows without manual taps in individual passes, but a fresh combined first-run trial stalled on Shortcuts UI idle waits. The terminal URL invocation visibly opened Shortcuts. A dependable one-command first run remains a gate.

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
| Build artifacts | Build both unsigned Simulator `.app` variants locally and cache by source/Xcode/runtime architecture | No downloaded binary trust or release hosting is needed for the first version. Rebuild when inputs change. Never overwrite another app's bundle ID. |
| Tests | Swift Testing or XCTest for host command logic, plus a small native simulator test matrix | Pure command tests catch device selection, quoting, retries, idempotence, and error reporting. Screenshots and ActivityKit counts establish actual system behavior. |
| Distribution | Source checkout first; a packaged command or signed binary is a later release decision | A copyable `swift run ...` command is feasible after checkout. The final repository and command names must be checked before publishing. |

The proposed module seam is `start(competitors:device:)`, `status(device:)`, and `stop(device:)`. It owns simulator selection, local builds, installs, trigger delivery, acknowledgments, and rollback. The helper exposes a small command/result protocol and owns only its own Live Activities. Do not expose Xcode commands, bundle variants, or ActivityKit IDs as normal user workflow steps.

### Trigger feasibility is the first gate

Apple says an ordinary [`Activity.request`](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) start occurs while the app is foregrounded. A background attempt can return [`ActivityAuthorizationError.visibility`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/visibility). A [`LiveActivityIntent`](https://developer.apple.com/documentation/appintents/liveactivityintent) can start one while the system runs app code without opening the helper UI. The simulator trials verified Start and Stop intents through saved one-action Shortcuts workflows with ActivityKit receipts. An `openurl` attempt using the advertised App Shortcut title on a fresh simulator failed before and after helper launch: a user shortcut must exist. Individual XCUITest runs created Start and Stop shortcuts without manual taps, but they visibly navigated Shortcuts. A screen recording showed terminal `simctl openurl` also opened Shortcuts and left it foregrounded; the host can restore the target app with `simctl launch`. A separate fresh combined command stalled on repeated roughly 60-second XCTest waits and was interrupted after more than five minutes. Local Xcode 27 `simctl` help lists no direct App Intent invocation. Its `push` help says it simulates only application remote notifications. Apple's [ActivityKit push workflow](https://developer.apple.com/documentation/ActivityKit/starting-and-updating-live-activities-with-activitykit-push-notifications) requires push tokens and APNs credentials, so it does not fit a free, local, one-command first run.

The remaining trigger gate is a dependable clean first run. XCUITest plus Shortcuts is an automatic experimental bridge, but it uses visible system UI and stalled in the combined trial. Test its bounded execution and recovery from partial or duplicate shortcut setup before adopting it. The fallback is `simctl launch` with a start argument, then returning to the target app. That foregrounds the helper briefly and does not meet a strict reading of “without opening helper apps.” If no reliable Shortcuts path works, decide explicitly whether that fallback is acceptable. Document every foreground transition in the README; do not implement a background start that ActivityKit rejects.

## CLI contract to validate

Names and syntax remain provisional. The desired shape after a source checkout is:

```sh
swift run islandstack doctor
swift run islandstack start --competitors 2 --device <simulator-udid>
swift run islandstack status --device <simulator-udid>
swift run islandstack stop --device <simulator-udid>
```

When exactly one eligible iPhone simulator is booted, `--device` can be omitted. With zero or multiple eligible devices, show the choices and require a UDID. `start` means **set the tool's competitor count**, not append more activities on every run. Starting one after two ends only the extra helper activity. A failed second start should report the first helper's actual state and offer `stop`, rather than claiming the whole setup succeeded. `stop` ends IslandStack's activities and leaves the target app and its activities alone. `status` must say when it cannot verify live ActivityKit state, rather than treating a cached receipt as proof.

The helper should acknowledge commands with a request ID, app identity, ActivityKit activity IDs, resulting count, and any error. If the chosen trigger launches the app, a response file in that helper's Simulator data container is a possible return channel, found with `simctl get_app_container`. Validate this before treating it as the protocol; stale files and an already running app must not produce false success.

## Execution stages

### Stage 0: prove the trigger and presentation

1. Use the verified minimal Xcode app and Widget Extension build from the iPhone 15 Pro trial as the starting point. Keep `NSSupportsLiveActivities`, an iOS 16.2 or newer deployment target for the ActivityKit calls used, an unsigned Simulator install, and a rendering check. The first hand-assembled extension crashed; a normal Xcode build rendered its compact and expanded Island content.
2. Build on the verified Start/Stop `LiveActivityIntent` workflows. XCUITest successfully created shortcuts without manual taps in individual runs, but a clean combined run stalled for more than five minutes. Make the first-run setup bounded, idempotent, and recoverable from partial shortcuts; repeat it on a clean simulator. Capture the full foreground sequence, restore the previously active app, and verify fresh receipts with request IDs. App Intents Testing failed in this iOS 27 simulator with `AppIntentsServicesSecurityErrorDomain Code=803`; do not treat that framework as a production trigger. Do not use private Simulator APIs or retry bare `simctl spawn` as though it had app identity.
3. Reuse the two verified helper bundle identities and repeat target only, target plus one helper, and target plus two helpers with final builds. The disposable iPhone 18 Pro trial found three active IDs but two exposed minimal items; B's widget rendered when A ended. Capture the Island's switching and expanded behavior in a visible Simulator window or on device, since headless screenshots omitted the pill and the tested swipes did not establish a third view. Keep ActivityKit counts separate from visible positions.

**Gate:** A bounded first run must produce acknowledged starts and stops without manual UI navigation or setup. State clearly that the tested Shortcuts path opens system UI and restores the target afterward. If it remains unreliable, decide whether brief helper foreground launches are acceptable before building the final CLI. The three-activity observation determines README wording, not whether ActivityKit can maintain three active activities.

### Stage 1: native helper and two identities

Create the final SwiftUI app, ActivityKit model, and widget layouts with distinct names, glyphs, and colors. Keep one active activity per helper identity and give it a bounded duration; the user can end it sooner. Build identities from checked-in Xcode configuration, with predictable bundle IDs and separate extensions. Check that installing or rebuilding a helper does not end the target app's activity. Implement start, enumerate, and end for each helper, plus the command acknowledgment proven in Stage 0.

**Gate:** Each identity installs independently, starts once, reports its ActivityKit state, and ends only its own activity after app relaunch.

### Stage 2: host CLI orchestration

Implement `doctor`, `start`, `status`, and `stop`. `doctor` reports Xcode path/version, installed runtimes, eligible booted iPhones, and Live Activity support checks it can actually perform. Build only missing or stale local artifacts, install on the selected simulator, invoke the proven trigger serially, wait for matching acknowledgments with a timeout, and report partial failures. No destructive simulator erase, global activity cleanup, or automatic target app installation.

**Gate:** Repeating `start --competitors 2` leaves exactly two IslandStack activities. `stop` is safe to repeat. Multiple booted devices never cause an implicit selection. Missing Xcode, unsupported devices, denied Live Activities, build errors, trigger failures, and timeouts produce actionable messages.

### Stage 3: system verification

Run the target plus zero, one, and two competitor cases on the selected simulator with the final helper builds. Verify counts by helper status and inspect the Island and Lock Screen. Confirm behavior after returning to the target app, after locking/unlocking, and after the helper process exits. Note that iOS chooses cross-app presentation and may show fewer simultaneous positions than active activities. Repeat the iPhone 18 Pro observation with capture that exposes the Island and switching gesture; the disposable headless trial showed two minimal items with three activities active.

**Gate:** Record the exact device/runtime result and narrow the supported claims to what was observed. Automated unit checks alone do not prove Island presentation.

### Stage 4: public release preparation

Write a short README with a copyable setup and command sequence, Xcode/macOS and Simulator requirements, expected first-run build time, `status`/`stop`, and measured limitations. Add a chosen open-source license after checking rights for every included asset and source file. Check repository and CLI name availability, choose the final names, verify clean-clone build and test on another Mac or account, and prepare a reviewable release checklist. Publishing, pushing, and package-registry release require separate authorization.

## Current environment and open decisions

- This repository has no commits or app project files yet. Its current files are this plan and the Stage 0 findings.
- The 15 Pro trial added [stage-0-findings.md](stage-0-findings.md) and no app source to this repository. A disposable probe remains in `/tmp` and installed on that simulator. A user-created Shortcuts workflow remains saved there. Probe and Activity Lab 3 each reported zero activities at the end of the trial.
- Local tools report Xcode 27.0 and Swift 6.4 with iOS 27.0 installed. A dedicated iPhone 18 Pro simulator was created and tested, then shut down. Three apps each held one activity; two minimal positions were exposed in the stable accessibility view. A second clean trial simulator was shut down after its XCUITest first-run setup stalled.
- Decide whether the visible Shortcuts UI and its first-run automation reliability are acceptable. The helper UI stayed closed when Start/Stop intents ran through Shortcuts, but the system UI opened. A direct supported Simulator App Intent command was not found.
- Decide final public license and names at Stage 4. The Gymrat prototype has no tracked license to carry into this repository.
- Keep the initial tool Simulator-only. Physical-device signing, APNs starts, prebuilt downloads, custom activity designs, and automated screenshot comparison need separate requirements and verification.
