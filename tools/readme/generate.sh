#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
# Reuse the production widget view without the WidgetBundle entry point or preview macro.
python3 - "$work_dir/WidgetView.swift" <<'PY'
from pathlib import Path
import sys
source = Path('yoUsageWidget/yoUsageWidget.swift').read_text()
view = source.split('struct YoUsageWidgetView: View {', 1)[1].split('#Preview', 1)[0]
Path(sys.argv[1]).write_text('import SwiftUI\nimport WidgetKit\nstruct UsageEntry: TimelineEntry { let date: Date; let usage: AccountUsage?; var preferences = UsageDisplayPreferences() }\nstruct YoUsageWidgetView: View {' + view)
PY
xcrun swiftc -swift-version 6 -parse-as-library -o "$work_dir/render" \
  Shared/Models/*.swift Shared/Storage/*.swift Shared/Views/*.swift yoUsageCLI/Formatting.swift \
  yoUsage/Providers/*.swift yoUsage/UsageManager.swift \
  yoUsage/Views/UsagePopoverView.swift yoUsage/Views/AccountCardView.swift \
  yoUsage/Views/MenuBarGauge.swift "$work_dir/WidgetView.swift" tools/readme/render.swift
"$work_dir/render" "$PWD/docs/assets"
