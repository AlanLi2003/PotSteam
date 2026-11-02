#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Dedicated disposable QA phone. Never substitute `booted` or the Duo UDID.
qa_device="734C746B-F86E-436C-97B3-ABB2F39E06DD"
run_stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p artifacts/native-tests
xcrun simctl bootstatus "$qa_device" -b
xcodebuild -project ios/CNrecipe.xcodeproj -scheme CNrecipe -configuration Debug \
 -destination "platform=iOS Simulator,id=$qa_device" -derivedDataPath artifacts/NativeSignedDerivedData \
 CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing \
 2>&1 | tee "artifacts/native-tests/$run_stamp-build.log"
xcrun simctl install "$qa_device" artifacts/NativeSignedDerivedData/Build/Products/Debug-iphonesimulator/CNrecipe.app
python3 scripts/prepare-qa-dates.py
xcodebuild -project ios/CNrecipe.xcodeproj -scheme CNrecipe -configuration Debug \
 -destination "platform=iOS Simulator,id=$qa_device" -derivedDataPath artifacts/NativeSignedDerivedData \
 -resultBundlePath "artifacts/native-tests/$run_stamp.xcresult" \
 CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
 -only-testing:CNrecipeTests -only-testing:CNrecipeUITests/NativeAcceptance test-without-building \
 2>&1 | tee "artifacts/native-tests/$run_stamp.log"
