#!/bin/sh
# Fixed runtime wrap contract. Generated preview; requires a manager-installed environment.
set -eu
store='/mnt/data/Configs/Runtime'
runtime='/mnt/data/Configs/Runtime/environments/rust-1.90.0-x86_64-glibc'
if [ ! -d "$store" ] || [ ! -x "$runtime/bin/rustc" ]; then echo '运行环境未安装或磁盘未挂载，尚未创建 HOME。' >&2; exit 1; fi
uid="$(id -u)"
runtime_home="${ISTORE_RUNTIME_HOME:-$store/users/$uid/home}"
case "$runtime_home" in /mnt/*) ;; *) echo 'HOME 必须位于持久磁盘 /mnt 下' >&2; exit 1 ;; esac
case "$runtime_home" in */../*|*/..|*/./*|*/.) echo 'HOME 路径无效' >&2; exit 1 ;; esac
export HOME="$runtime_home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache" XDG_DATA_HOME="$HOME/.local/share"
export MISE_DATA_DIR="$store/mise/x86_64-glibc"
export MISE_CONFIG_DIR="$store/users/$uid/mise/x86_64-glibc/config" MISE_CACHE_DIR="$HOME/.cache/mise"
export ISTORE_RUNTIME_ID='rust-1.90.0-x86_64-glibc'
project_path="$(pwd -P)"
export MISE_RUST_VERSION='1.90.0'
export RUSTUP_HOME="$store/rustup/x86_64-glibc" RUSTUP_TOOLCHAIN='1.90.0-x86_64-unknown-linux-gnu' RUSTUP_AUTO_INSTALL=0
export CARGO_HOME="$HOME/.local/cargo/rust-1.90.0-x86_64-glibc"
export CARGO_TARGET_DIR="$HOME/.cache/cargo/rust-1.90.0-x86_64-glibc/target$project_path"
export RUSTC="$runtime/bin/rustc" RUSTDOC="$runtime/bin/rustdoc"
export TMPDIR="$HOME/.cache/cargo/rust-1.90.0-x86_64-glibc/tmp"
export PATH="$runtime/bin:$CARGO_HOME/bin:$PATH"
umask 077
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$MISE_CONFIG_DIR" "$MISE_CACHE_DIR"
mkdir -p "$CARGO_HOME" "$CARGO_TARGET_DIR" "$TMPDIR"
command="${1:---shell}"
[ "$#" -eq 0 ] || shift
case "$command" in
 --shell) exec /bin/sh "$@" ;;
 rustc) exec "$runtime/bin/rustc" "$@" ;;
 cargo) exec "$runtime/bin/cargo" "$@" ;;
 *) echo '支持：rustc / cargo / --shell' >&2; exit 2 ;;
esac
