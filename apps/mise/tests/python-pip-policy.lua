-- Exercise actual pip config loading and installation, not a config mock.
local root,base=assert(arg[1]),assert(arg[2])
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local dir=base..'/pip-policy-resume1';assert(not fs.lstat(dir));s.mkdir(dir,448)
local report={scope='actual pip config isolation across installed Python matrix',arch=s.nixio.uname().machine,checks={}}
local function check(name,passed)
 report.checks[#report.checks+1]={name=name,passed=not not passed};s.write(dir..'/result.json',report);assert(passed,name)
end
local function main()
 local count=0
 for _,id in ipairs(require('store').list(root..'/environments'))do
  local r=s.decode(root..'/environments/'..id..'/receipt.json')
  if r and r.verified and r.entry.tool=='python'then
   count=count+1;local label=r.entry.version..'-'..r.entry.abi
   local project=base..'/applications/65001/'..label;local v=project..'/.venv'
   local cfg=v..'/pip.conf';local custom=project..'/pip-policy-redirect.conf'
   assert(not fs.lstat(cfg)and not fs.lstat(custom))
   local function run(args,env)
    local argv={'/usr/share/mise-runtime/native/bin/exec-user','65001','65001',id,'--venv',v,'pip'}
    for _,a in ipairs(args)do argv[#argv+1]=a end
    env=env or{};env.MISE_RUNTIME_ROOT=root;env.ISTORE_RUNTIME_ACCELERATION=env.ISTORE_RUNTIME_ACCELERATION or'origin'
    local out=dir..'/output';local rc=s.run(argv,{env=env,output=out,timeout=90,cwd=project})
    return rc,s.read(out)or''
   end
   local function configured(path,content,fn)
    s.write(path,content);assert(fs.chown(path,65001,65001))
    local ok,a,b=pcall(fn);assert(fs.unlink(path));assert(ok,a);return a,b
   end
   local install={'install','--force-reinstall','--no-index','--no-deps','--no-compile',project..'/istore_runtime_probe-1.0-py3-none-any.whl'}
   for _,section in ipairs({'global','install'})do
    for _,option in ipairs({'target','prefix','root','python','user'})do
     local escaped=project..'/policy-escape-'..section..'-'..option
     assert(not fs.lstat(escaped));local value=option=='user'and'true'or escaped
     local rc,out=configured(cfg,'['..section..']\n'..option..' = '..value..'\n',function()return run(install)end)
     check(label..' refuses '..section..'.'..option,rc==2 and out:find('clear '..section..'.'..option,1,true)and not fs.lstat(escaped))
    end
   end
   local escaped=project..'/policy-escape-redirect';assert(not fs.lstat(escaped))
   local rc,out=configured(custom,'[install]\ntarget = '..escaped..'\n',function()return run(install,{PIP_CONFIG_FILE=custom})end)
   check(label..' respects explicit config path but rejects target',rc==2 and out:find('clear install.target',1,true)and not fs.lstat(escaped))
   if report.arch=='aarch64'and r.entry.abi=='musl'then
    rc,out=configured(cfg,'[install]\ntarget = '..escaped..'\n',function()return run(install,{ISTORE_RUNTIME_ACCELERATION='ks-cli'})end)
    check(label..' rejects target before ks-cli dispatch',rc==2 and out:find('clear install.target',1,true)and not fs.lstat(escaped))
   end
   -- Configuration is retained: pip must discover our wheel via find-links,
   -- with no-index supplied ONLY by config. Credentials are task-only values;
   -- neither the value nor raw command output enters the public report.
   local secret='task-only-private-index-value'
   local content='[global]\nno-index = true\nfind-links = '..project..'\nindex-url = https://test-user:'..secret..'@example.invalid/simple\n[install]\nuser = false\n'
   local args={'install','--force-reinstall','--no-deps','--no-compile','istore-runtime-probe==1.0'}
   rc,out=configured(cfg,content,function()return run(args,{PIP_TARGET=escaped,PIP_PREFIX=escaped,PIP_USER='true',PIP_PYTHON='/missing/interpreter'})end)
   check(label..' preserves permitted config and clears inherited destinations',rc==0 and not fs.lstat(escaped)and not out:find(secret,1,true))
   check(label..' all temporary config restored',not fs.lstat(cfg)and not fs.lstat(custom))
  end
 end
 check('four Python version/ABI instances tested',count==4)
 report.passed=true;s.write(dir..'/result.json',report);fs.unlink(dir..'/output');print(s.json.stringify(report))
end
local ok,err=pcall(main)
if not ok then report.passed=false;report.error=type(err)=='table'and err.message or tostring(err);s.write(dir..'/result.json',report);io.stderr:write(report.error..'\n');os.exit(1)end
