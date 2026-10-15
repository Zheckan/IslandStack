# Stage 0 feasibility findings

Date: 27 September 2026. Device: iPhone 15 Pro simulator `FD6F770D-557E-4C1A-BFA8-474C811D752A`, iOS 27.0. Host: Xcode 27.0, Swift 6.4. This was a command-path probe, not the final IslandStack app.

## Setup and observations

The iPhone 15 Pro was shut down at the start of this run. I booted it. Gymrat and Activity Lab 3 were already installed. I created original Swift source and a temporary Xcode project under `/tmp/islandstack-spike-20260927`, then installed only `dev.islandstack.probe` on the iPhone 15 Pro. Neither Gymrat's repository nor its installed app was rebuilt or reinstalled.

| Check | Observation | What it proves |
| --- | --- | --- |
| `simctl launch --terminate-running-process <udid> dev.islandstack.probe start start1` | The app wrote a matching JSON receipt with one ActivityKit ID, `count: 1`, and no error. A screenshot showed the probe app in the foreground. | A CLI can deliver a start argument, obtain a response from the app's data container, and start an activity when the app is foregrounded. It does **not** meet the no-helper-UI requirement. |
| Relaunch with `status status1` | The app reported the same activity ID and `count: 1`. | The activity survived app relaunch. A cached receipt alone was not used as proof. |
| Relaunch with `stop stop1` | The app reported `count: 0` and no error. A later second start and stop produced the same pattern. | A command-driven cleanup path works for the probe's own activity. |
| `simctl spawn <udid> build/SpikeDirect` with an ActivityKit request | `areActivitiesEnabled` was false and the request returned `unsupportedTarget`. | A bare simulator process did not acquire the installed app identity needed for this start. It is not a working invisible trigger. |
| First hand-assembled widget bundle | `chronod` repeatedly lost the extension; macOS crash reports show `IslandStackProbeWidget` trapping in ExtensionFoundation before widget code ran. | This shortcut was unsuitable for testing presentation. It says nothing about a normal Xcode Widget Extension target. |
| Xcode app and Widget Extension targets | `xcodebuild` succeeded for the iPhone 15 Pro destination after setting the ActivityKit deployment target to iOS 16.2. The installed extension returned one Live Activity descriptor and stopped crashing. | Native SwiftUI and WidgetKit can build and run without Expo or Metro in this simulator. |
| Xcode-built probe on SpringBoard | The headless simulator's accessibility snapshot exposed the probe's compact Island glyph. A long press exposed the expanded label `IslandStack probe` and its countdown. A normal screenshot did not capture the pill. | The probe rendered Island content. Accessibility output, not a screenshot, is the evidence for this run. |
| Probe plus one Activity Lab 3 activity | The SpringBoard snapshot exposed two distinct minimal glyphs. Long pressing them showed `IslandStack probe` and `Lab 3.1` respectively. | Two app identities occupied the two minimal Island positions on iPhone 15 Pro with iOS 27.0. |
| Probe plus two Activity Lab 3 activities | Lab reported `Running: 2`; the probe reported one activity. The Island snapshot still exposed two minimal glyphs, one for each app. The Lab item expanded to `Lab 3.1`. | Three activities were active across two apps, but this run exposed only two minimal positions. It did not show two activities from the same app side by side. |

The user's subsequent screenshots show two Activity Lab 3 activities, `Lab 3.1` and `Lab 3.2`, as separate cards in the expanded view, while the compact Island shows only `Lab 3.1`. This is direct evidence that two active activities from one app do not become two simultaneous compact/minimal competitors in that example. The screenshots do not show the IslandStack probe. Apple's [ActivityKit presentation guidance](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) likewise says the system selects one activity from an app for the compact Island and uses the two minimal positions for activities from different apps.

## LiveActivityIntent follow-up

I added `StartSpikeIntent: LiveActivityIntent` and an App Shortcut to the disposable Xcode project, rebuilt, and reinstalled the probe. Its `perform()` requests an ActivityKit activity and writes `intent-result.json` in the probe's app container. The helper's `openAppWhenRun` is false. These are the observed results:

