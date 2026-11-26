set -u
base='/mnt/nvme0n1-1/OpenClawMgr-acceptance-20261123'
printf '%s\n' '== original npm install debug tail'
for f in "$base"/npm-cache/_logs/*.log; do
 [ -f "$f" ] || continue
 if grep -q 'title npm install' "$f"; then printf 'log=%s\n' "$f"; tail -n 28 "$f"; fi
done
