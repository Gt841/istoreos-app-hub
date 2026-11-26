-- Run the remaining independent scenarios sequentially on one device.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system')
local base,dir,source=assert(arg[1]),assert(arg[2]),assert(arg[3])
local scenarios={
  {'cancel-final','interruption-device.lua','cancel'},
  {'interruption-final','interruption-device.lua','kill'},
  {'shared-cancel-final','shared-cancel-device.lua'},
  {'independence-final','independence-device.lua',source}
}
local report={passed=false,arch=s.nixio.uname().machine,scenarios={}}
for _,scenario in ipairs(scenarios)do
  report.active=scenario[1];s.write(dir..'/remaining-status.json',report)
  local argv={'/usr/bin/lua',dir..'/with-device-lease.lua',dir..'/'..scenario[2],base,dir..'/'..scenario[1]}
  if scenario[3]then argv[#argv+1]=scenario[3]end
  local began=os.time()
  local rc=s.run(argv,{output=dir..'/'..scenario[1]..'.driver-private.log',timeout=1200})
  report.scenarios[#report.scenarios+1]={name=scenario[1],exit=rc,seconds=os.time()-began,passed=rc==0}
  s.write(dir..'/remaining-status.json',report)
  assert(rc==0,'Scenario failed; later scenarios not started: '..scenario[1])
end
report.passed=true;report.active=nil
s.write(dir..'/remaining-status.json',report);print(s.json.stringify(report))
