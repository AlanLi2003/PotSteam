#!/bin/bash
# Optimized Release tests on the reserved QA simulator, with data restoration.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
qa_device=734C746B-F86E-436C-97B3-ABB2F39E06DD
run_stamp=$(date +%Y%m%d-%H%M%S)
out="${CNRECIPE_RELEASE_TEST_OUTPUT:-artifacts/release-tests/$run_stamp}"
derived=artifacts/ReleaseReadinessDerivedData
mkdir -p "$out"
if [ "${CNRECIPE_SKIP_RELEASE_BUILD:-0}" != 1 ]; then
 xcodebuild -project ios/CNrecipe.xcodeproj -scheme CNrecipe -configuration Release -destination "platform=iOS Simulator,id=$qa_device" -derivedDataPath "$derived" ENABLE_TESTABILITY=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing > "$out/build.log" 2>&1
fi
xcrun simctl boot "$qa_device" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$qa_device" -b > "$out/boot.log"
container=$(xcrun simctl get_app_container "$qa_device" com.cnrecipe.app data)
xcrun simctl terminate "$qa_device" com.cnrecipe.app >/dev/null 2>&1 || true
folder="$container/Library/Application Support/CNrecipe"
restore(){
 container=$(xcrun simctl get_app_container "$qa_device" com.cnrecipe.app data)
 folder="$container/Library/Application Support/CNrecipe"
 xcrun simctl terminate "$qa_device" com.cnrecipe.app >/dev/null 2>&1 || true
 python3 - "$folder" "$out" <<'PY'
import sys,shutil,hashlib,json
from pathlib import Path
folder=Path(sys.argv[1]);out=Path(sys.argv[2]);backup=out/'original-data'
if folder.exists():shutil.move(str(folder),str(out/'tested-data'))
if backup.exists():shutil.copytree(backup,folder)
def hashes(p):return {str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in p.rglob('*') if x.is_file()}
a,b=hashes(backup),hashes(folder);(out/'restoration.json').write_text(json.dumps({'identical':a==b,'original':a,'restored':b},indent=2));assert a==b
PY
}
if [ -d "$folder" ]; then cp -R "$folder" "$out/original-data"; fi
trap restore EXIT
if [ -d "$folder" ]; then mv "$folder" "$out/isolated-original"; fi
xcrun simctl install "$qa_device" "$derived/Build/Products/Release-iphonesimulator/CNrecipe.app"
# Installation can relocate the data container; fixtures and restoration must use its current path.
container=$(xcrun simctl get_app_container "$qa_device" com.cnrecipe.app data)
folder="$container/Library/Application Support/CNrecipe"
python3 scripts/prepare-qa-dates.py > "$out/fixtures.log"
python3 - "$container" "$derived" "$out" <<'PY'
import sys,plistlib
from pathlib import Path
container,derived,out=sys.argv[1:];root=Path(derived,'Build/Products').resolve();source=next(root.glob('*.xctestrun'));d=plistlib.loads(source.read_bytes())
def expand(v):
 if isinstance(v,str):return v.replace('__TESTROOT__',str(root))
 if isinstance(v,list):return [expand(x) for x in v]
 if isinstance(v,dict):return {k:expand(x) for k,x in v.items()}
 return v
d=expand(d);ui=d['CNrecipeUITests'];ui.setdefault('EnvironmentVariables',{})['CNRECIPE_QA_CONTAINER']=container
ui['OnlyTestIdentifiers']=['NativeAcceptance','ReleaseReadinessUI'];ui['SkipTestIdentifiers']=['NativeAcceptance/test08OfflineTransportAndNativeHitAreas']
Path(out,'Release.xctestrun').write_bytes(plistlib.dumps(d))
PY
xcodebuild -xctestrun "$out/Release.xctestrun" -destination "platform=iOS Simulator,id=$qa_device" -parallel-testing-enabled NO -resultBundlePath "$out/native.xcresult" test-without-building "$@" > "$out/native.log" 2>&1
