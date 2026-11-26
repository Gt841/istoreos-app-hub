#!/usr/bin/env bash
# Owned preview process; an occupied port is never reclaimed from another process.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
action=${1:-status}; app=${2:-mise}
[[ "$app" = mise ]] || { echo 'Supported preview: mise' >&2; exit 2; }
port=${ISTORE_UI_DESIGN_PORT:-5180}
if ! [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] || ((port>65535)); then
 echo 'Invalid ISTORE_UI_DESIGN_PORT' >&2; exit 2
fi
export ISTORE_UI_DESIGN_PORT="$port"
server="$root/scripts/ui-design-server.cjs"
owner=$(printf '%s' "$root" | sha256sum | cut -c1-12)
runtime="${XDG_RUNTIME_DIR:-/tmp}/istore-ui-design-$UID-$owner"
mkdir -p "$runtime"
chmod 700 "$runtime"
pid_file="$runtime/$app-$port.pid"; log_file="$runtime/$app-$port.log"
exec 9>"$runtime/$app-$port.lock"; flock -w 5 9 || { echo 'Another preview operation is in progress' >&2; exit 1; }
running(){
 pid=''; [[ -r "$pid_file" ]] || return 1; read -r pid < "$pid_file" || return 1
 [[ "$pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$pid" 2>/dev/null && [[ -r /proc/$pid/cmdline ]] || return 1
 local -a args=(); mapfile -d '' -t args < "/proc/$pid/cmdline"
 [[ "${args[1]:-}" = "$server" ]] && tr '\0' '\n' < "/proc/$pid/environ" | grep -qx "ISTORE_UI_DESIGN_PORT=$port"
}
busy(){ [[ -n "$(ss -H -ltn "sport = :$port")" ]]; }
ready(){ curl -fsS --max-time 1 "http://127.0.0.1:$port/health" 2>/dev/null | python3 -c 'import json,sys; x=json.load(sys.stdin);sys.exit(0 if x["owner"]==sys.argv[1] and x["pid"]==int(sys.argv[2]) else 1)' "$root" "$pid" 2>/dev/null; }
case "$action" in
 start|run)
  if running; then echo "Already running: PID=$pid http://127.0.0.1:$port/mise"; exit 0; fi
  if busy; then echo "Port $port is occupied; no process was stopped." >&2; exit 1; fi
  [[ -x /var/cache/build-cache/run.sh ]] || { echo 'SSD build-cache entry missing' >&2; exit 1; }
  [[ -d "$root/apps/mise/web/node_modules" ]] || { echo 'Prepare the SSD dependencies as described in apps/mise/web/README.md' >&2; exit 1; }
  if [[ "$action" = run ]]; then
   echo "$$" > "$pid_file"; exec 9>&-
   exec /var/cache/build-cache/run.sh --project "$root" -- node "$server"
  fi
  nohup setsid /var/cache/build-cache/run.sh --project "$root" -- node "$server" >"$log_file" 2>&1 </dev/null 9>&- &
  pid=$!; echo "$pid" > "$pid_file"
  for ((i=0;i<450;i++)); do
   if ! kill -0 "$pid" 2>/dev/null; then rm -f "$pid_file"; tail -n 30 "$log_file" >&2; exit 1; fi
   if running && ready; then echo "Started: PID=$pid http://127.0.0.1:$port/mise"; echo "Log: $log_file"; exit 0; fi
   sleep 0.1
  done
  if running; then kill "$pid"; fi
  rm -f "$pid_file"; echo "Preview not ready; inspect $log_file" >&2; exit 1;;
 stop)
  if running; then
   kill "$pid"
   for ((i=0;i<40;i++)); do if ! running; then rm -f "$pid_file"; echo 'Stopped.'; exit 0; fi; sleep 0.1; done
   echo "Preview has not exited: PID=$pid" >&2; exit 1
  fi
  rm -f "$pid_file"; echo 'Not running.';;
 status) if running; then echo "Running: PID=$pid http://127.0.0.1:$port/mise"; else echo 'Not running.'; fi;;
 logs) if [[ -f "$log_file" ]]; then tail -n 50 "$log_file"; else echo 'No log yet.'; fi;;
 *) echo 'Usage: scripts/ui-design.sh {start|run|stop|status|logs} mise' >&2; exit 2;;
esac
