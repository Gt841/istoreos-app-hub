#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${BUILD_CACHE_WORK_DIR:?Load the SSD build cache environment before building}"
cd "$app_dir/web"
npm run build:live
output="$BUILD_CACHE_WORK_DIR/mise-live-dist"
target="$app_dir/luci-app-mise/htdocs/luci-static/resources/mise"
mkdir -p "$target"
cp "$output/app.js" "$output/style.css" "$target/"
for file in "$output"/chunk-*.js; do
 [ ! -f "$file" ] || cp "$file" "$target/"
done
cp src/styles/quickstart/LICENSE "$target/LICENSE.quickstart"
cp node_modules/vue/LICENSE "$target/LICENSE.vue"
printf 'production_assets=%s\naudit=%s\n' "$target" "$output/modules.audit.json"
