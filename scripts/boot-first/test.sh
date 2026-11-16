#!/bin/bash
set -euo pipefail
: "${CI_OUTPUT:?}" "${DERIVED_DATA:?}" "${RUNNER_TEMP:?}"
# xcodeproj is already pinned in this repository's Gemfile.lock. Isolate its
# installation in runner temp; no credentials, system gem changes, or signing.
export GEM_HOME="$RUNNER_TEMP/focus-ui-gems"
export GEM_PATH="$GEM_HOME"
gem install xcodeproj --version 1.27.0 --no-document
ruby scripts/tvos-focus-ui/make_project.rb "$RUNNER_TEMP/focus-ui-project" scripts/tvos-focus-ui/ViewerRemoteUITests.swift
: "${TVOS_SIM_UDID:?Boot-first simulator required}"
sim_id="$TVOS_SIM_UDID"
xcodebuild test -project "$RUNNER_TEMP/focus-ui-project/FocusRemote.xcodeproj" \
  -scheme FocusRemote -destination "platform=tvOS Simulator,id=$sim_id" \
  -derivedDataPath "$RUNNER_TEMP/focus-ui-derived" \
  -resultBundlePath "$CI_OUTPUT/viewer-focus-ui.xcresult" \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  2>&1 | tee "$CI_OUTPUT/viewer-focus-ui.log"
