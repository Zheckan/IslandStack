# Stage 3 system presentation findings

Date: 28 September 2026. Reference device: dedicated iPhone 18 Pro Simulator `70A4DAE4-7928-4A47-BD0D-B66E1B895C2E`, iOS 27.0. Target: installed Activity Lab 3, `com.zheckan.gymrat.lab3`. Helpers: final IslandStack A and B builds.

| State | ActivityKit or app result | Observed Island result |
| --- | --- | --- |
| Target only | Lab UI showed `Running: 1`. | Lab's `Song` item appeared. |
| Target plus A and B after one CLI start | CLI fresh intent receipts reported A1 and B1 with distinct IDs; Lab UI still showed `Running: 1` after returning to it. | A settled SpringBoard accessibility snapshot exposed Lab `Song` and A `Flash` as two minimal items. B was active but not exposed in that snapshot. |
| After terminating both final helper app processes | `simctl terminate` succeeded for A and B. Fresh CLI Status intents still reported A1 and B1 and returned to Lab 3. | Presentation after this process termination was not captured separately. |
| After stopping A while B remained active | A's intent receipt reported zero; B's prior active receipt remained. | B's `Flame` widget appeared, confirming that B's extension rendered. |
| After CLI stop | A0 and B0. | A separate Lab UI test still found `Running: 1`; it then ended Lab's activity through Lab's own control and found `Running: 0`. |

Evidence retained locally includes `/tmp/islandstack-stage3-target-plus-two.png` for the Lab foreground state and accessibility logs under `/tmp/islandstack-spike-20260927/stage3-final-island-ax-settled.log` and `stage3-final-island-b-ax.log`. The screenshot alone is not proof of all Island positions; the accessibility snapshots and fresh receipts carry separate presentation and ActivityKit claims.

The result is **three active activities across three app identities, with two minimal positions observed at once**. It does not prove that the third activity can never appear while all three remain active. No successful three-item switching gesture was established. Lock Screen layout, lock/unlock behavior, and presentation after helper process termination remain to be checked. A temporary XCTest Lock Screen probe did not compile because this local `XCUIDevice.Button` API has no `lock` case; it produced no runtime evidence and was removed. Apple's [ActivityKit presentation guidance](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) describes system selection of compact and minimal presentations, and the [iOS 27 iPhone guide](https://support.apple.com/guide/iphone/view-live-activities-in-the-dynamic-island-iph28f50d10d/27/ios/27) describes switching between Live Activities. The CLI should therefore report active counts without promising three simultaneous compact items.

No Gymrat repository files or installed target build were changed in this stage. The reference activity was ended after verification and the dedicated Simulator was shut down.
