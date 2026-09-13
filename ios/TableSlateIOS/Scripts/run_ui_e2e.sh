#!/usr/bin/env bash
set -euo pipefail

package_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$package_dir/../.." && pwd)
device_name=${1:-"iPhone 17 Pro"}
artifact_dir=${2:-"e2e-artifacts/ios-iphone"}
if [[ "$artifact_dir" = /* ]]; then
  artifact_candidate="$artifact_dir"
else
  artifact_candidate="$repo_dir/$artifact_dir"
fi
artifact_path="$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve())' "$artifact_candidate")"
inventory="$artifact_path/simulators.json"
result_bundle="$artifact_path/TestResults.xcresult"
safe_device=$(printf '%s' "$device_name" | tr -cs '[:alnum:]' '-')
derived_data="$package_dir/.derived-e2e-$safe_device"

case "$artifact_path" in
  "$repo_dir/e2e-artifacts/"*) ;;
  *) echo "Artifact directory must be inside $repo_dir/e2e-artifacts" >&2; exit 2 ;;
esac
rm -rf "$artifact_path" "$derived_data"
mkdir -p "$artifact_path"
xcrun simctl list devices available -j > "$inventory"
device_udid=$(python3 "$package_dir/Scripts/resolve_simulator.py" "$inventory" "$device_name")

cd "$package_dir"
xcodegen generate
xcodebuild \
  -project TableSlateApp.xcodeproj \
  -scheme TableSlate \
  -destination "platform=iOS Simulator,id=$device_udid" \
  -destination-timeout 120 \
  -derivedDataPath "$derived_data" \
  -resultBundlePath "$result_bundle" \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:TableSlateUITests \
  CODE_SIGNING_ALLOWED=NO \
  test
