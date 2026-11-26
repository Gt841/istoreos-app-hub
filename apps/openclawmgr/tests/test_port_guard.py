"""Exercise the shipped listener parser and procd/HOME ownership decision."""
import os
from pathlib import Path
import subprocess
import unittest

MODULE=Path(__file__).resolve().parents[1]/'luci-app-openclawmgr/root/usr/share/openclawmgr/port-check.lua'
HARNESS=r'''
local scenario=os.getenv('CASE')
local row='0: 00000000:4969 00000000:0000 0A 0:0 00:0 0 0 0 12345\n'
local values={['/proc/net/tcp']='header\n', ['/proc/net/tcp6']='header\n',
 ['/proc/42/environ']='HOME=/mnt/disk/OpenClawMgr/data\0',
 ['/proc/42/status']='PPid: 1\n', ['/proc/43/status']='PPid: 42\n',
 ['/proc/99/status']='PPid: 1\n', ['/proc/100/status']='PPid: 43\n'}
for _,pid in ipairs({43,99,100})do values['/proc/'..pid..'/environ']='HOME=/mnt/disk/OpenClawMgr/data\0'end
if scenario=='child-other-home'then values['/proc/43/environ']='HOME=/mnt/old/OpenClawMgr/data\0'end
if scenario=='ipv6'or scenario=='ipv6-unmanaged'then values['/proc/net/tcp6']=row
elseif scenario~='free' then values['/proc/net/tcp']=row end
if scenario=='connected'then values['/proc/net/tcp']=row:gsub(' 0A ',' 01 ')end
if scenario=='old-directory'then values['/proc/42/environ']='HOME=/mnt/old/OpenClawMgr/data\0'end
if scenario=='missing-proc'then values['/proc/net/tcp']=nil end
if scenario=='no-ipv6' then values['/proc/net/tcp6']=nil end
package.loaded.system={read=function(p)return values[p]end,
 need=function(ok,code,message)if not ok then error({code=code,message=message},0)end end,
 fs={lstat=function(p)return values[p]and{type='reg'}or nil end,
 dir=function(p)local list=p=='/proc'and{'42','43','99','100'}or{'5'};local i=0;return function()i=i+1;return list[i]end end,
 readlink=function(p)
  local target=(scenario=='child'or scenario=='child-other-home')and'43'or scenario=='grandchild'and'100'or scenario=='orphan'and'99'or'42'
  return scenario~='wrong-socket'and p=='/proc/'..target..'/fd/5'and'socket:[12345]'or'socket:[99999]'
 end}}
local check=assert(loadfile(os.getenv('PORT_MODULE')))().check
local ok,err=pcall(check,'/mnt/disk/OpenClawMgr',18793,(scenario=='unmanaged'or scenario=='ipv6-unmanaged')and''or'42')
print(ok and'allowed'or err.code)
'''

class PortGuard(unittest.TestCase):
    def test_actual_parser_and_instance_ownership(self):
        for case,expected in [('free','allowed'),('managed','allowed'),('connected','allowed'),
                              ('ipv6','allowed'),('ipv6-unmanaged','PORT_IN_USE'),('unmanaged','PORT_IN_USE'),
                              ('old-directory','PORT_IN_USE'),('wrong-socket','PORT_IN_USE'),
                              ('missing-proc','OFFLINE'),('no-ipv6','allowed'),
                              ('child','allowed'),('grandchild','allowed'),
                              ('orphan','PORT_IN_USE'),('child-other-home','PORT_IN_USE')]:
            with self.subTest(case=case):
                result=subprocess.run(['lua','-'],input=HARNESS,text=True,capture_output=True,check=True,
                                      env={**os.environ,'CASE':case,'PORT_MODULE':str(MODULE)})
                self.assertEqual(result.stdout.strip(),expected)

if __name__=='__main__':unittest.main()
