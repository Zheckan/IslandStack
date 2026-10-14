# Interactive installer and three helper apps

Date: 13 October 2026. This extends the original two-helper CLI with a third identity and an installation flow for people who want to activate activities by tapping the apps.

## User flow

After npm publication, `npx islandstack` builds the Swift launcher, lists eligible booted iPhone Simulators when there is more than one, and asks whether to install one, two, or three helper apps. With one eligible device, it selects that device automatically. With no eligible devices, it reports an error. The picker uses the existing iOS 17-or-newer iPhone eligibility check; it does not detect Dynamic Island hardware. Choose a Simulator with Dynamic Island to test Island presentation.

Updated 14 October 2026. Both menus use the full-screen setup layout from dotfiles' model picker, with highlighted choices, a **What this does** explanation, and a keyboard footer. Up/down arrows or J/K navigate, and Enter confirms. Selection wraps at the ends of the list. Esc returns from helper count to the Simulator picker and retains the previous Simulator selection. On the first screen, Esc cancels. Q and Ctrl+C cancel from either screen with exit code 130. Exiting restores terminal settings, cursor visibility, and the previous terminal screen. Piped input, redirected output, and `TERM=dumb` retain numeric input. No terminal UI dependency is installed.

The selected count installs A, A/B, or A/B/C. Every helper has a separate app and widget bundle identity. Installation leaves previously installed helpers and their activities alone. Each app is one full-page button, labeled **Activate Live Activity** while stopped and **Stop Live Activity** while active. Each helper deliberately maintains one activity. This is the tool's contract, not an ActivityKit limit of one activity per app.

For automation, use `install --competitors 3 --device <udid>` without prompts. Existing `start`, `status`, and `stop` commands still use built-in App Shortcuts and restore `--return-to`. Starting a smaller count stops the unused helpers; stopping visits all three independently. Active counts do not guarantee the same number of visible Island items.

## App icon

The icon source is `ios/Competitor/AppIcon.icon`, an Icon Composer document shared by the three helper app builds. It shows a Dynamic Island split into a pill and a separate bubble, with the helpers' cyan, orange, and purple colors. It has light and dark backgrounds; Xcode generates the tinted and clear variants. The artwork contains no Apple logo or SF Symbols.

`docs/logo/logo-light.png` and `docs/logo/logo-dark.png` are 256 px README renders. Regenerate them with Icon Composer's `ictool`:

```sh
ictool ios/Competitor/AppIcon.icon --export-image --output-file docs/logo/logo-dark.png --platform iOS --rendition Dark --width 256 --height 256 --scale 1
```

## Verification

- `swift test`: 12 tests passed. The new three-competitor regression failed before implementation because the host accepted only one or two. It now verifies three starts, reduction to one, and cleanup to zero. Other new tests verify installation does not start activities and invalid counts do not install apps.
- Seven pseudo-terminal/pipe CLI tests passed, covering second-Simulator selection, count selection with both arrow directions and wraparound, J/K navigation with changing explanations, Esc back-navigation that preserves the previous Simulator, Q/Ctrl+C cancellation, terminal restoration, recovery after terminal resizing, and invalid numeric input. J/K selection failed before the full-screen setup change. The original count-selection test failed before implementation because only a numeric prompt existed. These checks stop before installation.
- The earlier inline arrow menus also ran through `npx --yes --package=<archive> islandstack` in a terminal with `TERM=xterm-256color`. Down/Enter selected the second Simulator, two Down presses highlighted three helper apps, and Esc cancelled with exit code 130. A `TERM=dumb` run displayed the numeric fallback. Neither menu trial installed apps.
- All three native app and widget variants built and installed on the existing iPhone 18 Pro Max Simulator, iOS 27.0, UDID `6B3EAAB6-3D78-4DC8-BFAB-6D3B4044C41B`.
- On that Simulator, tapping A's full-page button changed **Activate Live Activity** to **Stop Live Activity**; tapping again restored **Activate Live Activity**.
- A locally packed npm archive ran through `npm exec --yes --package=<archive> -- islandstack` from an unrelated caller directory. It listed both booted iPhones, rejected invalid device and count input, and installed A/B/C on the selected device. This verifies the packaged flow without claiming the package is published to npm.
- From a packed archive outside the checkout, `start --competitors 3` and subsequent fresh `status` each reported A1/B1/C1 and restored Safari. The first C start timed out because its assumed symbol label was wrong. A live Shortcuts accessibility snapshot identified the actual label, **Do Not Disturb**, and the corrected driver completed the three-app start.
- From the same packed archive, `stop` reported A0/B0/C0 and restored Safari. All IslandStack activities created in this trial were stopped; the helper apps remain installed for manual testing.

The registry release remains separate. Physical devices, another Mac, and additional iOS/Xcode versions have not been verified in this change.

## Compact Island layout fix, 14 October 2026

The compact timer previously filled its available width, causing the Island to occupy most of the status bar. All three helpers now share a bounded countdown with monospaced digits: 44 points in the compact Island and 56 points in expanded and Lock Screen presentations. The interval ends at the activity deadline, so the timer holds at zero instead of counting upward after expiry. Explicit stop remains the activity cleanup contract.

This follows [Apple's widget timer guidance](https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:)), which explains why timer text needs a constrained frame.

On an isolated iPhone 15 Pro Simulator running iOS 27.0, SpringBoard accessibility measurements showed:

| Measurement | Before | After |
| --- | ---: | ---: |
| Compact Island width | 319.7 pt | 214.3 pt |
| Timer text width | 90.3 pt | 44.0 pt |

All three app/widget variants rebuilt and installed, and all 12 host tests passed. A focused UI regression starts A, returns Home, and checks the Island and timer bounds. It failed both assertions with the original widget and passed with the fixed widget. Run it on a Dynamic Island Simulator with A installed and other activities stopped:

```sh
xcodebuild test -project ios/ShortcutDriver.xcodeproj -scheme ShortcutDriver \
  -destination 'platform=iOS Simulator,id=<udid>' \
  -only-testing:ShortcutDriverUITests/ShortcutActionsUITests/testCompactIslandFitsStatusBar
```

The Simulator screenshot stream omits the Island overlay, so the layout evidence comes from its accessibility frames. Expiry was not observed by waiting out a full 20-minute activity.
