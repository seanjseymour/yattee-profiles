# Internal tvOS releases through GitHub Actions

Xcode Cloud onboarding failed with CommandHandlerError code 5. The selected
release path is now the manually triggered `tvOS internal TestFlight` workflow.
No Xcode Cloud hook is installed.

## One-time setup

Create the GitHub environment `tvos-testflight`, restricted to `main`.
Set its variable `YATTEE_PROFILES_TEAM` to the paid development team's ID.
Store these values as environment secrets, never as files in this public repo:

| Secret | Value |
| --- | --- |
| `DISTRIBUTION_P12_BASE64` | Base64 of an exportable Apple Distribution certificate **and its private key** in a password-protected .p12 |
| `DISTRIBUTION_P12_PASSWORD` | Password for that .p12 |
| `TVOS_APP_PROFILE_BASE64` | Base64 of the tvOS App Store distribution profile for `com.seanjseymour.yatteeprofiles` |
| `TVOS_TOPSHELF_PROFILE_BASE64` | Base64 of the tvOS App Store distribution profile for `com.seanjseymour.yatteeprofiles.TopShelf` |
| `ASC_PRIVATE_KEY_BASE64` | Base64 of the dedicated App Store Connect team API key .p8 |
| `ASC_KEY_ID` | That key's ID |
| `ASC_ISSUER_ID` | Its issuer ID |

Both profiles must include the imported distribution certificate and the fork's
app group. The main profile must include the fork's iCloud container, CloudKit,
and production push entitlement. A cloud-managed certificate without an
exportable private key cannot be used as the .p12. Do not revoke existing keys
or certificates belonging to other apps to make space.

Use a dedicated App Store Connect team API key with the Developer role for
uploading; team API keys are not limited to one app. Store it only in the release
environment. The workflow does not create certificates, profiles, or testers.

Enable automatic distribution for the existing `Apple TV Baseline` internal
group if desired; otherwise add each processed build to that group manually.
Do not add external tester groups.

## Each release

1. Merge reviewed source changes to `main`.
2. In Actions, select `tvOS internal TestFlight` and Run workflow on `main`.
3. Supply an unused build number at least 280, greater than the last upload.
   Use a new number if retrying a run whose upload may already have succeeded.
4. The workflow resolves pinned dependencies, validates both profiles, imports
   signing material into a temporary keychain, archives Release for generic
   Apple TV, checks the signed archive's app/extension IDs and build numbers,
   and exports/uploads with `testFlightInternalTestingOnly=true`.
5. Verify Apple processing and availability in Apple TV Baseline, then install
   via TestFlight and check source persistence and playback with iCloud sync off.

No local Xcode build is required. Only the selected fork app is archived; the
inherited Fastlane multi-platform release lanes are not invoked. There are no
push or pull-request triggers. Workflow dispatch on a branch other than main
is skipped. Upload success is not a claim of TestFlight processing or playback.

Temporary certificates, profiles, API key, archive, and keychain are deleted in
an always-run cleanup step. No signing material is published as an artifact.
The runner/toolchain matches the existing unsigned workflow; signed execution
remains unverified until the first successful run.

## Validation and known state

Build 279 is shown as Testing in internal TestFlight. The server fix passed a
local Debug playback/source-persistence smoke test; the uploaded build's device
test has not been separately reported. Build 278 contains the detection bug.
Media framework dSYM upload warnings remain a separate diagnostic limitation.

Python regression tests and shell/YAML validation can run on Linux. Archive,
manual distribution signing, upload authentication, and Apple processing must
be checked on the release runner.

References: [GitHub signing setup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications),
[Apple API keys](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).
