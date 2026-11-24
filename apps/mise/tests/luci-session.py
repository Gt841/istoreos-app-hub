#!/usr/bin/env python3
"""Root-SSH-created ephemeral real rpcd sessions; credentials never enter evidence."""
import argparse,json,os,secrets,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('host');p.add_argument('file',type=Path);p.add_argument('--destroy',action='store_true');a=p.parse_args()
def ubus(method,value):
 # JSON travels on stdin, not shell text or command-line arguments.
 code="local j=require('luci.jsonc');local u=require('luci.util');local r,err=u.ubus('session',"+repr(method)+",j.parse(io.read('*a')));assert(not err or err==0);io.write(j.stringify(r or {}))"
 import shlex
 raw=subprocess.check_output(['ssh','root@'+a.host,'lua -e '+shlex.quote(code)],input=json.dumps(value).encode())
 return json.loads(raw)
if a.destroy:
 data=json.loads(a.file.read_text())
 for name in ('admin','readonly','denied'):ubus('destroy',{'ubus_rpc_session':data[name]['sid']})
 a.file.unlink();print('three ephemeral sessions destroyed')
else:
 a.file.parent.mkdir(parents=True,exist_ok=True)
 if a.file.exists():raise SystemExit('refusing to replace existing session file')
 data={'base':'http://'+a.host}
 for name in ('admin','readonly','denied'):
  sid=ubus('create',{'timeout':7200})['ubus_rpc_session'];token=secrets.token_hex(16)
  ubus('set',{'ubus_rpc_session':sid,'values':{'username':'root','token':token}})
  objects=[['luci-base','read']]
  if name!='denied':objects.append(['luci-app-mise','read'])
  if name=='admin':objects.extend([['luci-base','write'],['luci-app-mise','write']])
  ubus('grant',{'ubus_rpc_session':sid,'scope':'access-group','objects':objects})
  if name=='admin':
   for scope in ('ubus','uci','file'):ubus('grant',{'ubus_rpc_session':sid,'scope':scope,'objects':[['*','*']]})
  elif name=='readonly':
   ubus('grant',{'ubus_rpc_session':sid,'scope':'uci','objects':[[name,'read']for name in('luci','system','mise')]})
   ubus('grant',{'ubus_rpc_session':sid,'scope':'ubus','objects':[['uci','get'],['luci','getFeatures'],['session','access'],['system','board']]})
  data[name]={'sid':sid,'token':token}
 descriptor=os.open(a.file,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(descriptor,'w')as f:json.dump(data,f)
 print('three ephemeral session credentials saved privately')
