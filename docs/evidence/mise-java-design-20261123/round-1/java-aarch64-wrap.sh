#!/bin/sh
# Fixed runtime wrap contract. Generated preview; requires a manager-installed environment.
set -eu
store='/mnt/data/Configs/Runtime'
runtime='/mnt/data/Configs/Runtime/environments/java-temurin-25.0.1+8-aarch64-glibc'
if [ ! -d "$store" ] || [ ! -x "$runtime/bin/java" ]; then echo '运行环境未安装或磁盘未挂载，尚未创建 HOME。' >&2; exit 1; fi
uid="$(id -u)"
runtime_home="${ISTORE_RUNTIME_HOME:-$store/users/$uid/home}"
case "$runtime_home" in /mnt/*) ;; *) echo 'HOME 必须位于持久磁盘 /mnt 下' >&2; exit 1 ;; esac
case "$runtime_home" in */../*|*/..|*/./*|*/.) echo 'HOME 路径无效' >&2; exit 1 ;; esac
export HOME="$runtime_home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache" XDG_DATA_HOME="$HOME/.local/share"
export MISE_DATA_DIR="$store/mise/aarch64-glibc"
export MISE_CONFIG_DIR="$store/users/$uid/mise/aarch64-glibc/config" MISE_CACHE_DIR="$HOME/.cache/mise"
export ISTORE_RUNTIME_ID='java-temurin-25.0.1+8-aarch64-glibc'
case "$HOME" in *'"'*) echo 'Java HOME 路径不能包含双引号' >&2; exit 1 ;; esac
export MISE_JAVA_VERSION='temurin-25.0.1+8'
export JAVA_HOME="$runtime" JDK_HOME="$runtime"
export TMPDIR="$HOME/.cache/java/java-temurin-25.0.1+8-aarch64-glibc/tmp"
# VM initialization options also reach javac/jar and shell child JVMs.
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Duser.home=\"$HOME\" -Djava.io.tmpdir=\"$TMPDIR\""
export PATH="$runtime/bin:$HOME/.local/bin:$PATH"
umask 077
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$MISE_CONFIG_DIR" "$MISE_CACHE_DIR"
mkdir -p "$TMPDIR"
command="${1:---shell}"
[ "$#" -eq 0 ] || shift
case "$command" in
 --shell) exec /bin/sh "$@" ;;
 java) exec "$runtime/bin/java" "$@" ;;
 javac) exec "$runtime/bin/javac" "$@" ;;
 jar) exec "$runtime/bin/jar" "$@" ;;
 *) echo '支持：java / javac / jar / --shell' >&2; exit 2 ;;
esac
