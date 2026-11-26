-- Serialize complete M5 device scenarios, whose individual app commands only
-- hold the application's operation lock for part of the scenario.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local lock='/tmp/openclawmgr-M5-tests.lock'
assert(not fs.lstat('/tmp/openclawmgr-installer.lock'),'Application operation is still active; no test started')
assert(fs.mkdir(lock,'700'),'Another M5 scenario owns the device; no test started')
local owner=s.process(s.nixio.getpid());s.write(lock..'/owner.json',owner)
local ok,code=pcall(function()
  local argv={'/usr/bin/lua'};for i=1,#arg do argv[#argv+1]=arg[i]end
  return s.run(argv,{timeout=4500})
end)
local current=s.decode(lock..'/owner.json')
assert(current.pid==owner.pid and current.start==owner.start and current.boot==owner.boot,'Test lease identity changed')
s.remove(lock)
if not ok then io.stderr:write(type(code)=='table'and code.message or tostring(code));io.stderr:write('\n');os.exit(1)end
os.exit(code)
