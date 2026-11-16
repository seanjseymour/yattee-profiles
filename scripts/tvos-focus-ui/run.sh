#!/bin/bash
set -euo pipefail
: "${CI_OUTPUT:?}" "${DERIVED_DATA:?}" "${RUNNER_TEMP:?}"
# xcodeproj is already pinned in this repository's Gemfile.lock. Isolate its
# installation in runner temp; no credentials, system gem changes, or signing.
export GEM_HOME="$RUNNER_TEMP/focus-ui-gems"
export GEM_PATH="$GEM_HOME"
gem install xcodeproj --version 1.27.0 --no-document
ruby scripts/tvos-focus-ui/make_project.rb "$RUNNER_TEMP/focus-ui-project" scripts/tvos-focus-ui/ViewerRemoteUITests.swift
xcrun simctl list runtimes -j > "$CI_OUTPUT/simulator-runtimes.json"
xcrun simctl list devicetypes -j > "$CI_OUTPUT/simulator-devicetypes.json"
# Apple-hosted bash is 3.x: select identifiers with Python, no readarray.
runtime_id=$(python3 -c 'import json,sys; a=[x["identifier"] for x in json.load(open(sys.argv[1]))["runtimes"] if "tvOS" in x["identifier"] and x.get("isAvailable")]; assert a, "No available tvOS runtime"; print(a[-1])' "$CI_OUTPUT/simulator-runtimes.json")
device_id=$(python3 -c 'import json,sys; a=[x["identifier"] for x in json.load(open(sys.argv[1]))["devicetypes"] if "Apple-TV-4K" in x["identifier"]]; assert a; print(a[-1])' "$CI_OUTPUT/simulator-devicetypes.json")
sim_id=$(xcrun simctl create "Viewer focus regression" "$device_id" "$runtime_id")
trap 'xcrun simctl shutdown "$sim_id" || true; xcrun simctl delete "$sim_id" || true' EXIT
xcrun simctl boot "$sim_id"
xcrun simctl bootstatus "$sim_id" -b
xcrun simctl install "$sim_id" "$DERIVED_DATA/Build/Products/Debug-appletvsimulator/Yattee.app"
xcodebuild test -project "$RUNNER_TEMP/focus-ui-project/FocusRemote.xcodeproj" \
  -scheme FocusRemote -destination "platform=tvOS Simulator,id=$sim_id" \
  -derivedDataPath "$RUNNER_TEMP/focus-ui-derived" \
  -resultBundlePath "$CI_OUTPUT/viewer-focus-ui.xcresult" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  2>&1 | tee "$CI_OUTPUT/viewer-focus-ui.log"
