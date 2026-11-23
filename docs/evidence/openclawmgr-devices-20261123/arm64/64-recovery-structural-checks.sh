set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf '%s\n' '== directory safety'
for name in releases backups data log; do ls -ld "$base/$name"; done
printf '%s\n' '== runtime sources'
wc -c /usr/libexec/istorec/openclawmgr.sh /usr/share/openclawmgr/install-runtime.sh /usr/share/openclawmgr/runtime-check.cjs
printf '%s\n' '== journal bytes'
for txn in "$base"/.install.*; do
 for name in phase release old-current old-previous legacy was-running; do
 printf '%s\n' "$name"; od -An -tx1 "$txn/$name" | head -n 3
 done
done
printf '%s\n' '== recovery trace without secrets'
# recover has not reached configuration/service calls; filter trace to structural checks only.
sh -x /usr/libexec/istorec/openclawmgr.sh recover_install 2>&1 | grep -E 'oc_|OC_|\[ |readlink|return|recover|journal|phase|cat /mnt.*(phase|release|old-|legacy|was-running)' | tail -n 65
