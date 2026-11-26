#!/bin/sh
# Fixed runtime wrap contract. Generated preview; requires a manager-installed environment.
set -eu
store='/mnt/data/Configs/Runtime'
runtime='/mnt/data/Configs/Runtime/environments/zig-0.15.2-aarch64-native'
if [ ! -d "$store" ] || [ ! -x "$runtime/bin/zig" ]; then echo '运行环境未安装或磁盘未挂载，尚未创建 HOME。' >&2; exit 1; fi
uid="$(id -u)"
runtime_home="${ISTORE_RUNTIME_HOME:-$store/users/$uid/home}"
case "$runtime_home" in /mnt/*) ;; *) echo 'HOME 必须位于持久磁盘 /mnt 下' >&2; exit 1 ;; esac
case "$runtime_home" in */../*|*/..|*/./*|*/.) echo 'HOME 路径无效' >&2; exit 1 ;; esac
export HOME="$runtime_home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache" XDG_DATA_HOME="$HOME/.local/share"
export MISE_DATA_DIR="$store/mise/aarch64-native"
export MISE_CONFIG_DIR="$store/users/$uid/mise/aarch64-native/config" MISE_CACHE_DIR="$HOME/.cache/mise"
export ISTORE_RUNTIME_ID='zig-0.15.2-aarch64-native'
project_path="$(pwd -P)"
export MISE_ZIG_VERSION='0.15.2'
export ZIG_LIB_DIR="$runtime/lib"
export ZIG_GLOBAL_CACHE_DIR="$HOME/.cache/zig/zig-0.15.2-aarch64-native/global"
export ZIG_LOCAL_CACHE_DIR="$HOME/.cache/zig/zig-0.15.2-aarch64-native/local$project_path"
export TMPDIR="$HOME/.cache/zig/zig-0.15.2-aarch64-native/tmp"
export PATH="$runtime/bin:$HOME/.local/bin:$PATH"
umask 077
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$MISE_CONFIG_DIR" "$MISE_CACHE_DIR"
mkdir -p "$ZIG_GLOBAL_CACHE_DIR" "$ZIG_LOCAL_CACHE_DIR" "$TMPDIR"
command="${1:---shell}"
[ "$#" -eq 0 ] || shift
case "$command" in
 --shell) exec /bin/sh "$@" ;;
 zig) exec "$runtime/bin/zig" "$@" ;;
 *) echo '支持：zig / --shell' >&2; exit 2 ;;
esac
