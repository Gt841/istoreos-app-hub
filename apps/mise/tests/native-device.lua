local root,base,phase=assert(arg[1]),assert(arg[2]),arg[3]or'initial'
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local evidence=base..'/'..phase;s.mkdir(evidence,448)
local report={scope='real nonroot Go/Zig compilation, fixed policies and cache ownership',arch=s.nixio.uname().machine,boot_id=s.boot_id(),checks={}}
local function check(name,ok,details)
 report.checks[#report.checks+1]={name=name,passed=not not ok,details=details};s.write(evidence..'/native-result.json',report);assert(ok,name)
end
local function owned(path,uid)
 s.mkdir(path,448);assert(fs.chown(path,uid,uid))
end
local function run(r,args,cwd,uid,extra,timeout,stdin)
 uid=uid or 65001
 local argv={'/usr/share/mise-runtime/native/bin/exec-user',tostring(uid),tostring(uid),r.instance}
 for _,a in ipairs(args)do argv[#argv+1]=a end
 local env={MISE_RUNTIME_ROOT=root,ISTORE_RUNTIME_ACCELERATION='origin'};for k,v in pairs(extra or{})do env[k]=v end
 local out=evidence..'/output';local rc=s.run(argv,{cwd=cwd,env=env,output=out,timeout=timeout or 60,stdin=stdin})
 return rc,s.read(out)or''
end
local function main()
 for _,uid in ipairs({65001,65002})do
  s.write(evidence..'/request',{op='prepare-user',uid=uid,gid=uid})
  check('prepare UID '..uid,s.run({'/usr/sbin/mise-runtime','request'},{env={MISE_RUNTIME_ROOT=root},stdin=evidence..'/request',output=evidence..'/prepare',timeout=30})==0)
 end
 local apps=base..'/applications';s.mkdir(apps,493);owned(apps..'/65001',65001)
 local function appwrite(path,value) s.write(path,value,420);assert(fs.chown(path,65001,65001))end
 local roots={go={},zig={}};local count=0
 for _,id in ipairs(require('store').list(root..'/environments'))do
  local r=s.decode(root..'/environments/'..id..'/receipt.json')
  if r and r.verified and(r.entry.tool=='go'or r.entry.tool=='zig')then
   count=count+1;local label=r.entry.tool..'-'..r.entry.version
   local project=apps..'/65001/'..label;owned(project,65001)
   local other=project..'/second project';owned(other,65001)
   local sdk=root..'/environments/'..id;local home=root..'/users/65001/home'
   if r.entry.tool=='go'then
    local rc,out=run(r,{'go','env','-json','GOROOT','GOTOOLCHAIN','GOENV','GOPATH','GOBIN','GOCACHE','GOMODCACHE','GOTMPDIR','CGO_ENABLED'},project)
    local info=rc==0 and s.json.parse(out)
    check(label..' fixed Go environment',info and info.GOROOT==sdk and info.GOTOOLCHAIN=='local'and(info.GOENV==''or info.GOENV=='off')and info.CGO_ENABLED=='0',info)
    for _,key in ipairs({'GOPATH','GOBIN','GOCACHE','GOMODCACHE','GOTMPDIR'})do check(label..' persistent '..key,info[key]:sub(1,#home+1)==home..'/')end
    roots.go[id]=info
    rc,out=run(r,{'go','env','CGO_ENABLED'},project,nil,{CGO_ENABLED='1'});check(label..' explicit CGO=1 preserved',rc==0 and out=='1\n')
    rc,out=run(r,{'go','env','GOCACHE','GOMODCACHE'},other);check(label..' projects share UID/version build and UID module cache',rc==0 and out==info.GOCACHE..'\n'..info.GOMODCACHE..'\n')
    rc,out=run(r,{'go','env','GOCACHE','GOMODCACHE'},base,65002);check(label..' other UID caches isolated',rc==0 and out:find('/users/65002/home/',1,true)and not out:find(home,1,true))
    if phase=='initial'then
     appwrite(project..'/go.mod','module istore.local/probe\n\ngo '..r.entry.version..'\n',420)
     appwrite(project..'/main.go',[=[package main
import("encoding/json";"io";"os";"os/exec";"strings")
func main(){b,_:=io.ReadAll(os.Stdin);v,e:=exec.Command("go","version").Output();if e!=nil{panic(e)};json.NewEncoder(os.Stdout).Encode(map[string]any{"uid":os.Getuid(),"args":os.Args[1:],"stdin":string(b),"version":strings.TrimSpace(string(v)),"home":os.Getenv("HOME"),"tmp":os.Getenv("TMPDIR")})}
]=],420)
     local rc,out=run(r,{'gofmt','-w','main.go'},project);check(label..' gofmt works',rc==0,out)
     rc,out=run(r,{'go','build','-p=1','-o','application','.'},project,nil,nil,360);check(label..' real user Go compilation',rc==0,out)
     rc,out=run(r,{'go','build','-p=1','-o','explicit-output','.'},project,nil,nil,180);check(label..' explicit project output retained',rc==0 and fs.stat(project..'/explicit-output').uid==65001,out)
     appwrite(other..'/go.mod','module istore.local/higher\n\ngo 99.0.0\n',420)
     rc,out=run(r,{'go','list','.'},other);check(label..' higher toolchain refuses auto download',rc~=0 and out:find('GOTOOLCHAIN=local',1,true),out)
     rc,out=run(r,{'go','env','-w','GOTOOLCHAIN=auto'},project);check(label..' global Go env writes disabled',rc~=0,out)
     -- Both architectures use their own iStoreEnhance backend. Architecture
     -- must not silently select the origin or a different network policy.
     local env={ISTORE_RUNTIME_ACCELERATION='ks-cli'}
     rc,out=run(r,{'go','mod','download','-json','github.com/google/uuid@v1.6.0'},project,nil,env,180)
     local module=rc==0 and s.json.parse(out)
     check(label..' pinned module acquisition '..(env and'ks-cli'or'origin'),module and module.Version=='v1.6.0'and module.Dir:sub(1,#info.GOMODCACHE+1)==info.GOMODCACHE..'/'and module.Sum,out)
     local cgo=project..'/cgo';owned(cgo,65001)
     appwrite(cgo..'/go.mod','module istore.local/cgo\n\ngo '..r.entry.version..'\n',420)
     appwrite(cgo..'/main.go','package main\n/* int f(){return 1;} */\nimport "C"\nfunc main(){_ = C.f()}\n',420)
     rc,out=run(r,{'go','build','-p=1','.'},cgo,nil,{CGO_ENABLED='1',CC='/missing/explicit-c-compiler'},90)
     check(label..' missing explicit CGO compiler errors clearly',rc~=0 and out:find('/missing/explicit-c-compiler',1,true),out)
    end
    local input=evidence..'/stdin';s.write(input,'stdin $literal\n')
    local rc,out=run(r,{'--shell','-c',[[exec ./application 'space and $literal' "quote'" ]]},project,nil,nil,45,input)
    local value=rc==0 and s.json.parse(out)
    check(label..' program UID/stdin/args/fixed go child',value and value.uid==65001 and value.args[1]=='space and $literal'and value.args[2]=="quote'"and value.stdin=='stdin $literal\n'and value.home==home and value.tmp:sub(1,#home+1)==home..'/'and value.version:find('go'..r.entry.version,1,true),value or out)
   else
    local rc,out=run(r,{'zig','env'},project,nil,nil,90)
    local cache=home..'/.cache/zig/'..id
    check(label..' complete Zig and persistent caches',rc==0 and out:find('"'..sdk..'/lib"',1,true)and out:find('"'..cache..'/local'..project..'"',1,true)and out:find('"'..cache..'/global"',1,true))
    roots.zig[id]=cache
    rc,out=run(r,{'zig','env'},other,nil,nil,90);check(label..' project local cache isolated',rc==0 and out:find('"'..cache..'/local'..other..'"',1,true))
    rc,out=run(r,{'zig','env'},base,65002,nil,90);check(label..' other UID cache isolated',rc==0 and out:find('/users/65002/home/.cache/zig/',1,true))
    if phase=='initial'then
     appwrite(project..'/hello.zig','pub fn main() u8 { return 37; }\n',420)
     rc,out=run(r,{'zig','build-exe','hello.zig','-O','ReleaseSmall'},project,nil,nil,360);check(label..' real user Zig default output',rc==0 and fs.stat(project..'/hello').uid==65001,out)
     rc,out=run(r,{'zig','build-exe','hello.zig','-O','ReleaseSmall','-femit-bin=explicit-output','--cache-dir','custom-cache','--global-cache-dir','custom-global'},project,nil,nil,360)
     check(label..' explicit output/cache arguments preserved',rc==0 and fs.stat(project..'/explicit-output').uid==65001 and fs.stat(project..'/custom-cache')and fs.stat(project..'/custom-global'),out)
     appwrite(project..'/c.c','int main(void){return 42;}\n',420)
     appwrite(project..'/cxx.cc','template<int N>struct Answer{static constexpr int value=N;}; int main(){return Answer<42>::value;}\n',420)
     rc,out=run(r,{'zig','cc','-O0','c.c','-o','c-app'},project,nil,nil,360);check(label..' Zig C compilation',rc==0,out)
     rc,out=run(r,{'zig','c++','-std=c++17','-fno-exceptions','-fno-rtti','-nostdlib++','-O0','cxx.cc','-o','cxx-app'},project,nil,nil,360);check(label..' Zig C++ compilation',rc==0,out)
    end
    for name,status in pairs({hello=37,['explicit-output']=37,['c-app']=42,['cxx-app']=42})do
     rc,out=run(r,{'--shell','-c','exec ./'..name},project);check(label..' execute '..name,rc==status,out)
    end
   end
  end
 end
 check('two Go and two Zig instances tested',count==4)
 local go={};for id,v in pairs(roots.go)do go[#go+1]=v end
 check('Go versions isolate build cache and share UID module cache',#go==2 and go[1].GOCACHE~=go[2].GOCACHE and go[1].GOMODCACHE==go[2].GOMODCACHE)
 local zig={};for _,v in pairs(roots.zig)do zig[#zig+1]=v end;check('Zig versions isolate caches',#zig==2 and zig[1]~=zig[2])
 report.passed=true;s.write(evidence..'/native-result.json',report);fs.unlink(evidence..'/output');print(s.json.stringify(report))
end
local ok,err=pcall(main)
if not ok then report.passed=false;report.error=type(err)=='table'and err.message or tostring(err);s.write(evidence..'/native-result.json',report);io.stderr:write(report.error..'\n');os.exit(1)end
