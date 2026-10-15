# Stage 1 native helper findings

Date: 28 September 2026. Device: IslandStack iPhone 18 Pro simulator `70A4DAE4-7928-4A47-BD0D-B66E1B895C2E`, iOS 27.0. Host: Xcode 27.0.

The checked-in [Competitor Xcode project](../ios/Competitor.xcodeproj/project.pbxproj) builds the same original Swift source under configurations `A` and `B`. Each configuration has its own app and widget extension bundle ID. The app uses ActivityKit for start, status, and stop; the extension supplies Lock Screen and Dynamic Island layouts. Start and Stop `LiveActivityIntent` actions were compiled at this stage and later invoked through the built-in Shortcuts Apps library. A Status App Intent was added in Stage 2 so the CLI can check live ActivityKit state without foregrounding a helper.

| Check | Result |
| --- | --- |
| Unsigned Simulator builds for A and B | Both `xcodebuild` commands succeeded. The built app IDs are `dev.islandstack.competitor.a` and `.b`; widget IDs end in `.a.widget` and `.b.widget`. |
| Install both apps on the iPhone 18 Pro | Both installed without replacing each other. |
| A `start`, then A `start` again after relaunch | Both receipts reported `count: 1` and the same ActivityKit ID. Start is idempotent for this identity. |
| B `start`, then B `status` after relaunch | Both receipts reported `count: 1` and the same B ID. A's later `status` still reported its original ID. |
| A `stop` while B remained active | A reported zero; B still reported its original ID and count one. B `stop` then reported zero. Repeating A `stop` also reported zero. |
| Reference Activity Lab 3 across helper reinstall and use | An XCUITest started one Lab activity and observed `Running: 1`. After reinstalling A and B and running their start/stop commands, a second XCUITest still observed `Running: 1`, then used Lab's own End all control to return it to zero. |
| Final widget presentation | With A and B active, SpringBoard accessibility exposed A's `Flash` minimal content. After A ended, B's `Flame` content appeared. Another app's activity occupied the other visible position. This establishes that both final extensions render, while iOS chose which helper was visible. |

The command receipts were written under each app's Simulator data container as `Documents/response-<requestID>.json`. The test checked the request ID, command, app ID, error, count, and ActivityKit IDs for each response. `observedAt` uses an ISO 8601 timestamp. The launch command briefly foregrounds the helper, so this receipt path is a verified fallback rather than the finished no-helper-UI trigger.

The widget countdown is set to 20 minutes and its `staleDate` is the same time. On the next helper command, the controller ends activities whose deadline has passed. Neither the countdown nor `staleDate` guarantees that ActivityKit ends the activity at 20 minutes while no command runs. The explicit Stop command is verified; automatic expiration still needs a supported design or a narrower product promise. Both variants were rebuilt after adding the expiry check, installed again, and returned zero from `status`.

Stage 1's two-identity, one-activity, relaunch, and isolation checks passed. Automatic expiration remains open. Stage 2 later passed a clean first run by invoking built-in App Shortcuts directly, avoiding the saved-workflow provisioning path that stalled in [Stage 0](stage-0-findings.md). No Gymrat source was changed. All IslandStack activities were stopped at the end of this stage; Activity Lab 3 was restored to the foreground. An unrelated activity remained visible in the Simulator's Island and was left alone.
