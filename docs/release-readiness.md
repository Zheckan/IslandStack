# Release readiness

Snapshot: 28 September 2026. This is a local review checklist. No commit, push, or release was made in this work session.

## Prepared

- The source checkout has a CLI, two native helper identities, a Shortcuts UI driver, tests, a [README](../README.md), and a proposed [MIT license](../LICENSE).
- `swift test` passed five host tests. Simulator trials on iOS 27.0 exercised a clean first start, fresh status, repeat start, one-competitor transition, repeat stop, and isolation from Activity Lab 3.
- The current `origin` points to [Zheckan/IslandStack](https://github.com/Zheckan/IslandStack). GitHub's repository API reported it as public, with `main` as the default branch and no license in the published repository at this snapshot. GitHub repository search found that exact name under this owner and one differently named `IslandStackControl` repository. A local `command -v islandstack` found no installed command, and Homebrew search found no formula or cask with that name. These checks do not reserve a command name elsewhere.
- Source and widget designs in this repository were written for IslandStack. The Gymrat Activity Lab was a test target and reference; no Gymrat source was copied into this repository.

## Before publishing this work

1. Review the MIT choice and the `Zheckan` copyright line. The LICENSE file is local until the changes are published.
2. Verify a clean checkout on another Mac or macOS user account with full Xcode. Run `swift test`, then the README command sequence on a fresh booted iPhone Simulator. This has not been done.
3. Check the Shortcuts UI driver on any Xcode/iOS versions the README will claim. It currently has direct runtime proof only on Xcode 27.0 with iOS 27.0.
4. Decide whether the public instructions should require explicit `stop` or whether an automatic expiry mechanism must be built. A widget countdown and `staleDate` do not end an idle activity at 20 minutes.
5. Capture Lock Screen and three-activity switching behavior if those presentation claims will be made. Current wording promises only the counts and the two observed minimal positions.
6. Review the full diff and repository name, then commit and push only after authorization. A public repository already exists at the current remote, so a push would make these local changes public.

The new work in the active source tree is uncommitted. `.build/` holds local Swift/Xcode products and is ignored by Git. Simulator trial devices were shut down after their activities were stopped; they were not erased or deleted.
