set -eu
printf '%s\n' '== baseline'
uname -m
uptime
free -m
for path in /etc/config/openclawmgr /etc/init.d/openclawmgr /usr/libexec/istorec/openclawmgr.sh /usr/share/openclawmgr /usr/share/openclawmgr-glibc; do
 if [ -e "$path" ] || [ -L "$path" ]; then printf 'PRESENT %s\n' "$path"; else printf 'ABSENT %s\n' "$path"; fi
done
id openclawmgr 2>/dev/null || true
printf '%s\n' '== acceleration availability'
command -v ks-cli || true
printf 'KSpeeder='
ubus call service list '{"name":"istoreenhance"}' | jsonfilter -e '@.istoreenhance.instances.*.running' || true
printf '%s\n' '== test port availability'
netstat -lnt 2>/dev/null | grep ':19189 ' || true