| Check | Observation | Limit |
| --- | --- | --- |
| Xcode build with `LiveActivityIntent` | Succeeded; Shortcuts listed the action `Start IslandStack Probe`. | Discovery alone does not prove execution. |
| App Intents Testing UI test | `intent.run()` failed with `AppIntentsServicesSecurityErrorDomain Code=803`, “Unable to run internal tests on a Customer build.” | This simulator/runtime cannot be used as evidence for the testing framework route. |
| `simctl openurl ... 'shortcuts://run-shortcut?name=Start%20probe'` before a user shortcut existed | Shortcuts showed “Could not find the shortcut ‘Start probe.’” No intent receipt appeared. | An App Shortcut's advertised title was not directly runnable through this URL. |
| One-action shortcut created in Shortcuts and run there | `StartSpikeIntent.perform` wrote one ActivityKit ID, `count: 1`, `error: null`. Shortcuts stayed in the foreground; the helper UI was not shown. | Creation required simulator UI navigation. |
| `simctl openurl ... 'shortcuts://run-shortcut?name=Start%20IslandStack%20Probe'` with that user shortcut saved | A new receipt reported `count: 2` and a second ID. | A later screen recording established that this URL visibly opens Shortcuts and leaves it foregrounded. The earlier Activity Lab 3 inspection did not establish continuous foreground state. |
| Terminate probe process, repeat the same terminal command | A new receipt reported `count: 3`, a third ID, and no error. | Confirms a stopped helper process can be invoked by the system path after shortcut setup. |
| Foreground `stop intent-stop` cleanup | Receipt reported `count: 0`, no error, and no IDs. Activity Lab 3 was relaunched afterward. | At this point in the trial, stop still used the foreground fallback. The later iPhone 18 Pro follow-up tested a Stop intent. |

