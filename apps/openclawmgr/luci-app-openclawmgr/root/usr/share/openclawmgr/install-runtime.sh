# Sourced by openclawmgr.sh. All mutating children belong to one coordinator.
OC_SHARE=/usr/share/openclawmgr
OC_GLIBC_SOURCE=/usr/share/openclawmgr-glibc
. "$OC_SHARE/node-pins.sh"
. "$OC_SHARE/npm-env.sh"
OC_CHILD='' OC_SPAWNING=0 OC_SIGNAL=0 OC_TXN='' OC_COMMITTED=0
OC_ACTIVATING=0 OC_OLD_CURRENT='' OC_OLD_PREVIOUS='' OC_LEGACY='' OC_RELEASE=''
OC_WAS_RUNNING=0 OC_BACKUP_READY=0 OC_NODE_URL='' OC_NODE_SHA256=''
OC_DOWNLOAD_PART='' OC_LOG_FILE=''

oc_signal() {
	OC_SIGNAL="$1"
	[ "$OC_SPAWNING" = 1 ] || exit "$OC_SIGNAL"
}

oc_join_child() {
	[ -n "$OC_CHILD" ] || return 0
	local n=0
	kill -TERM "-$OC_CHILD" 2>/dev/null || kill -TERM "$OC_CHILD" 2>/dev/null || true
	while kill -0 "-$OC_CHILD" 2>/dev/null && [ "$n" -lt 10 ]; do sleep 1; n=$((n + 1)); done
	kill -KILL "-$OC_CHILD" 2>/dev/null || true
	wait "$OC_CHILD" 2>/dev/null || true
	OC_CHILD=
}

oc_run() {
	local rc=0
	OC_SPAWNING=1
	setsid timeout -k 10 900 "$@" &
	OC_CHILD=$!
	OC_SPAWNING=0
	[ "$OC_SIGNAL" = 0 ] || exit "$OC_SIGNAL"
	wait "$OC_CHILD" || rc=$?
	# A wrapper can crash before its native child exits. Join the remaining
	# owned process group before releasing its transaction and files.
	if kill -0 "-$OC_CHILD" 2>/dev/null; then oc_join_child; else OC_CHILD=; fi
	return "$rc"
}

oc_npm() {
	if [ "$INSTALL_ACCELERATED" = 1 ]; then set -- ks-cli npm "$@"; else set -- "$NPM_BIN" "$@"; fi
	oc_run env HOME="$OC_TXN/npm-home" PATH="${NODE_DIR}/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
		OPENCLAWMGR_ACCELERATED="$INSTALL_ACCELERATED" npm_config_git="$OC_SHARE/npm-git.sh" \
		npm_config_cache="$BASE_DIR/npm-cache" npm_config_registry=https://registry.npmjs.org \
		npm_config_audit=false npm_config_fund=false npm_config_progress=false \
		npm_config_update_notifier=false npm_config_ignore_scripts=false npm_config_umask=0022 "$@"
}

download() {
	local url="$1" out="$2" rc=0 work
	# Native downloaders may create sidecars (ks-cli uses .syn). Keep all
	# partial files inside the transaction so cancellation removes them too.
	work="$(mktemp -d "$OC_TXN/download.XXXXXX")" || return 1
	OC_DOWNLOAD_PART="$work/payload"
	write_installer_log "Downloading: $url"
	if [ "$INSTALL_ACCELERATED" = 1 ]; then
		local ap
		ap="$(uci -q get 'istoreenhance.@istoreenhance[0].adminport' 2>/dev/null || echo 5003)"
		case "$ap" in ''|*[!0-9]*) return 2 ;; esac
		oc_run ks-cli download --mode auto --admin-url "http://127.0.0.1:$ap" \
			--timeout 600s --progress plain -O "$OC_DOWNLOAD_PART" "$url" || rc=$?
	else
		oc_run curl -fSL --proto '=https' --proto-redir '=https' --retry 2 \
			--connect-timeout 15 --max-time 600 -o "$OC_DOWNLOAD_PART" "$url" || rc=$?
	fi
	if [ "$rc" -ne 0 ]; then rm -rf "$work"; OC_DOWNLOAD_PART=; return "$rc"; fi
	mv -f "$OC_DOWNLOAD_PART" "$out" || return 1
	rm -rf "$work"
	OC_DOWNLOAD_PART=
}

