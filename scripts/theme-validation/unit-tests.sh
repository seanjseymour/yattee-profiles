#!/bin/bash
set -euo pipefail
# Add launch-fixture environment only to this runner's test scheme. No shipping
# project or scheme change is committed into the production candidate.
cp Yattee.xcodeproj/xcshareddata/xcschemes/Yattee.xcscheme "$CI_OUTPUT/original-test-scheme.xml"
python3 - <<'PY'
import xml.etree.ElementTree as ET
p='Yattee.xcodeproj/xcshareddata/xcschemes/Yattee.xcscheme'
t=ET.parse(p);a=t.getroot().find('TestAction');a.set('shouldUseLaunchSchemeArgsEnv','NO')
e=ET.SubElement(a,'EnvironmentVariables');ET.SubElement(e,'EnvironmentVariable',{'key':'YATTEE_FOCUS_UI_ITEMS','value':'0','isEnabled':'YES'})
t.write(p)
PY
xcodebuild test -project Yattee.xcodeproj -scheme Yattee -configuration Debug \
 -destination "platform=tvOS Simulator,id=$TVOS_SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
 -clonedSourcePackagesDirPath "$PACKAGE_CACHE" -disableAutomaticPackageResolution \
 -onlyUsePackageVersionsFromResolvedFile -only-testing:YatteeTests/TVAppearanceSettingsTests \
 -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
 -resultBundlePath "$CI_OUTPUT/theme-preferences.xcresult" \
 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
 2>&1 | tee "$CI_OUTPUT/theme-preferences.log"
