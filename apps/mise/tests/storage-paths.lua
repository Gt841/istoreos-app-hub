-- Enumeration policy only; no real mounts or configuration writes.
package.path=arg[1]..'/?.lua;'..package.path
local contract=require('contract')
local mounts,rejected='',{}
package.loaded.system={read=function(path)assert(path=='/proc/mounts');return mounts end}
package.loaded.store={validate=function(path)contract.path(path);assert(not rejected[path])end}
package.loaded.wire={array=function(v)return v or{}end}
local paths=require('storage-paths');local n=0
local function test(name,fn)fn();n=n+1;print('PASS '..name)end
local function equal(actual,wanted)assert(table.concat(actual,'|')==table.concat(wanted,'|'))end
test('no disks has no /root or invented fallback',function()
  local p,d=paths.discover('','/root/Configs');equal(p,{});assert(d=='')
end)
mounts=[[/dev/sdb /mnt/b ext4 rw,relatime 0 0
/dev/sda /mnt/a ext4 rw 0 0
/dev/sda /mnt/a ext4 rw 0 0
/dev/sdc /mnt/readonly ext4 ro 0 0
/dev/sdd /mnt/noexec ext4 rw,noexec 0 0
/dev/loop1 /mnt/fixture ext4 rw 0 0
/dev/ram0 /mnt/ram ext4 rw 0 0
tmpfs /mnt/temporary tmpfs rw 0 0
server:/export /mnt/network nfs rw 0 0
/dev/dm-1 /mnt/a/containers/test ext4 rw 0 0
/dev/sda /ext_overlay ext4 rw 0 0
]]
test('one sorted option per usable disk; no containers or system overlay',function()
  local p,d=paths.discover('');equal(p,{'/mnt/a/Configs/Runtime','/mnt/b/Configs/Runtime'});assert(d==p[1])
end)
test('QuickStart configured folder is preferred on a usable disk',function()
  local p,d=paths.discover('','/mnt/b/CustomConfigs/');assert(d=='/mnt/b/CustomConfigs/Runtime');assert(p[1]==d and #p==3)
end)
test('existing custom directory is retained without changing recommendation',function()
  local p,d=paths.discover('/mnt/offline/ExistingRuntime');assert(p[1]=='/mnt/offline/ExistingRuntime');assert(d=='/mnt/a/Configs/Runtime')
end)
test('current directory and proposed path are deduplicated',function()
  local p=paths.discover('/mnt/a/Configs/Runtime');assert(#p==2)
end)
test('invalid or unmounted preference cannot replace safe disk recommendation',function()
  for _,dir in ipairs({'/root/Configs','/mnt/missing/Configs','/mnt/a/../b/Configs'})do
    local _,d=paths.discover('',dir);assert(d=='/mnt/a/Configs/Runtime')
  end
end)
test('canonical storage validator can reject unsafe parent directories',function()
  rejected['/mnt/a/Configs/Runtime']=true
  local p,d=paths.discover('');equal(p,{'/mnt/b/Configs/Runtime'});assert(d==p[1])
end)
print('passed='..n)
