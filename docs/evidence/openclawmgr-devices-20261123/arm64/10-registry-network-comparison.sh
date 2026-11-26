set -u
printf '%s\n' '== registry origin'
curl -fsS --connect-timeout 3 --max-time 12 -o /dev/null -w 'origin code=%{http_code} total=%{time_total}\n' 'https://registry.npmjs.org/@napi-rs%2fcanvas' || true
printf '%s\n' '== KSpeeder gateway'
curl -fsS --connect-timeout 3 --max-time 12 --resolve 'dl-npm.linkease.net:5443:127.0.0.1' -o /dev/null -w 'gateway code=%{http_code} total=%{time_total}\n' 'https://dl-npm.linkease.net:5443/@napi-rs%2fcanvas' || true
printf '%s\n' '== baseline source service process'
ubus call service list '{"name":"istoreenhance"}' | jsonfilter -e '@.istoreenhance.instances.*.running' || true
