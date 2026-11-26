-- Real SDK/venv/pip/ELF checks under a non-root application UID.
local root,base,phase=assert(arg[1]),assert(arg[2]),arg[3]or'initial'
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs;local uid=65001
local evidence=base..'/'..phase;s.mkdir(evidence,448)
local report={scope='real non-root fixed Python applications',boot_id=s.boot_id(),arch=s.nixio.uname().machine,checks={}}
local function check(name,ok,details)
 report.checks[#report.checks+1]={name=name,passed=not not ok,details=details}
 s.write(evidence..'/python-result.json',report);assert(ok,name)
end
local function run(r,args,timeout,extra)
 local argv={'/usr/share/mise-runtime/native/bin/exec-user',tostring(uid),tostring(uid),r.instance}
 for _,a in ipairs(args)do argv[#argv+1]=a end
 local env={MISE_RUNTIME_ROOT=root,ISTORE_RUNTIME_ACCELERATION='origin'}
 for k,v in pairs(extra or{})do env[k]=v end
 local out=evidence..'/output'
 local rc=s.run(argv,{env=env,output=out,timeout=timeout or 60,cwd=base})
 return rc,s.read(out)or''
end
local fixtures=[=[import zipfile,pathlib
p=pathlib.Path(__import__('sys').argv[1]);d='istore_runtime_probe-1.0.dist-info/'
files={'istore_runtime_probe.py':"import json,os,sys\ndef main():\n print(json.dumps(dict(prefix=sys.prefix,executable=sys.executable,uid=os.getuid(),args=sys.argv[1:],stdin=sys.stdin.read())))\n return 19\n",d+'METADATA':'Metadata-Version: 2.1\nName: istore-runtime-probe\nVersion: 1.0\n',d+'WHEEL':'Wheel-Version: 1.0\nGenerator: istore-test\nRoot-Is-Purelib: true\nTag: py3-none-any\n',d+'entry_points.txt':'[console_scripts]\nistore-python-probe = istore_runtime_probe:main\n'}
files[d+'RECORD']=''.join(k+',,\n'for k in files)+d+'RECORD,,\n'
with zipfile.ZipFile(p/'istore_runtime_probe-1.0-py3-none-any.whl','w')as z:
 for name,data in files.items():z.writestr(name,data)
]=]
local python_checks=[=[import ctypes,json,os,pathlib,site,sqlite3,ssl,subprocess,sys
v=pathlib.Path(sys.argv[1]);sdk=pathlib.Path(sys.argv[2]);home=pathlib.Path(sys.argv[3]);expected=sys.argv[4]
assert os.getuid()==65001 and not os.getgroups()
assert pathlib.Path(sys.prefix)==v and pathlib.Path(sys.base_prefix)==sdk and pathlib.Path(sys.executable)==v/'bin/python3'
assert not site.ENABLE_USER_SITE and os.environ['HOME']==str(home)
for k in ('TMPDIR','PYTHONPYCACHEPREFIX','PIP_CACHE_DIR','XDG_CONFIG_HOME','XDG_CACHE_HOME'):assert pathlib.Path(os.environ[k]).is_relative_to(home),k
assert ctypes.CDLL(None).getpid()==os.getpid()
db=sqlite3.connect(':memory:');assert db.execute('select ?',('a\x00b',)).fetchone()==('a\x00b',)
context=ssl.create_default_context();assert context.verify_mode==ssl.CERT_REQUIRED and context.check_hostname and context.cert_store_stats()['x509_ca']>0
from pip._vendor.packaging.tags import sys_tags
tags=[str(t)for t in sys_tags()];assert any(expected+'_'in t for t in tags)
assert not any(('musllinux_'if expected=='manylinux'else'manylinux_')in t for t in tags)
from markupsafe import _speedups,escape
assert escape('<x>')=='&lt;x&gt;' and _speedups.__file__.endswith('.so')
code='import json,os,sys;print(json.dumps([sys.executable,sys.prefix,os.getuid()]))'
for entry in (sys.executable,'python','python3'):
 child=json.loads(subprocess.check_output([entry,'-I','-c',code],text=True));assert child==[sys.executable,sys.prefix,65001],child
out=subprocess.check_output([sys.executable,'-c','import sys;print(repr(sys.argv[1:])+":"+sys.stdin.read())','space and $literal',"quote'"],input=b'stdin\x00data')
assert out==b'''['space and $literal', "quote'"]:stdin\x00data\n''',out
result=subprocess.run([str(v/'bin/istore-python-probe'),'space and $literal'],input='hello stdin',text=True,capture_output=True)
assert result.returncode==19,result
console=json.loads(result.stdout);assert console['uid']==65001 and console['prefix']==str(v)and console['executable']==str(v/'bin/python3')and console['stdin']=='hello stdin'and console['args']==['space and $literal']
print(json.dumps(dict(uid=os.getuid(),prefix=sys.prefix,base=sys.base_prefix,executable=sys.executable,wheel_abi=expected,native_extension=_speedups.__file__,home=str(home),pip=__import__('importlib.metadata',fromlist=['version']).version('pip'))))
]=]
local function main()
 local request=evidence..'/request';s.write(request,{op='prepare-user',uid=uid,gid=uid})
 check('prepare non-root persistent HOME',s.run({'/usr/sbin/mise-runtime','request'},{env={MISE_RUNTIME_ROOT=root},stdin=request,output=evidence..'/prepare',timeout=30})==0)
 local apps=base..'/applications';s.mkdir(apps,493)
 local parent=apps..'/'..uid;s.mkdir(parent,448);assert(fs.chown(parent,uid,uid))
 local count=0
 for _,id in ipairs(require('store').list(root..'/environments'))do
  local r=s.decode(root..'/environments/'..id..'/receipt.json')
  if r and r.verified and r.entry.tool=='python'then
   count=count+1;local label=r.entry.version..'-'..r.entry.abi
   local project=parent..'/'..label;local v=project..'/.venv'
   local home=root..'/users/'..uid..'/home';local sdk=root..'/environments/'..id
   if phase=='initial'then
    s.mkdir(project,448);assert(fs.chown(project,uid,uid))
    local rc,out
    if not fs.lstat(v)then rc,out=run(r,{'--create-venv',v},180);check(label..' create verified bundled-pip venv',rc==0,out)
    else local ref=s.decode(v..'/.istore-python-runtime.json');check(label..' reuse own previous test venv',ref and ref.state=='ready'and ref.instance==id)end
    rc,out=run(r,{'python','-c',fixtures,project});check(label..' create console wheel fixture',rc==0,out)
    rc,out=run(r,{'--venv',v,'pip','install','--no-index',project..'/istore_runtime_probe-1.0-py3-none-any.whl'},90);check(label..' real pip installs console wheel',rc==0,out)
    rc,out=run(r,{'--venv',v,'pip','install','--only-binary=:all:','--no-deps','MarkupSafe==3.0.3'},180,{ISTORE_RUNTIME_ACCELERATION=(r.entry.abi=='musl'and report.arch=='aarch64')and'ks-cli'or'origin'})
    check(label..' real native wheel install via '..((r.entry.abi=='musl'and report.arch=='aarch64')and'ks-cli'or'origin'),rc==0,out)
   end
   local rc,out=run(r,{'--venv',v,'python','-c',python_checks,v,sdk,home,r.entry.abi=='glibc'and'manylinux'or'musllinux'})
   check(label..' native extension, fixed children/console, ABI and UID/HOME',rc==0,rc==0 and s.json.parse(out)or out)
   rc,out=run(r,{'python','-c',"import importlib.util;assert importlib.util.find_spec('istore_runtime_probe')is None;assert importlib.util.find_spec('markupsafe')is None"})
   check(label..' application packages absent from shared base',rc==0,out)
   rc,out=run(r,{'--venv',v,'--shell','-c',[[python -c 'import sys;assert sys.prefix!=sys.base_prefix'; pip --version]]})
   check(label..' activated shell keeps selected venv',rc==0 and out:find(v,1,true)~=nil,out)
   rc,out=run(r,{'--venv',v,'python',base..'/python-tls.py',base..'/tls'},90)
   check(label..' actual trusted/untrusted TLS',rc==0,rc==0 and s.json.parse(out)or out)
   rc,out=run(r,{'pip','install','this-must-not-run'});check(label..' shared pip refuses package mutation',rc~=0 and out:find('Shared pip',1,true)~=nil)
   if phase=='initial'then
    local before=s.read(v..'/.istore-python-runtime.json')
    rc,out=run(r,{'--create-venv',v});check(label..' existing target preserved',rc~=0 and before==s.read(v..'/.istore-python-runtime.json'))
    rc,out=run(r,{'--venv',v,'pip','install','--target',sdk,'this-must-not-run'});check(label..' pip target escape refused',rc~=0 and out:find('overriding',1,true)~=nil)
    rc,out=run(r,{'--venv',v..'/../.venv','python','--version'});check(label..' traversal refused',rc~=0)
    local ref=s.decode(v..'/.istore-python-runtime.json');local save=ref.instance;ref.instance='foreign-sdk';s.write(v..'/.istore-python-runtime.json',ref);assert(fs.chown(v..'/.istore-python-runtime.json',uid,uid))
    rc,out=run(r,{'--venv',v,'python','--version'});check(label..' foreign local receipt refused',rc~=0)
    s.write(v..'/.istore-python-runtime.json',before);assert(fs.chown(v..'/.istore-python-runtime.json',uid,uid))
    local cfg=s.read(v..'/pyvenv.cfg');s.write(v..'/pyvenv.cfg',cfg..'home = /root/foreign\n');assert(fs.chown(v..'/pyvenv.cfg',uid,uid))
    rc,out=run(r,{'--venv',v,'python','--version'})
    s.write(v..'/pyvenv.cfg',cfg);assert(fs.chown(v..'/pyvenv.cfg',uid,uid))
    check(label..' changed venv configuration refused',rc~=0)
    assert(fs.rename(v..'/.istore-python-runtime.json',v..'/.receipt-test-backup'))
    rc,out=run(r,{'--venv',v,'python','--version'})
    assert(fs.rename(v..'/.receipt-test-backup',v..'/.istore-python-runtime.json'))
    check(label..' missing local receipt has no fallback',rc~=0)
    if label=='3.12.16-glibc'then
     local bundled=sdk..'/lib/python3.12/ensurepip/_bundled';local hidden=bundled..'.M6-fault'
     assert(not fs.lstat(hidden)and fs.rename(bundled,hidden))
     local ok,a,b=pcall(run,r,{'--create-venv',project..'/ensurepip-failure'},120)
     assert(fs.rename(hidden,bundled))
     check(label..' ensurepip failure cleans only new target',ok and a~=0 and not fs.lstat(project..'/ensurepip-failure')and fs.lstat(v),ok and b or tostring(a))
     local marker=sdk..'/.python-sdk.json';assert(fs.rename(marker,marker..'.M6-fault'))
     rc,out=run(r,{'--venv',v,'python','--version'})
     assert(fs.rename(marker..'.M6-fault',marker))
     check(label..' missing SDK launcher identity has no fallback',rc~=0)
    end
   end
  end
 end
 check('full two-version GNU/musl installed matrix',count==4,count)
 report.passed=true;s.write(evidence..'/python-result.json',report);fs.unlink(evidence..'/output');print(s.json.stringify(report))
end
local ok,err=pcall(main)
if not ok then report.passed=false;report.error=type(err)=='table'and err.message or tostring(err);s.write(evidence..'/python-result.json',report);io.stderr:write(report.error..'\n');os.exit(1)end
