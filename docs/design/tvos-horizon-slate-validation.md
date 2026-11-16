# Horizon / Slate implementation candidate

## Scope

This is an isolated design candidate based on `dafe9869f3bb73266c38c2a80c8c8e9461a4ea3e` (build 283). It must **not** replace or bypass the separately pending combined Viewer layout / per-viewer history fix. Reconcile that exact reviewed implementation before a release. This candidate does not introduce or claim viewer history isolation.

The approved concept sheet was inspected before implementation. The runtime uses real configured Home sections, not the sample film titles or invented “Recently added” data from the concept:

- Horizon: featured Continue Watching entry with explicit Resume action and large thumbnail, followed by remaining entries and configured sections.
- Slate: grid-first Continue Watching and configured sections.
- Both: consistent Home / Search / Settings / Viewer header, while retaining the native sidebar for the remaining destinations.
- Both: deliberate no-resume state linking to Sources.
- Settings → Appearance: Theme (Horizon / Slate) and Mode (System / Light / Dark), independently persisted on this Apple TV. Default Horizon / System. No legacy history ownership or data migrations.

System removes the UIKit window override instead of persisting the effective light/dark scheme. Explicit modes cover presented content and are reapplied for newly visible windows and when returning to foreground. The existing synced iOS/macOS theme is unchanged.

## Evidence available on Linux

- Exact baseline checked out through Git.
- `git diff --check` passed.
- Static conditional compilation balance checked.
- Semantic palette numeric contrast checked for all four combinations; secondary text is at least 5.54:1, focus foreground is at least 6.89:1.
- Added Swift Testing cases for defaults, local-only storage, independent persistence across all theme/mode combinations, cache invalidation, invalid stored values, and UIKit mapping.

**Native attempt 1:** run 43825470736 proved stable boot and package resolution, then identified `scrollContentBackground` as unavailable on tvOS. The candidate removes that unsupported modifier and retains native adaptive list backgrounds.

**Not yet passed:** Xcode build, Swift tests, Periphery, tvOS remote tests, actual app screenshots, independent visual review. No Apple runtime or Swift toolchain exists in this Linux workspace. Source review and numeric contrast do not substitute for those checks.

## Required exact-revision Apple verification

1. Build the tvOS app and Top Shelf target; run the added preference tests and applicable existing suites.
2. Capture matching Home content in Horizon Light, Horizon Dark, Slate Light, and Slate Dark at the same screen size, including focused and unfocused controls. Also capture zero, one and five Continue Watching entries, long titles, long viewer name, Search, Settings → Appearance and Viewer picker/editor in all four combinations.
3. Verify Home top header can be reached with the remote, traversal never skips an intervening card, Left returns to content from Viewer, and Back from Settings root stays in-app. Because Viewer moved from a trailing column to the header, explicitly verify the previously reported single-tile Right → Viewer route. Do not assume that native focus geometry proves this.
4. Open and dismiss Viewer repeatedly; Rename → Down → Add Viewer remains reachable; Cancel and Back restore sane focus. Navigate between Home/Search/Settings without leaking pushed detail screens.
5. Set each theme/mode combination, terminate and relaunch. Switching theme must preserve mode; switching mode must preserve theme. Observe System while changing tvOS appearance both while active and in background, and while picker/editor is presented. Confirm explicit Light/Dark ignore system changes; returning to System resumes live inheritance.
6. Activate Resume with nonzero saved progress; confirm real playback starts there (including password-protected source and the existing queue list/index/continuation context), rather than only opening details. Test with the generic resume preference set to Start from Beginning and Ask: explicit Resume must still use the saved time. Explicit Resume starts playback directly; ordinary video taps retain their queue-action menu. Remove using the context menu and verify the correct entry is removed.
7. Reconcile and independently review against the combined per-viewer history candidate. Repeat viewer isolation and stale-save/removal tests on the final integrated revision.
8. Independent reviewer must examine actual captures for alignment, spacing, clipping, focus scale, colour contrast and tvOS safe margins. Only then consider the separately authorized internal release workflow. Do not treat this document as release approval.
