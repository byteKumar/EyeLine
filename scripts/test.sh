#!/usr/bin/env bash
# Runs the unit tests. Uses `swift test` when SwiftPM works (Xcode, CI), otherwise compiles
# the tests directly with swiftc (for Command Line Tools installs with a broken SwiftPM).
set -euo pipefail
cd "$(dirname "$0")/.."

if swift test 2>/dev/null; then exit 0; fi
echo "swift test unavailable, compiling tests with swiftc"

CLT=/Library/Developer/CommandLineTools
W=.build/tests; rm -rf "$W"; mkdir -p "$W"
EXTRA=()
STALE=$CLT/usr/include/swift/module.modulemap
if [[ -f "$STALE" && -f "$CLT/usr/include/swift/bridging.modulemap" ]]; then
  : > "$W/empty.modulemap"
  echo "{ \"version\": 0, \"case-sensitive\": \"false\", \"roots\": [ { \"type\": \"file\", \"name\": \"$STALE\", \"external-contents\": \"$PWD/$W/empty.modulemap\" } ] }" > "$W/overlay.yaml"
  EXTRA=(-vfsoverlay "$W/overlay.yaml" -Xcc -ivfsoverlay -Xcc "$W/overlay.yaml")
fi

cat > "$W/main.swift" <<'EOF'
import Testing
@main struct Runner { static func main() async { await Testing.__swiftPMEntryPoint() as Never } }
EOF
sed 's/@testable import EyeLineCore//' Tests/EyeLineCoreTests/*.swift > "$W/tests.swift"
FW=$CLT/Library/Developer/Frameworks
swiftc ${EXTRA[@]+"${EXTRA[@]}"} -parse-as-library -F "$FW" -I "$FW" \
  -plugin-path "$CLT/usr/lib/swift/host/plugins/testing" -Xlinker -rpath -Xlinker "$FW" \
  Sources/EyeLineCore/*.swift "$W/tests.swift" "$W/main.swift" -o "$W/run"
"$W/run"
