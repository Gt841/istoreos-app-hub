#!/bin/sh
# Fixed runtime wrap contract. Generated preview; requires a manager-installed environment.
set -eu
store='/mnt/data/Configs/Runtime'
runtime='/mnt/data/Configs/Runtime/environments/node-24.22.1-x86_64-glibc'
if [ ! -d "$store" ] || [ ! -x "$runtime/bin/node" ]; then echo '运行环境未安装或磁盘未挂载，尚未创建 HOME。' >&2; exit 1; fi
uid="$(id -u)"
runtime_home="${ISTORE_RUNTIME_HOME:-$store/users/$uid/home}"
case "$runtime_home" in /mnt/*) ;; *) echo 'HOME 必须位于持久磁盘 /mnt 下' >&2; exit 1 ;; esac
case "$runtime_home" in */../*|*/..|*/./*|*/.) echo 'HOME 路径无效' >&2; exit 1 ;; esac
export HOME="$runtime_home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache" XDG_DATA_HOME="$HOME/.local/share"
export MISE_DATA_DIR="$store/mise/x86_64-glibc"
export MISE_CONFIG_DIR="$store/users/$uid/mise/x86_64-glibc/config" MISE_CACHE_DIR="$HOME/.cache/mise"
export ISTORE_RUNTIME_ID='node-24.22.1-x86_64-glibc'
export MISE_NODE_VERSION='24.22.1'
export npm_config_libc='glibc' npm_config_cache="$HOME/.cache/npm"
export npm_config_prefix="$HOME/.local/npm/node-24.22.1-x86_64-glibc"
export PATH="$runtime/bin:$npm_config_prefix/bin:$PATH"
umask 077
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$MISE_CONFIG_DIR" "$MISE_CACHE_DIR"
command="${1:---shell}"
[ "$#" -eq 0 ] || shift
case "$command" in
 --shell) exec /bin/sh "$@" ;;
 node) exec "$runtime/bin/node" "$@" ;;
 npm) exec "$runtime/bin/node" "$runtime/lib/node_modules/npm/bin/npm-cli.js" "$@" ;;
 *) echo '支持：node / npm / --shell' >&2; exit 2 ;;
esac
