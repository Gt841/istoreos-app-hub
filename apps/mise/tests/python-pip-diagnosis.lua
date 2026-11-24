-- Targeted read-only Python probes while a task-owned pip.conf is present.
local root,base=assert(arg[1]),assert(arg[2])
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs;local r
for _,id in ipairs(require('store').list(root..'/environments'))do
 local value=s.decode(root..'/environments/'..id..'/receipt.json')
 if value and value.entry.tool=='python'and value.entry.version=='3.12.16'and value.entry.abi=='glibc'then r=value;break end
end
assert(r);local v=base..'/applications/65001/3.12.16-glibc/.venv'
local config=v..'/pip.conf';assert(not fs.lstat(config))
s.write(config,'[install]\ntarget = '..base..'/diagnosis-unused-target\n');assert(fs.chown(config,65001,65001))
local code=[=[import inspect,json,os,sys
from pip._internal.configuration import Configuration,get_configuration_files
c=Configuration(isolated=False);c.load()
print(json.dumps(dict(prefix=sys.prefix,base=sys.base_prefix,executable=sys.executable,virtual_env=os.environ.get('VIRTUAL_ENV'),files=get_configuration_files(),items=[dict(key=k,option=k.rsplit('.',1)[-1],is_target=k.rsplit('.',1)[-1]=='target')for k,v in c.items()],configuration_source=inspect.getsourcefile(Configuration))))
print(inspect.getsource(Configuration.items))
print(inspect.getsource(Configuration.load))
]=]
local function run(args,label)
 local argv={'/usr/share/mise-runtime/native/bin/exec-user','65001','65001',r.instance,'--venv',v,'python'}
 for _,a in ipairs(args)do argv[#argv+1]=a end
 local rc=s.run(argv,{env={MISE_RUNTIME_ROOT=root,ISTORE_RUNTIME_ACCELERATION='origin'},output=base..'/pip-diagnosis-'..label..'.log',timeout=60})
 return {rc=rc,output=s.read(base..'/pip-diagnosis-'..label..'.log')}
end
local ok,result=pcall(function()return{configuration=run({'-c',code},'config'),exit_status=run({'-c','raise SystemExit(23)'},'exit')}end)
assert(fs.unlink(config));assert(ok,result);print(s.json.stringify(result))
