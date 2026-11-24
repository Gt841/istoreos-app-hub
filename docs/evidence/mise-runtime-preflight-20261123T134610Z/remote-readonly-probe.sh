set +e
printf '[identity]\n'
date -u
uname -a
cat /etc/openwrt_release
cat /proc/sys/kernel/random/boot_id
uptime
printf '[memory]\n'
awk '/MemTotal:|MemAvailable:|SwapTotal:|SwapFree:/{print}' /proc/meminfo
printf '[storage-config]\n'
for key in mise.main.runtime_dir quickstart.main.conf_dir quickstart.main.main_dir openclawmgr.main.base_dir agentflow.main.data_dir; do value="$(uci -q get "$key" 2>/dev/null)"; printf '%s=%s\n' "$key" "$value"; done
printf '[mounts]\n'
awk '$2=="/" || $2=="/overlay" || $2=="/ext_overlay" || $2 ~ /^\/mnt\/[^\/]+$/ {print $1,$2,$3,$4}' /proc/mounts
printf '[disk-kib]\n'
df -kP
printf '[inode-stat]\n'
for p in / /overlay /mnt/vio4-0 /mnt/mmc1-4 /mnt/nvme0n1-1; do
 if [ -d "$p" ]; then printf 'path=%s ' "$p"; stat -f -c 'type=%T block=%S total=%b free=%a inodes=%c free_inodes=%d' "$p" 2>/dev/null; [ -w "$p" ] && printf 'access-writable=yes\n' || printf 'access-writable=no\n'; fi
done
printf '[tools]\n'
for c in opkg apk ubus uci jsonfilter jshn lua curl wget tar xz zstd sha256sum timeout stat setsid git ks-cli mise node npm python3 gcc cc readelf; do command -v "$c" 2>/dev/null || printf 'missing=%s\n' "$c"; done
printf '[package-versions]\n'
if command -v opkg >/dev/null 2>&1; then opkg list-installed | awk '$1 ~ /^(mise|ks-cli|istoreenhance|agentflow|luci-app-agentflow|luci-app-openclawmgr|openclawmgr-glibc|coreutils-timeout|coreutils-stat|git|git-http|curl|ca-bundle|lua|liblua|jsonfilter|jshn|tar|xz-utils|luci-lib-taskd|libstdcpp|libatomic)$/'; fi
printf '[service-presence]\n'
for c in kspeeder iStoreEnhance agentflow openclawmgr uhttpd rpcd dockerd incusd; do printf '%s=' "$c"; pidof "$c" 2>/dev/null || printf 'not-running\n'; done
for service in openclawmgr agentflow istoreenhance; do if [ -x "/etc/init.d/$service" ]; then /etc/init.d/"$service" enabled >/dev/null 2>&1; printf '%s-autostart-exit=%s\n' "$service" "$?"; fi; done
printf '[installer-locks]\n'
for p in /tmp/openclawmgr-installer.lock /tmp/mise-runtime.lock; do if [ -e "$p" ]; then ls -ld "$p"; [ ! -r "$p/pid" ] || cat "$p/pid"; else printf 'absent=%s\n' "$p"; fi; done
printf '[configured-storage-summary]\n'
for key in mise.main.runtime_dir quickstart.main.conf_dir openclawmgr.main.base_dir; do
 p="$(uci -q get "$key" 2>/dev/null)"; [ -n "$p" ] || continue
 printf 'key=%s path=%s\n' "$key" "$p"
 if [ -d "$p" ]; then df -kP "$p"; timeout 15 du -sk "$p" 2>/dev/null; else printf 'directory-absent\n'; fi
done
printf '[prior-acceptance-directories]\n'
for base in /mnt/vio4-0/Configs /mnt/mmc1-4/Configs /mnt/nvme0n1-1/Configs; do
 [ -d "$base" ] || continue
 for p in "$base"/openclaw* "$base"/Runtime "$base"/mise*; do [ ! -e "$p" ] || { ls -ld "$p"; timeout 15 du -sk "$p" 2>/dev/null; }; done
done
printf '[kernel-alert-counts]\n'
dmesg 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /SQUASHFS.*[Ee]rror|I\/O error|Buffer I\/O|EXT4-fs error|Out of memory|oom-kill|mmc.*timeout|nvme.*(reset|timeout)/{n++; if(n<=12)print} END{print "matched_lines=" n+0}'
printf '[network-head]\n'
if command -v curl >/dev/null 2>&1; then
 for url in https://nodejs.org/dist/index.json https://registry.npmjs.org/openclaw https://github.com/jdx/mise/releases https://go.dev/dl/; do
  printf 'url=%s ' "$url"
  curl -sS -I -L --connect-timeout 5 --max-time 15 -o /dev/null -w 'http=%{http_code} verify=%{ssl_verify_result} seconds=%{time_total}\n' "$url"; printf 'curl-exit=%s\n' "$?"
 done
fi
printf '[ks-cli-version]\n'
if command -v ks-cli >/dev/null 2>&1; then timeout 10 ks-cli --version; fi
printf '[ks-cli-capability]\n'
if command -v ks-cli >/dev/null 2>&1; then timeout 10 ks-cli --explain --json npm --version 2>/dev/null | head -c 8000; printf '\n'; fi
