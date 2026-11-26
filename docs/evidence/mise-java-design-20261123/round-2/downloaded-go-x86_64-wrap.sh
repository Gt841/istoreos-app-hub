#!/bin/sh
# Fixed runtime wrap contract. Generated preview; requires a manager-installed environment.
set -eu
store='/mnt/data/Configs/Runtime'
runtime='/mnt/data/Configs/Runtime/environments/go-1.26.10-x86_64-native'
if [ ! -d "$store" ] || [ ! -x "$runtime/bin/go" ]; then echo '运行环境未安装或磁盘未挂载，尚未创建 HOME。' >&2; exit 1; fi
uid="$(id -u)"
runtime_home="${ISTORE_RUNTIME_HOME:-$store/users/$uid/home}"
case "$runtime_home" in /mnt/*) ;; *) echo 'HOME 必须位于持久磁盘 /mnt 下' >&2; exit 1 ;; esac
case "$runtime_home" in */../*|*/..|*/./*|*/.) echo 'HOME 路径无效' >&2; exit 1 ;; esac
export HOME="$runtime_home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache" XDG_DATA_HOME="$HOME/.local/share"
export MISE_DATA_DIR="$store/mise/x86_64-native"
export MISE_CONFIG_DIR="$store/users/$uid/mise/x86_64-native/config" MISE_CACHE_DIR="$HOME/.cache/mise"
export ISTORE_RUNTIME_ID='go-1.26.10-x86_64-native'
export MISE_GO_VERSION='1.26.10'
export GOROOT="$runtime" GOTOOLCHAIN=local GOENV=off
export GOPATH="$HOME/.local/go/go-1.26.10-x86_64-native" GOBIN="$HOME/.local/go/go-1.26.10-x86_64-native/bin"
export GOCACHE="$HOME/.cache/go/go-1.26.10-x86_64-native/build" GOMODCACHE="$HOME/.cache/go/mod" GOTMPDIR="$HOME/.cache/go/go-1.26.10-x86_64-native/tmp"
export CGO_ENABLED="${CGO_ENABLED:-0}"
export PATH="$runtime/bin:$GOBIN:$PATH"
umask 077
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$MISE_CONFIG_DIR" "$MISE_CACHE_DIR"
mkdir -p "$GOPATH" "$GOBIN" "$GOCACHE" "$GOMODCACHE" "$GOTMPDIR"
command="${1:---shell}"
[ "$#" -eq 0 ] || shift
case "$command" in
 --shell) exec /bin/sh "$@" ;;
 go) exec "$runtime/bin/go" "$@" ;;
 gofmt) exec "$runtime/bin/gofmt" "$@" ;;
 *) echo '支持：go / gofmt / --shell' >&2; exit 2 ;;
esac
