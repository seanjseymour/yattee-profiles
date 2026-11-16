# Local viewer picker candidate

Base: `1e92ef0399851c4ade563059112d34e99f0a267f`, accepted on TV Room as
TestFlight 2.0.0 (280) for NAS playback. Independent Top Shelf acceptance was
not reported.

## Scope and storage

- tvOS has a visible viewer button above the main content, opening a full-screen
  picker. The active card receives initial focus. Selecting a card commits and
  dismisses; Back/Close dismiss without changing selection. Focus returns to the
  opener. Add and Rename are explicit actions; switching requires no text entry.
- First use seeds one Default viewer. Add keeps the current viewer selected.
  Names are trimmed, nonempty, at most 40 characters, and unique ignoring case
  and diacritics. Renaming preserves the UUID. There is no deletion.
- A versioned JSON record in app-local UserDefaults stores profiles and selection
  together under `yatteeProfiles.localViewers.v1`. No app-group or cloud storage
  is added. A missing/dangling active ID falls back to the first saved viewer.
  Unreadable, empty, duplicate-ID, wrong-type, or newer-version records are kept
  untouched; the picker explains the failure and refuses changes.
- The manager has no account, network, credential, player, or SwiftData dependency.
  NAS connection, data context, app identity, settings and existing content remain
  shared and unchanged. The picker explicitly explains that history and bookmarks
  are still shared. This is identity selection, not history isolation.
- Normal relaunch persistence is the acceptance target. UserDefaults is not a
  recovery design for growing history, reinstall, or device loss. Per-viewer
  history ownership, playback attribution and cache-loss recovery remain separate.

## Automated verification

`ViewerProfilesTests` uses isolated defaults suites and Swift Testing. It covers
first-use upgrade, shared defaults preservation through edits/switching, stable
IDs, reload, name validation, invalid selections, selection repair, and preservation
of malformed/newer saved records. Reconstructing the manager is not an on-device
process-relaunch test.

On an Apple development machine, run:

```sh
xcodebuild test -scheme Yattee -destination 'platform=macOS' -only-testing:YatteeTests/ViewerProfilesTests
```

Also run the existing navigation/account regression suites and unsigned tvOS
simulator build. The repository's manual `tvos-simulator.yml` builds the app and
Top Shelf extension; it does not launch the app or run unit/UI tests.

Initial Linux checks: 10 Python configuration/release-script tests passed;
localization JSON parses, 13 new keys have English values, and all existing
localization entries are preserved. `git diff --check` passes. Swift, Xcode,
Ruby and Periphery are unavailable here; Swift tests and Apple UI behavior must
not be described as passed based on these checks.

## Apple TV acceptance checklist

1. Upgrade the accepted app in place. Confirm NAS connection, existing history,
   bookmarks, settings and app identity are retained; official app still coexists.
2. Open the picker with the Siri Remote. The active card must be initially focused,
   including after enough profiles are added to place it offscreen.
3. Add two distinct names. Add alone must not switch viewers. Rename an inactive
   and active viewer; selection and IDs must remain stable. Invalid/duplicate names
   must show an error without losing the previous record. Cancel editing with Back.
4. Highlight another viewer and press Back: current viewer is unchanged. Reopen,
   press Select on that viewer: picker closes and opener label updates. Focus must
   return to the opener, with no focus trap or unwanted keyboard.
5. Terminate the app and relaunch: names and active viewer remain. Repeat offline.
6. Play NAS video, return to browsing with playback retained, switch viewers, and
   resume playback. No credential prompt, server change, or player reset.
7. Verify existing sidebar/tab navigation, overlays, and Top Shelf regression
   behavior; independent Top Shelf acceptance is still needed.

## Release handoff

The Apple TV Build thread owns the single signed internal upload. No signing,
entitlements, version, workflow, or baseline changes belong to this candidate.
The current TestFlight workflow has `if: github.ref == 'refs/heads/main'`; it will
skip a feature-branch dispatch. This guard is intentionally unchanged. The build
thread must resolve the protected-main promotion/release path with Sean before an
upload; do not merge or bypass protection from this thread.
