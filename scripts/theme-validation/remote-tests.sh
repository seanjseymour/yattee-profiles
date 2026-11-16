#!/bin/bash
set -euo pipefail
export GEM_HOME="$RUNNER_TEMP/theme-ui-gems"
export GEM_PATH="$GEM_HOME"
gem install xcodeproj --version 1.27.0 --no-document
ruby scripts/theme-validation/make_project.rb "$RUNNER_TEMP/theme-ui-project" scripts/theme-validation/ThemeRemoteUITests.swift
xcodebuild test -project "$RUNNER_TEMP/theme-ui-project/FocusRemote.xcodeproj" \
 -scheme FocusRemote -destination "platform=tvOS Simulator,id=$TVOS_SIM_UDID" \
 -derivedDataPath "$RUNNER_TEMP/theme-ui-derived" \
 -resultBundlePath "$CI_OUTPUT/theme-remote.xcresult" \
 -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
 2>&1 | tee "$CI_OUTPUT/theme-remote.log"
