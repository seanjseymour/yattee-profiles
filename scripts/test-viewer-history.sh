#!/bin/bash
set -euo pipefail
: "${RUNNER_TEMP:?}" "${CI_OUTPUT:?}"
test_package="$RUNNER_TEMP/viewer-history-model-tests"
mkdir -p "$test_package/Sources/ViewerHistoryCore" "$test_package/Tests/ViewerHistoryCoreTests"
cp Yattee/Core/ViewerWatchStore.swift Yattee/Core/ViewerPlaybackOwnership.swift "$test_package/Sources/ViewerHistoryCore/"
cp YatteeTests/ViewerWatchStoreTests.swift "$test_package/Tests/ViewerHistoryCoreTests/"
cat > "$test_package/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ViewerHistoryCore", platforms: [.macOS(.v15)],
    products: [.library(name: "ViewerHistoryCore", targets: ["ViewerHistoryCore"])],
    targets: [.target(name: "ViewerHistoryCore"),
              .testTarget(name: "ViewerHistoryCoreTests", dependencies: ["ViewerHistoryCore"])])
SWIFT
xcrun swift test --package-path "$test_package" 2>&1 | tee "$CI_OUTPUT/viewer-history-model-tests.log"
