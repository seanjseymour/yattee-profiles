# tvOS internal TestFlight workflow

Repository preparation is local until committed and pushed. Cloud configuration
and successful cloud signing/upload must be verified separately.

## Workflow settings

- Product: existing Yattee Profiles App Store Connect record,
  `com.seanjseymour.yatteeprofiles`, with the paid development team.
- Repository access: only `seanjseymour/yattee-profiles`.
- Project: `Yattee.xcodeproj`; scheme: `Yattee`; platform: tvOS.
- Action: Archive, Release configuration, TestFlight Internal Only distribution.
- Environment: Xcode 27.2 initially, matching the verified local toolchain.
- Start manually for the first verification. Once successful, use changes to
  `main` as the start condition. Do not distribute pull-request builds.
- TestFlight post-action: the existing `Apple TV Baseline` internal group.
- Set the next cloud build number to 280 or higher than any build uploaded since
  setup began. Xcode Cloud manages subsequent build numbers automatically.

## Signing

`ci_scripts/ci_post_clone.sh` uses Apple's `CI_TEAM_ID` to resolve
`$(YATTEE_PROFILES_TEAM)` in the temporary cloud checkout before building.
It makes no changes on ordinary local runs. Apple manages cloud signing;
no certificates, private keys, App Store Connect keys, or concrete team ID
are stored in the repository. Main app and Top Shelf retain distinct IDs and
use the same team. Local Xcode signing edits remain local.

## First cloud build verification

1. Confirm the pushed revision includes the server detector fix and cloud hook.
2. Finish GitHub authorization and select the existing Apple app record.
3. Verify the workflow settings above before starting the build.
4. Check successful archive/upload, internal-only marking, and availability to
   Apple TV Baseline in TestFlight. Add the build to that group if needed.
5. Install through TestFlight and confirm source persistence and playback with
   iCloud sync off. A successful local Debug test does not verify this cloud build.

Build 278 uploaded with missing dSYM warnings for media frameworks; keep tracking
those separately from archive/upload failures. No profile picker is implemented.

## References

- [Connect GitHub](https://developer.apple.com/documentation/xcode/connecting-xcode-cloud-to-github)
- [Custom build scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [Cloud environment variables](https://developer.apple.com/documentation/xcode/environment-variable-reference)
- [Internal TestFlight distribution](https://developer.apple.com/documentation/xcode/distributing-your-xcode-cloud-builds-through-testflight)
- [Next cloud build number](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds)
