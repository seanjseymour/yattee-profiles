#!/bin/bash
set -euo pipefail
: "${CI_OUTPUT:?}" "${DERIVED_DATA:?}" "${RUNNER_TEMP:?}"
# xcodeproj is already pinned in this repository's Gemfile.lock. Isolate its
# installation in runner temp; no credentials, system gem changes, or signing.
export GEM_HOME="$RUNNER_TEMP/focus-ui-gems"
export GEM_PATH="$GEM_HOME"
gem install xcodeproj --version 1.27.0 --no-document
ruby scripts/tvos-focus-ui/make_project.rb "$RUNNER_TEMP/focus-ui-project" scripts/tvos-focus-ui/ViewerRemoteUITests.swift
: "${TVOS_SIM_UDID:?}"
sim_id="$TVOS_SIM_UDID"
# Persist actual Slate choice for the legacy suite's history-marker card check.
# No special theme default or focus behavior is injected into the fixture.
SIMCTL_CHILD_YATTEE_FOCUS_UI_ITEMS=0 SIMCTL_CHILD_YATTEE_THEME=slate \
 xcrun simctl launch "$sim_id" com.seanjseymour.yatteeprofiles
sleep 3
xcrun simctl terminate "$sim_id" com.seanjseymour.yatteeprofiles
xcodebuild test -project "$RUNNER_TEMP/focus-ui-project/FocusRemote.xcodeproj" \
  -scheme FocusRemote -destination "platform=tvOS Simulator,id=$sim_id" \
  -derivedDataPath "$RUNNER_TEMP/focus-ui-derived" \
  -resultBundlePath "$CI_OUTPUT/viewer-focus-ui.xcresult" \
  -only-testing:FocusRemote/ViewerRemoteUITests/testViewerHistoryAdaptersAndUpgradePreservation \
  -only-testing:FocusRemote/ViewerRemoteUITests/testSearchHeaderAndOptionsBoundary \
  -only-testing:FocusRemote/ViewerRemoteUITests/testSettingsRootHeaderSeparation \
  -only-testing:FocusRemote/ViewerRemoteUITests/testSourcesRootHeader \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  2>&1 | tee "$CI_OUTPUT/viewer-focus-ui.log"
