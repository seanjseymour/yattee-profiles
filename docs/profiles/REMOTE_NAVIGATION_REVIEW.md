# tvOS remote navigation review candidate

Base: `2a154392bacccaacf67b35169a0a64bce80f2cce` (build 282).
Sean verified the picker Rename → Down → Add correction on device. This patch
preserves `ViewerPickerView.swift` byte-for-byte.

## Reproductions and ownership correction

1. Owner photo inspected locally: Home, a single Continue Watching video tile
   focused at mid-left, Viewer: Sean at upper right. Right from the tile failed
   to reach Viewer. The JPEG decoded successfully (202207 bytes, 1260 × 1680);
   neither the photo nor its contents are included in repository/test artifacts.
2. Owner report and parent inspection: Settings root, Viewer: Leslie focused;
   Back exited rather than staying in the app. This second photo was not
   independently materialized in this executor.

The prior launcher was outside the per-tab NavigationStacks. Its small top-right
frame was not adjacent to content tiles and it had no current-tab Back ownership.
The fix moves viewer chrome inside each tab's root, with native focus sections
on the content and a full-height trailing region. Content controls remain native:
Right visits any intervening video before reaching Viewer, and Left can return
from the top-aligned Viewer button to content below it. This follows Apple's
[directional focus guidance](https://developer.apple.com/documentation/swiftui/view/focussection()).

The launcher alone handles Back at non-Home roots by selecting Home. At Home it
installs no Back handler. Pushed screens do not carry the root launcher, so native
Back can pop the nearest detail instead of skipping to Home. The existing picker
owns its cover/editor dismissal; cover dismissal returns focus to Viewer. There
is no global directional handler, gesture recognizer, or app-wide Back override.

Tradeoff: the trailing region reserves 360 points of horizontal space; screen
width/layout and long viewer names need device review. Viewer access is at tab
roots, not on pushed details. Back from a detail first returns to its root.

## Input and evidence matrix

`SOURCE` means inspected code, not runtime acceptance. `UI` is reserved for a
passing, named XCUIRemote assertion in the recorded workflow. `DEVICE` means
Sean's reported device result, not inferred from compilation.

| Surface/state | Directions and Select | Back ownership/expected result | Other input | Evidence / remaining verification |
| --- | --- | --- | --- | --- |
| Home, one Continue Watching tile | Right → Viewer; Select → picker; Left → tile | Home native sidebar/root handling remains; true Home-root exit may be a system action | Long Select opens native video context menu | Owner-reproduced failure; UI test `testSingleContinueWatchingTileReachesViewerAndPicker` added |
| Home, two/many tiles | Right visits next tile before Viewer; reverse Left visits last/previous tile | Native Home handling | Long Select uses `VideoContextMenu` | UI test `testRightVisitsNextTileBeforeViewerAndLeftReturns` covers two; long/scrolled shelves remain device checks |
| Empty Home | Open Sources remains focusable; Right → Viewer; Left → Sources | Native Home handling, no global exit suppression | Select Sources selects its tab | UI test `testEmptyHomeCanReachViewerAndReturn` added |
| Sidebar/tab selection | Native directional tab navigation and Select | Native sidebar levels; no new root interception | Home/TV button and system app switcher remain system-owned | SOURCE: `UnifiedTabView`, `NavigationRouter`; full sidebar traversal still device check |
| Settings root, Viewer focused | Left returns to settings content; Select opens picker | Scoped Viewer Back → Home, app stays foreground | No transport handler added | Owner-reproduced failure; UI test `testSettingsDetailBackAndLauncherBackStayInApp` added |
| Settings root, list focused | Native Up/Down; Select pushes selected page; Right → Viewer | Native tab/sidebar Back (not the Viewer's explicit fallback) | Native controls | SOURCE; UI test reaches Appearance from list; all individual settings rows not automated |
| Settings subpage and nested page | Native focus/select; launcher absent while pushed | Native link/NavigationStack pops one level; `TVSidebarDetailContainer` force-pop notification only on tab change | Editor/alert owns its own input | UI test covers Appearance → Back → Settings; deeper editors remain device checks |
| Viewer picker | Active viewer initially focused; rows/Rename/Add reachable; Select viewer saves and dismisses | Picker Back dismisses cover and restores Viewer focus | No Play/Pause/long-Select override | DEVICE: build 282 Rename → Add verified; UI test checks two rows, Add, active selection and reopening |
| Viewer name editor | Native tvOS keyboard; Save validates; Cancel does not save | Editor Back first; subsequent Back dismisses picker | System text entry/dictation remains native | SOURCE: alert plus picker guard; regression test should verify editor Back separately |
| Search / text entry | Native searchable field/keyboard; results use native video buttons | Keyboard/filter sheet first, then navigation level; never root fallback while launcher not focused | System text entry | SOURCE: `SearchView` searchable and sheets; keyboard/remote/dictation not automated |
| Video details | Native controls; Select follows configured video tap action | Typed NavigationStack path pops nearest destination | Native context menu | SOURCE: `TappableVideoModifier`, `VideoInfoView`, router; runtime playback/network details not exercised |
| Media browser / source lists | Native buttons/links; focus sections on relevant content | NavigationStack pops folder/detail before root | File actions/password alerts remain existing behavior | SOURCE; NAS device regression required; no credentials/network fixtures used |
| Global sheet / nested sheet / alert | Presented UI owns focus and Select | Innermost presentation first | No underlying launcher handler added | SOURCE: `PresentationRouter` recursive `appSheetHost`; stacked modal runtime checks pending |
| Quality/settings panel | Native stream/subpage controls | Pop panel's path before `performDismiss()` | Player transport remains existing behavior | SOURCE: `QualitySelectorView.onExitCommand`; no changes |
| Queue panel | Native queue item navigation/Select | `QueueManagementSheet` dismisses panel | Existing queue actions | SOURCE; no changes; playback device check |
| Player details / locked description | Select toggles description scroll lock; Up/Down scroll when locked | First unlock description, then dismiss panel | Other panel tabs native | SOURCE: `TVDetailsPanel`; no changes |
| Player transport / scrub | Hidden background Left/Right seeks; Up/Down/Select reveal controls. Focused progress Left/Right seek; scrub has its own behavior | Error details/failure/autoplay/debug/quality/queue/details/scrub/controls are handled before player dismissal/close | Play/Pause toggles playback (or cancels countdown); arrow holds use existing window recognizers | SOURCE: `TVPlayerView`, `TVPlayerProgressBar`, `TVRemoteHoldSeekObserver`; actual media/remote transport not automated |
| System-level controls | TV/Home, app switching, volume, Siri follow tvOS | True Home-root exit intentionally preserved | Long TV/Home is system-owned | No app handlers added; physical remote check |

## Audit risks not promoted to confirmed bugs

- Real swipe velocity, continuous holds, system keyboard/dictation and transport
  require the physical remote; button-press automation is not equivalent.
- The player has several Back owners (panel and parent). Source shows intended
  priority, but only runtime testing establishes actual event precedence.
- Hold-seek activation excludes details/debug/quality/queue/scrub, but does not
  explicitly exclude every error/countdown state. Review that separately with
  playback evidence; this patch does not alter transport speculatively.
- Native Back from focused Settings list vs focused launcher differs: list uses
  sidebar behavior; launcher explicitly returns Home. Both must remain in-app
  until a true root/system exit. The regression must not pass solely by seeing
  that the app process still exists: assertions check `runningForeground`.

## Hosted test method and limits

The original CI workflow only compiled for a generic simulator. The focused
branch adds one unsigned UI-test step using an ephemeral tvOS simulator. A small
Ruby generator uses `xcodeproj` 1.27.0 (already in Gemfile.lock) in runner temp to
create an external UI-test project, leaving the production project, entitlements,
signing, security permissions and release workflow unchanged. XCTest is used only
because the requested XCUIRemote API requires it; model tests stay Swift Testing.

The real app gets an explicit DEBUG + tvOS + simulator-only fixture with 0/1/2
in-memory WatchEntry records and two local viewer names. No live NAS or credentials
are used. The hook is absent from device/Release builds. Stable accessibility
identifiers identify actual Home buttons; tests send XCUIRemote presses and
assert `hasFocus`, selected viewer labels, and foreground app state. The runner
captures only synthetic-fixture screenshots, the accessibility tree, logs and
xcresult. It never uploads the owner photo.

Results and exact candidate receipts are recorded in the implementation handoff.
A compile-only result is never UI/DEVICE evidence. If the test harness cannot
launch on the hosted image, keep all corresponding matrix rows unverified.

Hosted execution is feasible: run
[43798346689](https://github.com/seanjseymour/yattee-profiles/actions/runs/43798346689)
at `1c949cb50ed0644b8f2ec0d349f49cda3e08b77b` compiled the app/Top Shelf and passed
the empty Home, two-tile traversal and single-tile/picker remote tests. The
Settings test stopped in setup because it queried the child button rather than
the focused native List cell; the harness now queries the cell. That run does
not establish Settings Back behavior. Earlier unsigned launch diagnostics
identified a CKContainer entitlement trap; the explicit simulator fixture now
disables CloudKit availability before environment initialization. This exclusion
is absent from device and Release builds and changes no signing or entitlements.
Use the final handoff's exact-SHA receipt for the subsequent full-suite result.

## Short physical retest

1. Home with one tile: Right → Viewer → Select → picker; Back → Viewer; Left →
   tile. With two tiles, Right must visit the second first. Repeat on empty Home.
2. Settings: focus Viewer, open and close picker, then Back: Home, not tvOS.
   Open a Settings subpage: Back returns one level to Settings, not Home.
3. Confirm build 282 picker behavior (Rename → Down → Add), editor Back before
   picker Back, active-viewer focus, and selection after normal relaunch.
4. Smoke-test Search keyboard, video details/context menu, stacked sheets, NAS
   playback, Play/Pause, seek/scrub and Back through player overlays. At true Home
   root, intentional system exit must still work.

No main promotion or signed upload is authorized in this implementation thread.
The exact patch needs independent review before the build thread handles release.
