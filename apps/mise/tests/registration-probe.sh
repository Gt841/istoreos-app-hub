#!/bin/sh
# Protocol fixture only: these are deliberately NOT real language SDKs.
set -eu
base="$1"; mise_bin="$2"
case "$base" in /mnt/*) ;; *) exit 2 ;; esac
[ ! -e "$base" ] || { echo 'probe directory already exists' >&2;exit 2; }
mkdir -p "$base/home" "$base/config" "$base/data" "$base/cache"
export HOME="$base/home" MISE_CONFIG_DIR="$base/config" MISE_DATA_DIR="$base/data" MISE_CACHE_DIR="$base/cache"
export MISE_PARANOID=1 MISE_YES=1 MISE_NOT_FOUND_AUTO_INSTALL=0 MISE_HIDE_UPDATE_WARNING=1
export MISE_HTTP_TIMEOUT=3 MISE_REMOTE_VERSION_CACHE=0 MISE_ENV=production
unset MISE_NODE_VERSION MISE_PYTHON_VERSION MISE_GO_VERSION MISE_RUST_VERSION MISE_ZIG_VERSION MISE_JAVA_VERSION
printf '# unchanged test global configuration\n' > "$MISE_CONFIG_DIR/config.toml"
before="$(sha256sum "$MISE_CONFIG_DIR/config.toml")"
cd "$base"
for tool in node python go rust zig java; do
 case "$tool" in node) binary=node;;python) binary=python3;;go) binary=go;;rust) binary=rustc;;zig) binary=zig;;java) binary=java;;esac
 for revision in one two; do
  sdk="$base/sdk-$tool-$revision"
  mkdir -p "$sdk/bin"
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$tool:$revision" > "$sdk/bin/$binary"
  chmod 755 "$sdk/bin/$binary"
  registry="$tool"
  [ "$tool" != rust ] || registry=http:istore-rust
  "$mise_bin" link "$registry@istore-probe-$revision" "$sdk"
  actual="$("$mise_bin" where "$registry@istore-probe-$revision")"
  [ "$(readlink -f "$actual")" = "$sdk" ]
  result="$("$mise_bin" exec "$registry@istore-probe-$revision" -- "$binary" --version)"
  [ "$result" = "$tool:$revision" ]
  printf 'passed tool=%s revision=%s location=%s output=%s\n' "$tool" "$revision" "$actual" "$result"
 done
done
[ "$before" = "$(sha256sum "$MISE_CONFIG_DIR/config.toml")" ]
printf 'default-config-unchanged=yes\n'