**Answer:** Yes, `LiveActivityIntent` started Live Activities without showing the helper UI in this iPhone 15 Pro simulator. A terminal command can invoke it through a saved Shortcuts workflow, even after terminating the helper process. The URL visibly opens Shortcuts, and a custom shortcut must first exist. The local `simctl` help still has no direct App Intent command. Apple documents the background start in [`LiveActivityIntent`](https://developer.apple.com/documentation/appintents/liveactivityintent) and the Shortcuts action integration in [App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts).

## Clean shortcut and iPhone 18 Pro follow-up

I created a separate iPhone 18 Pro simulator `70A4DAE4-7928-4A47-BD0D-B66E1B895C2E` with iOS 27.0. I installed the disposable probe as app A, built a second original-source bundle `dev.islandstack.probe.b` with a flame glyph, and installed the existing compiled Activity Lab 3 app as the reference target. No Gymrat repository files were changed.

| Check | Observed result |
| --- | --- |
| Exact `shortcuts://run-shortcut?name=Start%20IslandStack%20Probe` on the new simulator, before and after launching probe A | Shortcuts showed “Could not find the shortcut ‘Start IslandStack Probe.’” No intent receipt appeared. Advertising the App Shortcut did not create a user shortcut that this URL could run. |
| XCUITest UI automation of Shortcuts | A UI test created a one-action **Start** shortcut in 26.855 seconds and a separate **Stop** shortcut in 18.775 seconds. Both tests passed on the iPhone 18 Pro after the probe was installed. This used public XCTest UI automation but opened and navigated Shortcuts on screen. |
| Terminal `simctl openurl` with those saved shortcuts | Start wrote a new ActivityKit ID and `count: 1`, `error: null`; Stop wrote `count: 0`, empty IDs. The helper app UI was not used. The host can launch the target app afterward. |
| Recording the terminal Start invocation | `/tmp/islandstack-spike-20260927/invocation-18pro.mov` shows Activity Lab 3 foreground before the command, then Shortcuts foreground and still foreground at recording end. It also shows the probe's activity banner. The prior claim that the target stayed foreground throughout was incorrect. |
| Target only; target plus A; target plus A and B | Activity Lab 3 reported `Running: 1`; A and B each wrote `count: 1` with distinct ActivityKit IDs. SpringBoard accessibility exposed the target's single compact `Song` item, then target `Song` and A's hexagon as two minimal items. With all three activities active, the stable snapshot still exposed `Song` and A's hexagon, not B's flame. After ending A, B's flame appeared, showing that B's widget rendered. |
| Swipes across the Island with all three active | The tested swipes collapsed or hid visible items and did not establish a three-item view or a successful switch to B while A remained active. Normal headless screenshots omitted the Island; the SpringBoard accessibility tree is the presentation evidence. |
| Fresh end-to-end command trial on new iPhone 15 Pro simulator `D6A3FC9D-45E8-4F26-80EA-F122A3A65F80` | A temporary script installed the probe and began provisioning both shortcuts through XCUITest. On this fresh simulator, XCTest waited about 60 seconds for Shortcuts to become idle after successive UI actions. I interrupted the trial after over five minutes, before the start/stop commands. A dependable one-command first run is **not** established by the separate passing tests. |

Apple's [iOS 27 iPhone guide](https://support.apple.com/guide/iphone/view-live-activities-in-the-dynamic-island-iph28f50d10d/27/ios/27) says iPhone 18 Pro can show up to three Live Activities and describes swiping between them. This trial proves three *active* activities from three app identities, but observed only two minimal positions at once. It does not establish that a third simultaneous presentation is impossible on the device or runtime.

## Decision at the end of the initial probe

At this point, the Stage 0 trigger gate had **not passed** for a dependable first run. The saved-workflow bridge could provision and run start/stop without manual taps in successful individual tests, but it visibly opened Shortcuts and the fresh combined run stalled on XCTest idle waits. A direct supported Simulator App Intent command was not found. The later built-in App Shortcut route and passing clean run are recorded below.

On 28 September, I ran another clean iPhone 15 Pro trial on `234688CD-10AC-4F5B-A943-DD7FEFA46B2D`. A single XCUITest method opened Shortcuts once and attempted to create both saved actions, removing the app relaunch between tests as a variable. The test stalled on the **first** action search field after the keyboard opened. XCTest logged `App animations complete notification not received` at 79.40 seconds, and the host terminated the test at 150 seconds. This shows the earlier second-test relaunch was not required for the idle wait. It is a bounded repeat of the first-run failure, not a successful provisioning path. The trial Simulator was shut down afterward and may retain an incomplete shortcut editor state.

## Trial state

The final stop receipt for the probe reported zero active probe activities. Activity Lab 3 reported `Running: 0` after its End all action. The temporary source, Xcode build, test log, receipts, and screenshots remain under `/tmp/islandstack-spike-20260927` or the probe's simulator data container. The probe app and the one-action user shortcut `Start IslandStack Probe` remain installed/saved on the iPhone 15 Pro. The simulator remains booted with Activity Lab 3 foregrounded; no other app was uninstalled. The first hand-assembled widget extension generated crash reports in `~/Library/Logs/DiagnosticReports`; the Xcode-built extension rendered successfully. No files were changed in the Gymrat checkout.

On the iPhone 18 Pro, Activity Lab 3 reported `Running: 0`, A and B each reported `count: 0`, and the device was shut down after testing. It retains the three installed apps and the automated Start/Stop user shortcuts. The additional clean iPhone 15 Pro trial was also shut down after the interrupted first-run test; its Shortcuts editor state may be partial. Both created simulators and their temporary source/build artifacts remain for review. No app or repository files were changed in Gymrat.

## 28 September: direct built-in App Shortcut route

The earlier first-run failures were specific to **creating saved workflows through a keyboard search**. Apple's [App Shortcuts guide](https://support.apple.com/en-mo/guide/shortcuts/apd43295406d/ios) also describes running built-in actions directly from the Shortcuts Apps library. On a fresh iPhone 15 Pro trial, a no-host XCUITest opened Shortcuts, selected IslandStack A or B, and tapped the advertised Start/Stop action. Each action wrote a fresh `source: intent` receipt, including after terminating the helper process. The helper UI did not open. A later Status App Intent worked through the same route. No saved workflow, keyboard search, or manual taps were used.

The checked-in CLI then ran a clean first start on a second new iPhone 15 Pro (`EA3D9505-3113-49E6-8CD6-0DA311C9AED2`): it built and installed A/B, invoked both built-in actions, reported A1/B1, and restored Safari. Status reported A1/B1 and Stop reported A0/B0. This passes the one-command first-run gate for that iOS 27.0 Simulator. Shortcuts remains visible during invocation; the CLI restores the target afterward. See [stage-2-findings.md](stage-2-findings.md) for the failure found under an expanded Live Activity and its navigation fix.
