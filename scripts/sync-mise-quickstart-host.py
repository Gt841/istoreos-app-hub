#!/usr/bin/env python3
"""Copy the actual QuickStart design host and its direct UI dependencies."""
import argparse,hashlib,json,pathlib,subprocess
parser=argparse.ArgumentParser();parser.add_argument('--source',type=pathlib.Path,required=True);a=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];target=root/'apps/mise/web/src/quickstart'
files=['design/IStoreHostShellPrototype.vue','design/istoreHostShellPrototype.css','design/shell.css','home/ThemeSelector.vue','utils/theme.ts','home/homeSemanticColors.css','home/homeTypography.css']
manifest={'source':'quickstart/web/src','policy':'Full files copied. Host Vue only adds mise to service navigation; CSS/theme code is unchanged.','files':[]}
manifest['sourceCommit']=subprocess.check_output(['git','-C',str(a.source),'rev-parse','HEAD'],text=True).strip()
for name in files:
 source=a.source/'web/src'/name;raw=source.read_bytes();text=raw.decode();adaptations=[]
 if name=='design/IStoreHostShellPrototype.vue':
  patches=[("current:item.id==='storage'&&storagePage", "current:(item.id==='storage'&&storagePage)||(item.id==='services'&&route.path==='/mise')"),
  ("children:[{label:'服务设置',path:'/design/system/services'}]", "children:[{label:'运行时环境',path:'/mise'},{label:'服务设置',path:'/design/system/services'}]"),
  ("watch(()=>route.path,path=>{", "watch(()=>route.path,path=>{if(path==='/mise'&&!expanded.value.includes('services'))expanded.value.push('services');")]
  for old,new in patches:
   if text.count(old)!=1:raise SystemExit('Source changed; review navigation patch: '+old)
   text=text.replace(old,new);adaptations.append({'before':old,'after':new})
 p=target/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
 manifest['files'].append({'path':name,'sourceSha256':hashlib.sha256(raw).hexdigest(),'copiedSha256':hashlib.sha256(p.read_bytes()).hexdigest(),'adaptations':adaptations})
(target/'LICENSE').write_bytes((a.source/'LICENSE').read_bytes())
(target/'sources.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Copied full QuickStart host files:',len(files))