oc_check() { oc_run "$NODE_BIN" "$OC_SHARE/runtime-check.cjs" "$@"; }

oc_pointer_valid() {
	case "$1" in releases/*) ;; *) return 1 ;; esac
	local name="${1#releases/}"
	case "$name" in ''|.*|*[!a-zA-Z0-9._-]*) return 1 ;; esac
	[ -d "$BASE_DIR/$1" ] && [ ! -L "$BASE_DIR/$1" ]
}

oc_switch() {
	local name="$1" target="$2"
	[ ! -e "$BASE_DIR/.$name.$$" ] && [ ! -L "$BASE_DIR/.$name.$$" ] || return 2
	ln -s "$target" "$BASE_DIR/.$name.$$" || return 1
	# -T is supported by OpenWrt's BusyBox mv; do not follow a directory symlink.
	mv -Tf "$BASE_DIR/.$name.$$" "$BASE_DIR/$name"
}

oc_phase() {
	printf '%s\n' "$1" > "$OC_TXN/phase.new" && mv -f "$OC_TXN/phase.new" "$OC_TXN/phase" || return 1
	write_installer_log "Installation phase: $1"
}

oc_log_open() {
	[ ! -L "$BASE_DIR/log" ] && [ ! -L "$BASE_DIR/log/installer.log" ] || return 1
	mkdir -p "$BASE_DIR/log" && chmod 700 "$BASE_DIR/log" || return 1
	OC_LOG_FILE="$BASE_DIR/log/installer.log"
	touch "$OC_LOG_FILE" && chmod 600 "$OC_LOG_FILE"
}

oc_preflight() {
	local resolved fs_type free_inodes total_inodes inode_info data_kb=0
	for command in curl sha256sum tar xz readlink setsid timeout stat; do
		command -v "$command" >/dev/null 2>&1 || { write_installer_log "Required command missing: $command"; return 1; }
	done
	if [ "$INSTALL_ACCELERATED" = 1 ]; then
		command -v ks-cli >/dev/null 2>&1 || { write_installer_log "Install the OpenWrt ks-cli package, or disable accelerated installation"; return 1; }
		[ "$(uci -q get 'istoreenhance.@istoreenhance[0].enabled' 2>/dev/null || echo 0)" = 1 ] || {
			write_installer_log "KSpeeder is disabled/missing; enable iStore enhancement or disable accelerated installation"; return 1;
		}
	fi
	mkdir -p "$BASE_DIR" || return 1
	resolved="$(readlink -f "$BASE_DIR")" || return 1
	validate_base_dir "$resolved" || return 1
	[ "$resolved" = "$BASE_DIR" ] || { write_installer_log "Use the resolved installation directory: $resolved"; return 1; }
	fs_type="$(df -P "$BASE_DIR" | awk 'NR==2{print $1}')"
	case "$fs_type" in tmpfs|ramfs) write_installer_log "Installation requires persistent storage"; return 1 ;; esac
	[ ! -d "$DATA_DIR" ] || data_kb="$(du -sk "$DATA_DIR" | awk '{print $1}')"
	check_space_mb "$BASE_DIR" "$((2048 + (data_kb + 1023) / 1024))" || return 1
	# OpenWrt commonly compiles BusyBox df without -i; coreutils-stat is
	# already used by storage tools and exposes the same statfs counters.
	inode_info="$(stat -f -c '%c %d' "$BASE_DIR")" || return 1
	read -r total_inodes free_inodes <<OC_INODES
$inode_info
OC_INODES
	case "$total_inodes:$free_inodes" in :*|*:|*[!0-9:]*) write_installer_log "Cannot inspect free inodes"; return 1 ;; esac
	[ "$total_inodes" = 0 ] || [ "$free_inodes" -ge 30000 ] || { write_installer_log "Need at least 30000 free inodes"; return 1; }
	case "$(uname -m)" in x86_64) OC_ARCH=x64 ;; aarch64) OC_ARCH=arm64 ;; *) write_installer_log "Unsupported architecture"; return 1 ;; esac
	# Node and native addons use our glibc runtime on both musl and glibc hosts.
	oc_glibc_check "$OC_GLIBC_SOURCE" || { write_installer_log "Missing/invalid private glibc runtime; install openclawmgr-glibc"; return 1; }
	for name in releases backups npm-cache data; do [ ! -L "$BASE_DIR/$name" ] || return 1; done
	for name in current previous; do
		if [ -e "$BASE_DIR/$name" ] || [ -L "$BASE_DIR/$name" ]; then
			[ -L "$BASE_DIR/$name" ] && oc_pointer_valid "$(readlink "$BASE_DIR/$name")" || return 1
		fi
	done
	for name in node global; do
		[ ! -L "$BASE_DIR/$name" ] || [ "$(readlink "$BASE_DIR/$name")" = "current/$name" ] || return 1
		if [ -L "$BASE_DIR/current" ]; then [ -L "$BASE_DIR/$name" ] || return 1; fi
	done
	mkdir -p "$BASE_DIR/releases" "$BASE_DIR/backups" "$BASE_DIR/npm-cache"
	chmod 700 "$BASE_DIR/backups" "$BASE_DIR/npm-cache" || return 1
}

oc_glibc_check() {
	[ -x "$1/ld.so" ] && [ -f "$1/SHA256SUMS" ] || return 1
	(cd "$1" && sha256sum -c SHA256SUMS) >/dev/null 2>&1
}

oc_node_launcher() {
	[ -f "$NODE_DIR/bin/node.real" ] || mv "$NODE_BIN" "$NODE_DIR/bin/node.real" || return 1
	cp "$OC_SHARE/glibc-node.sh" "$NODE_BIN" || return 1
	cp "$OC_SHARE/node-loader.cjs" "$NODE_DIR/node-loader.cjs" || return 1
	chmod 755 "$NODE_BIN" || return 1
	printf '%s\n' 1 > "$NODE_DIR/.openclawmgr-glibc"
}

install_node() {
	local archive old_node="$NODE_DIR"
	NODE_DIR="$OC_TXN/candidate/node"; NODE_BIN="$NODE_DIR/bin/node"; NPM_BIN="$NODE_DIR/bin/npm"
	if [ "${1:-}" = pinned ]; then rm -rf "$NODE_DIR"; fi
	mkdir -p "$NODE_DIR"
	# Reuse only a self-contained managed glibc runtime, never a system or
	# previous musl Node. Each release owns its loader/libraries for rollback.
	if [ "${1:-}" != pinned ] && [ -f "$old_node/.openclawmgr-glibc" ] &&
		oc_glibc_check "$old_node/glibc" &&
		timeout -k 5 30 "$old_node/bin/node" "$OC_SHARE/runtime-check.cjs" node "$OC_ARCH" glibc >/dev/null 2>&1; then
		oc_run cp -a "$old_node/." "$NODE_DIR/" || return $?
		oc_run chown -hR "$(id -u):$(id -g)" "$NODE_DIR" || return $?
		# A runtime-package update must reach the candidate even if the Node
		# executable is reusable. Previous releases keep their own old libraries.
		rm -rf "$NODE_DIR/glibc"
		mkdir -p "$NODE_DIR/glibc" || return 1
		oc_run cp -a "$OC_GLIBC_SOURCE/." "$NODE_DIR/glibc/" || return $?
		oc_node_launcher || return 1
		OC_NODE_URL="reused:$old_node"; OC_NODE_SHA256=
		oc_check node "$OC_ARCH" glibc || return $?
		oc_run env PATH="$NODE_DIR/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$NPM_BIN" --version
		return $?
	fi
	oc_node_pin "$OC_ARCH" glibc || return 1
	archive="$BASE_DIR/npm-cache/node-${NODE_VERSION}-${OC_ARCH}-glibc.tar.xz"
	if ! printf '%s  %s\n' "$OC_NODE_SHA256" "$archive" | sha256sum -c - >/dev/null 2>&1; then
		rm -f "$archive"
		download "$OC_NODE_URL" "$archive" || return $?
	fi
	printf '%s  %s\n' "$OC_NODE_SHA256" "$archive" | sha256sum -c - || return 1
	oc_run xz -t "$archive" || return $?
	oc_run tar -xJf "$archive" -C "$NODE_DIR" --strip-components=1 --no-same-owner || return $?
	mkdir -p "$NODE_DIR/glibc" || return 1
	oc_run cp -a "$OC_GLIBC_SOURCE/." "$NODE_DIR/glibc/" || return $?
	oc_node_launcher || return 1
	oc_check node "$OC_ARCH" glibc || return $?
	oc_run env PATH="$NODE_DIR/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$NPM_BIN" --version
}

install_openclaw() {
	local version tarball npm_version script_flag rc
	oc_npm view "$(target_openclaw_package)" --json > "$OC_TXN/metadata.json" || return $?
	if oc_check metadata "$OC_TXN/metadata.json" "$NPM_BIN" "$OC_TXN/resolved.json" > "$OC_TXN/version"; then :
	else
		rc=$?
		case "$rc:$OC_NODE_URL" in
			61:reused:*)
				write_installer_log "Existing Node does not satisfy target engines; trying the pinned runtime"
				install_node pinned || return $?
				oc_check metadata "$OC_TXN/metadata.json" "$NPM_BIN" "$OC_TXN/resolved.json" > "$OC_TXN/version" || return $?
				;;
			*) return "$rc" ;;
		esac
	fi
	version="$(cat "$OC_TXN/version")"
	write_installer_log "Resolved OpenClaw $version with Node $("$NODE_BIN" --version)"
	write_installer_log "Fetching package archive and verifying SHA512"
	oc_npm pack "openclaw@$version" --ignore-scripts --json --pack-destination "$OC_TXN" > "$OC_TXN/pack.json" || return $?
	oc_check pack "$OC_TXN/resolved.json" "$OC_TXN/pack.json" "$OC_TXN" > "$OC_TXN/tarball" || return $?
	tarball="$(cat "$OC_TXN/tarball")"
	oc_run env PATH="$NODE_DIR/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$NPM_BIN" --version > "$OC_TXN/npm-version" || return $?
	npm_version="$(cat "$OC_TXN/npm-version")"
	oc_check scripts "$npm_version" "$NPM_BIN" > "$OC_TXN/script-flag" || return $?
	script_flag="$(cat "$OC_TXN/script-flag")"
	GLOBAL_DIR="$OC_TXN/candidate/global"
	mkdir -p "$GLOBAL_DIR" "$OC_TXN/smoke-home"
	# Optional dependencies retain npm's platform selection; required native
	# dependencies are checked below. No blanket --ignore-scripts on musl.
	write_installer_log "Installing OpenClaw $version and dependencies"
	oc_npm install -g "$tarball" --prefix="$GLOBAL_DIR" ${script_flag:+"$script_flag"} \
		--no-audit --no-fund --no-progress --foreground-scripts --loglevel=http --prefer-offline || return $?
	write_installer_log "Checking native modules and required sqlite-vec vector queries"
	oc_check native "$GLOBAL_DIR" "$OC_TXN/resolved.json" > "$OC_TXN/native.json" || return $?
	if [ "$(jsonfilter -i "$OC_TXN/native.json" -e '@.nodePty.available' 2>/dev/null || true)" = false ]; then
		write_installer_log "node-pty unavailable; ordinary child process fallback verified; interactive PTY unavailable (see receipt)"
	fi
	write_installer_log "Checking the candidate CLI in an isolated home"
	local entry actual
	entry="$(find_entry)" || return 1
	oc_run env HOME="$OC_TXN/smoke-home" OPENCLAW_HOME="$OC_TXN/smoke-home" \
		OPENCLAW_STATE_DIR="$OC_TXN/smoke-home/.openclaw" OPENCLAW_CONFIG_PATH="$OC_TXN/smoke-home/.openclaw/openclaw.json" \
		PATH="$NODE_DIR/bin:$GLOBAL_DIR/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$NODE_BIN" "$entry" --version > "$OC_TXN/cli-version" || return $?
	actual="$(cat "$OC_TXN/cli-version")"
	case "$actual" in *"$version"*) ;; *) write_installer_log "CLI version verification failed: $actual"; return 1 ;; esac
	oc_check receipt "$OC_TXN/resolved.json" "$npm_version" "$INSTALL_CHANNEL" \
		"$([ "$INSTALL_ACCELERATED" = 1 ] && echo ks-cli || echo origin)" "$OC_NODE_URL" "$OC_NODE_SHA256" \
		"$OC_TXN/candidate/receipt.json" "$OC_TXN/native.json"
}

oc_health() {
	local n=0
	# Cold OpenClaw CLI imports on ARM can exceed ten seconds even while the
	# Gateway is already listening. Allow CLI startup within each bounded try.
	while [ "$n" -lt 3 ]; do
		if oc_run env HOME="$DATA_DIR" OPENCLAW_HOME="$DATA_DIR" OPENCLAW_STATE_DIR="$DATA_DIR/.openclaw" \
			OPENCLAW_CONFIG_PATH="$DATA_DIR/.openclaw/openclaw.json" PATH="$NODE_DIR/bin:$GLOBAL_DIR/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
			timeout -k 2 60 "$NODE_BIN" "$(find_entry)" gateway health \
			--url "ws://127.0.0.1:$PORT" --token "$TOKEN"; then return 0; fi
		n=$((n + 1)); sleep 2
	done
	write_installer_log "Gateway health check failed"
	return 1
}

oc_restore() {
	[ "$OC_ACTIVATING" = 1 ] || return 0
	# A reboot/storage failure can leave a journal beside an incomplete tar.
	# Refuse it before stopping a live service or moving the current data.
	if [ "$OC_BACKUP_READY" = 1 ] && [ ! -f "$OC_TXN/data-restored" ]; then
		if ! oc_run tar -tf "$BASE_DIR/backups/$OC_RELEASE/data.tar" >/dev/null; then
			write_installer_log "Data snapshot is missing or invalid; preserving runtime, data and journal for manual recovery"
			return 1
		fi
	fi
	write_installer_log "Restoring previous runtime and data snapshot"
	oc_run /etc/init.d/openclawmgr stop || return 1
	oc_wait_stopped || return 1
	if [ -n "$OC_OLD_CURRENT" ]; then oc_switch current "$OC_OLD_CURRENT" || return 1
	else
		rm -f "$BASE_DIR/current"
		if [ -n "$OC_LEGACY" ]; then
			for name in node global; do
				if [ -L "$BASE_DIR/$name" ]; then
					[ "$(readlink "$BASE_DIR/$name")" = "current/$name" ] || return 1
					rm "$BASE_DIR/$name" || return 1
				fi
				if [ -e "$BASE_DIR/$OC_LEGACY/$name" ]; then
					[ ! -e "$BASE_DIR/$name" ] || return 1
					mv "$BASE_DIR/$OC_LEGACY/$name" "$BASE_DIR/$name" || return 1
				fi
			done
		fi
	fi
	if [ -n "$OC_OLD_PREVIOUS" ]; then oc_switch previous "$OC_OLD_PREVIOUS" || return 1; else rm -f "$BASE_DIR/previous"; fi
	if [ "$OC_BACKUP_READY" = 1 ] && [ ! -f "$OC_TXN/data-restored" ]; then
		local backup="$BASE_DIR/backups/$OC_RELEASE"
		# This marker makes restoration repeatable after a second interruption.
		if [ -e "$backup/failed-data" ]; then [ -f "$OC_TXN/restoring-data" ] || return 1
		else
			printf '%s\n' restoring > "$OC_TXN/restoring-data" || return 1
			[ ! -e "$DATA_DIR" ] || mv "$DATA_DIR" "$backup/failed-data" || return 1
		fi
		mkdir -p "$DATA_DIR" || return 1
		oc_run tar -xf "$backup/data.tar" -C "$DATA_DIR" || return 1
		printf '%s\n' restored > "$OC_TXN/data-restored" || return 1
	fi
	NODE_DIR="$BASE_DIR/node"; NODE_BIN="$NODE_DIR/bin/node"; NPM_BIN="$NODE_DIR/bin/npm"; GLOBAL_DIR="$BASE_DIR/global"
	[ "$OC_WAS_RUNNING" != 1 ] || oc_run env OPENCLAWMGR_FORCE_START=1 /etc/init.d/openclawmgr start || return 1
	[ "$OC_WAS_RUNNING" != 1 ] || oc_health || return 1
	oc_phase restored
}

oc_wait_stopped() {
	local n=0
	while [ "$(do_status)" = running ] && [ "$n" -lt 15 ]; do sleep 1; n=$((n + 1)); done
	[ "$(do_status)" != running ] || { write_installer_log "Service did not stop; refusing to snapshot live data"; return 1; }
}

oc_exit() {
	local rc="$1"
	trap - EXIT
	trap '' HUP INT TERM
	oc_join_child
	[ -z "$OC_DOWNLOAD_PART" ] || rm -f "$OC_DOWNLOAD_PART"
	# The durable commit marker is authoritative even if a signal arrived
	# immediately before the in-memory flag was assigned.
	if [ -n "$OC_TXN" ] && [ "$(cat "$OC_TXN/phase" 2>/dev/null || true)" = committed ]; then OC_COMMITTED=1; fi
	if [ "$OC_COMMITTED" != 1 ] && ! oc_restore; then
		write_installer_log "Recovery incomplete; journal retained: $OC_TXN. Run recover_install before retrying."
		exit 1
	fi
	if [ "$OC_COMMITTED" != 1 ] && [ -n "$OC_RELEASE" ]; then
		case "$OC_RELEASE" in *[!a-zA-Z0-9._-]*|.*) exit 1 ;; esac
		[ "$(readlink "$BASE_DIR/current" 2>/dev/null || true)" != "releases/$OC_RELEASE" ] || exit 1
		[ "$(readlink "$BASE_DIR/previous" 2>/dev/null || true)" != "releases/$OC_RELEASE" ] || exit 1
		rm -rf "$BASE_DIR/releases/$OC_RELEASE"
		[ -z "$OC_LEGACY" ] || rmdir "$BASE_DIR/$OC_LEGACY" 2>/dev/null || true
	fi
	[ -z "$OC_TXN" ] || rm -rf "$OC_TXN"
	write_installer_log "Installation finished (exit=$rc)"
	rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR" 2>/dev/null || true
	exit "$rc"
}

do_install() {
	acquire_lock
	trap 'oc_exit $?' EXIT
	trap 'oc_signal 129' HUP
	trap 'oc_signal 130' INT
	trap 'oc_signal 143' TERM
	for old in "$BASE_DIR"/.install.*; do
		[ ! -d "$old" ] || { write_installer_log "Interrupted transaction: $old; run recover_install first"; return 1; }
	done
	if [ "$ACTION" = install ] && have_openclaw_runtime; then
		write_installer_log "OpenClaw is already installed; use upgrade to replace the runtime"
		return 0
	fi
	oc_npm_environment
	oc_preflight || return $?
	oc_log_open || return 1
	OC_TXN="$(mktemp -d "$BASE_DIR/.install.XXXXXX")" || return 1
	chmod 700 "$OC_TXN"
	OC_RELEASE="$(date +%Y%m%d%H%M%S)-${OC_TXN##*.}"
	mkdir -p "$OC_TXN/candidate" "$OC_TXN/npm-home"
	chmod 700 "$OC_TXN/npm-home"
	OC_OLD_CURRENT="$(readlink "$BASE_DIR/current" 2>/dev/null || true)"
	OC_OLD_PREVIOUS="$(readlink "$BASE_DIR/previous" 2>/dev/null || true)"
	[ -n "$OC_OLD_CURRENT" ] || OC_LEGACY="releases/legacy-$OC_RELEASE"
	[ "$(do_status)" != running ] || OC_WAS_RUNNING=1
	printf '%s\n' "$OC_RELEASE" > "$OC_TXN/release"
	printf '%s\n' "$OC_OLD_CURRENT" > "$OC_TXN/old-current"
	printf '%s\n' "$OC_OLD_PREVIOUS" > "$OC_TXN/old-previous"
	printf '%s\n' "$OC_LEGACY" > "$OC_TXN/legacy"
	printf '%s\n' "$OC_WAS_RUNNING" > "$OC_TXN/was-running"
	oc_phase preparing || return 1
	install_node || return $?
	install_openclaw || return $?
	NODE_DIR="$BASE_DIR/node"; NODE_BIN="$NODE_DIR/bin/node"; NPM_BIN="$NODE_DIR/bin/npm"; GLOBAL_DIR="$BASE_DIR/global"
	# Journal is written before any live mutation, including service stop.
	oc_phase stopping || return 1
	OC_ACTIVATING=1
	oc_run /etc/init.d/openclawmgr stop || return $?
	oc_wait_stopped || return 1
	mkdir -p "$DATA_DIR" "$BASE_DIR/backups/$OC_RELEASE"
	chmod 700 "$BASE_DIR/backups/$OC_RELEASE"
	oc_run tar -cf "$BASE_DIR/backups/$OC_RELEASE/data.tar.part" -C "$DATA_DIR" . || return $?
	mv "$BASE_DIR/backups/$OC_RELEASE/data.tar.part" "$BASE_DIR/backups/$OC_RELEASE/data.tar" || return 1
	oc_phase backup-ready || return 1
	OC_BACKUP_READY=1
	if [ -n "$OC_LEGACY" ]; then
		mkdir -p "$BASE_DIR/$OC_LEGACY"
		for name in node global; do
			if [ -d "$BASE_DIR/$name" ] && [ ! -L "$BASE_DIR/$name" ]; then mv "$BASE_DIR/$name" "$BASE_DIR/$OC_LEGACY/$name" || return 1; fi
		done
	fi
	for name in node global; do
		[ -L "$BASE_DIR/$name" ] || ln -s "current/$name" "$BASE_DIR/$name" || return 1
	done
	mv "$OC_TXN/candidate" "$BASE_DIR/releases/$OC_RELEASE" || return 1
	oc_switch current "releases/$OC_RELEASE" || return 1
	oc_phase activated || return 1
	chmod 700 "$DATA_DIR" || return 1
	ensure_token
	ensure_gateway_config || return 1
	fix_data_permissions || return 1
	if [ "$OC_WAS_RUNNING" = 1 ] || [ "$ENABLED" = 1 ]; then
		ensure_safe_port_for_start || return 1
		if [ "$ENABLED" = 1 ]; then oc_run /etc/init.d/openclawmgr enable || return $?; fi
		oc_run env OPENCLAWMGR_FORCE_START=1 /etc/init.d/openclawmgr start || return $?
		oc_health || return 1
	fi
	local previous="$OC_OLD_CURRENT"
	[ -n "$previous" ] || previous="$OC_LEGACY"
	if [ -n "$previous" ]; then oc_switch previous "$previous" || return 1; fi
	printf '%s\n' managed-by=openclawmgr > "$BASE_DIR/.openclawmgr.managed"
	oc_phase committed || return 1
	OC_COMMITTED=1
	write_installer_log "Installation committed: $OC_RELEASE; receipt: $BASE_DIR/current/receipt.json"
}

oc_remove_runtime() {
	for journal in "$BASE_DIR"/.install.*; do
		[ ! -d "$journal" ] || { write_installer_log "Recover interrupted installation before removing runtime"; return 1; }
	done
	for name in current previous; do
		if [ -L "$BASE_DIR/$name" ]; then oc_pointer_valid "$(readlink "$BASE_DIR/$name")" || return 1; fi
	done
	[ ! -L "$BASE_DIR/releases" ] || return 1
	rm -rf "$BASE_DIR/node" "$BASE_DIR/global" "$BASE_DIR/current" "$BASE_DIR/previous" "$BASE_DIR/releases"
}

do_cancel_install() {
	local pid n=0 cmdline
	pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
	case "$pid" in ''|*[!0-9]*) return 1 ;; esac
	[ "$pid" -gt 1 ] && [ "$pid" != "$$" ] || return 1
	cmdline="$(tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
	case "$cmdline" in *openclawmgr.sh*install*|*openclawmgr.sh*upgrade*) ;; *) return 1 ;; esac
	kill -TERM "$pid" || return 1
	while [ -d "$LOCK_DIR" ] && [ "$n" -lt 30 ]; do sleep 1; n=$((n + 1)); done
	[ ! -d "$LOCK_DIR" ] || { write_installer_log "Cancellation/recovery still pending; lock retained"; return 1; }
}

do_recover_install() {
	acquire_lock
	local txn phase count=0
	[ "$(readlink -f "$BASE_DIR")" = "$BASE_DIR" ] || return 1
	for name in releases backups data; do [ ! -L "$BASE_DIR/$name" ] || return 1; done
	oc_log_open || return 1
	for txn in "$BASE_DIR"/.install.*; do
		[ -d "$txn" ] || continue
		[ ! -L "$txn" ] || return 1
		count=$((count + 1)); OC_TXN="$txn"
	done
	[ "$count" = 1 ] || { write_installer_log "Expected exactly one interrupted journal"; return 1; }
	phase="$(cat "$OC_TXN/phase")" || return 1
	OC_RELEASE="$(cat "$OC_TXN/release")" || return 1
	case "$OC_RELEASE" in ''|.*|*[!a-zA-Z0-9._-]*) return 1 ;; esac
	OC_OLD_CURRENT="$(cat "$OC_TXN/old-current")"; OC_OLD_PREVIOUS="$(cat "$OC_TXN/old-previous")"
	OC_LEGACY="$(cat "$OC_TXN/legacy")"; OC_WAS_RUNNING="$(cat "$OC_TXN/was-running")"
	[ -z "$OC_OLD_CURRENT" ] || oc_pointer_valid "$OC_OLD_CURRENT" || return 1
	[ -z "$OC_OLD_PREVIOUS" ] || oc_pointer_valid "$OC_OLD_PREVIOUS" || return 1
	[ -z "$OC_LEGACY" ] || [ "$OC_LEGACY" = "releases/legacy-$OC_RELEASE" ] || return 1
	case "$OC_WAS_RUNNING" in 0|1) ;; *) return 1 ;; esac
	case "$phase" in
		preparing|committed|restored) ;;
		stopping) OC_ACTIVATING=1 ;;
		backup-ready|activated) OC_ACTIVATING=1; OC_BACKUP_READY=1 ;;
		*) return 1 ;;
	esac
	trap 'oc_exit $?' EXIT
	trap 'oc_signal 129' HUP
	trap 'oc_signal 130' INT
	trap 'oc_signal 143' TERM
	oc_restore || return 1
	OC_ACTIVATING=0
	[ "$phase" != committed ] || OC_COMMITTED=1
	write_installer_log "Interrupted installation recovered"
}
