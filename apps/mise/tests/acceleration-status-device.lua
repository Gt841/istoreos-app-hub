-- Real local iStoreEnhance availability must reach the public runtime response.
local base=assert(arg[1])
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');s.mkdir(base,448)
local rc,port=s.pipe_capture({'/sbin/uci','-q','get','istoreenhance.@istoreenhance[0].adminport'})
port=rc==0 and tonumber(port)or 5003;assert(port and port%1==0 and port>0 and port<65536)
local healthy=s.pipe_capture({'/usr/bin/curl','--disable','-fsS','--noproxy','*','--max-time','1','-o','/dev/null','http://127.0.0.1:'..port..'/api/download-gateway/routes'})==0
assert(healthy,'Test requires a healthy local iStoreEnhance backend')
s.write(base..'/request.json',{op='read'})
local rc=s.run({'/usr/sbin/mise-runtime','request'},{stdin=base..'/request.json',output=base..'/response.json',timeout=60})
local response=s.decode(base..'/response.json')
local report={local_istoreenhance_healthy=healthy,public_request_exit=rc,gateway=response and response.value and response.value.gateway,passed=false}
report.passed=rc==0 and response.ok and report.gateway==true
s.write(base..'/result.json',report);print(s.json.stringify(report));assert(report.passed,'Healthy local service reported unavailable by runtime')
