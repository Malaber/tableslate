#!/usr/bin/env bash
set -euo pipefail

package_dir=$(cd "$(dirname "$0")/.." && pwd)
coverage_dir="$package_dir/coverage"
minimum_coverage=${TABLESLATE_COVERAGE_MINIMUM:-99}

mkdir -p "$coverage_dir" "$package_dir/.clang-module-cache"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$package_dir/.clang-module-cache}"

swift test \
  --package-path "$package_dir" \
  --disable-sandbox \
  --enable-code-coverage

profdata=$(find "$package_dir/.build" -name default.profdata -type f -print | sort | head -n 1)
binary=$(find "$package_dir/.build" -type f \( \
  -name 'TableSlateIOSPackageTests.xctest' -o \
  -path '*/TableSlateIOSPackageTests.xctest/Contents/MacOS/TableSlateIOSPackageTests' \
\) -print | sort | head -n 1)

if [[ -z "$profdata" || -z "$binary" ]]; then
  echo "Coverage artifacts were not produced" >&2
  exit 1
fi

llvm_cov=(llvm-cov)
if ! command -v llvm-cov >/dev/null 2>&1; then
  llvm_cov=(xcrun llvm-cov)
fi

"${llvm_cov[@]}" export \
  "$binary" \
  -instr-profile "$profdata" \
  -ignore-filename-regex='(/Tests/|/.build/)' \
  -summary-only \
  > "$coverage_dir/summary.json"

python3 "$package_dir/Scripts/coverage_gate.py" \
  "$coverage_dir/summary.json" \
  "$minimum_coverage" \
  | tee "$coverage_dir/summary.txt"
