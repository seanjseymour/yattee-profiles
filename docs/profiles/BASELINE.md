# Yattee Profiles baseline

Fork: seanjseymour/yattee-profiles.

Upstream: tag 2.0.0-beta.278, commit 71b3b2cce53cdf5c5b0ebd83f771d938f9e7264c.

The fork uses com.seanjseymour.yatteeprofiles. Internal TestFlight builds 278 and
279 have been uploaded. Build 278 has a server-detection regression; the local
Debug fix passed server connection, source persistence, and playback on Apple TV.
Build 279 is Testing in TestFlight; its device playback has not been separately
reported. No profile feature has been added.
For a fresh upstream baseline, the reproducible transform is:

    python3 scripts/configure_profiles.py --bundle-id YOUR.REVERSE.DNS.ID
    python3 scripts/configure_profiles.py --bundle-id YOUR.REVERSE.DNS.ID --apply

The first invocation is a dry run. The second edits only this checkout, records
non-secret identity metadata, and removes the inherited release/AltStore
workflows. It is deliberately one-shot against a fresh upstream baseline so
subsequent reconfiguration cannot leave a mixed identity. Team ID stays outside tracked files: supply YATTEE_PROFILES_TEAM as an xcodebuild build setting via the signed CI configuration. Unsigned simulator builds need no team.

## Isolation

- Main bundle, Top Shelf extension, optional share extension, and test IDs change.
- App-group entitlements and both Swift AppGroup definitions change together.
- CloudKit container resolves to iCloud.<new bundle ID>; app identifiers, background
  identifiers and Handoff types change with it.
- Fork registers only yatteeprofiles:// (default), not yattee://. Generated Top Shelf
  links and Swift routing/parser tests use the new scheme too.
- Display name is Yattee Profiles. Internal project, scheme and module stay Yattee.
- No NAS configuration, existing app data, source credentials or upstream account
  changes are performed. Existing official beta remains installed independently.
- Source login must be entered again; old app data cannot be assumed to migrate.

## Signing and CloudKit gates

Register the main ID, <ID>.TopShelf, group.<ID>.shared, and iCloud.<ID> under Sean's
team. Enable matching capabilities and generate tvOS App Store distribution
profiles for BOTH main app and Top Shelf. Preserve the new iCloud identity in
runtime AppIdentifiers and the signed entitlements.

Do not simply strip iCloud entitlements from a TestFlight build: upstream
CloudKitAvailability treats a missing embedded profile as available. Without a
registered compatible container the app could attempt unavailable CloudKit.
Preferred baseline is a correctly provisioned separate container; its schema must
be initialized/tested and deployed to Production before enabling sync in a
distributed build. A local-only build would need an explicit, tested feature gate
covering CloudKit startup and UI, not just entitlement removal.

The selected cloud release path is [GitHub Actions](GITHUB_ACTIONS.md), with a
manual trigger and internal-only upload. Xcode Cloud onboarding failed with code 5. Do not use
the inherited Fastlane workflow unmodified: it queries build numbers on multiple
platforms and the default beta lane may distribute externally. Keep signing keys
in approved secret storage, never code or this metadata file.

## Verification before upload

1. Run transform and git diff --check; validate all changed plist XML.
2. On a suitable Mac/runner, resolve packages and xcodebuild -showBuildSettings
   for Release with generic/platform=tvOS. Inspect final IDs and team for both targets.
3. Archive and export for App Store Connect using matching distribution profiles.
4. Inspect signed main/extension entitlements and embedded profiles. Confirm no
   upstream identifier or yattee URL registration and no Sparkle symbols in tvOS.
5. Upload internal-only to the new app record, not upstream or StowMo/Zumli.
6. Sean installs via TestFlight alongside official beta, adds existing NAS source,
   and tests cold start, playback, seek/pause, Top Shelf, relaunch and separate data.
7. Test iCloud with only the fork's container before claiming sync works.

The Linux preparation environment has no Xcode, Apple signing, tvOS SDK or device.
Static tests cannot establish archive success, runtime playback or TestFlight acceptance.
