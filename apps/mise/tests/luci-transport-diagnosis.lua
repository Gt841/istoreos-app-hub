local n=require('nixio');local json=require('luci.jsonc')
local fixed=arg[1]=='fixed'
local input_r,input_w=n.pipe();local output_r,output_w=n.pipe()
local input_fd=input_r:fileno()
local function redirect(fd,target)
  if fd:fileno()==target:fileno()then
    local copy=assert(n.dup(fd));fd:close();fd=copy
  end
  assert(n.dup(fd,target));fd:close()
end
local pid=assert(n.fork())
if pid==0 then
 input_w:close();output_r:close()
 if fixed then redirect(input_r,n.stdin);redirect(output_w,n.stdout)
 else n.dup(input_r,n.stdin);n.dup(output_w,n.stdout);input_r:close();output_w:close()end
 local err=n.open('/dev/null','w');if fixed then redirect(err,n.stderr)else n.dup(err,n.stderr);err:close()end
 n.exec('/usr/sbin/mise-runtime','request');os.exit(127)
end
input_r:close();output_w:close();assert(input_w:write('{"op":"catalog"}'));input_w:close()
local parts={};while true do local part=output_r:read(8192);if not part or #part==0 then break end;parts[#parts+1]=part end
output_r:close();local _,_,code=n.waitpid(pid)
local result=json.parse(table.concat(parts));local ok=result and result.ok==true
io.write(json.stringify({fixed=fixed,input_fd=input_fd,backend_ok=ok,backend_error=result and result.error,exit_code=code})..'\n')
if fixed then assert(ok and #result.value.entries>=44)elseif input_fd==0 then assert(not ok and result.error.message=='Request too large')else assert(ok)end
