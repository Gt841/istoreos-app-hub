#!/usr/bin/env python3
"""Compare real build locks with archived configuration and verified SDK defaults."""
import argparse,hashlib,json,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--arch',choices=['x64','arm64'],required=True);p.add_argument('--profile');p.add_argument('--sdk-defaults',type=Path,required=True);p.add_argument('--patch-sha',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
def env(path):return{key:value.strip().strip('"')for line in path.read_text().splitlines()if line and not line.startswith('#')and'='in line for key,value in[line.split('=',1)]}
def feeds(text):
 result={}
 for line in text.splitlines():
  parts=line.split()
  if not parts or not parts[0].startswith('src-git'):continue
  index=2 if parts[1].startswith('--')else 1
  result[parts[index]]=parts[index+1]
 return result
profile=env(a.directory/('input/'+(a.profile or 'mise-runtime-'+a.arch)+'.env'));build=env(a.directory/'build.env')
source=feeds((a.directory/'input'/Path(profile['FEEDS_CONFIG']).name).read_text());defaults=feeds(a.sdk_defaults.read_text());source.update({key:defaults[key]for key in('base','luci')});source['base']=re.split(r'[;^]',source['base'])[0]+'^'+profile['BASE_FEED_COMMIT']
expected={}
for name,spec in source.items():
 origin,pin=spec.split('^');assert re.fullmatch('[0-9a-f]{40}',pin)
 expected[name]={'origin':origin,'commit':pin}
actual={parts[1]:{'commit':parts[2],'origin':parts[3]}for line in(a.directory/'feeds.lock.tsv').read_text().splitlines()if(parts:=line.split('\t'))}
checks=[{'name':name,'expected':value,'actual':actual.get(name),'passed':actual.get(name)==value}for name,value in expected.items()]
checks.append({'name':'feed-set','passed':actual.keys()==expected.keys()})
checks.append({'name':'successful build','passed':(a.directory/'build.status').read_text().strip()=='status=success'})
platform=env(a.directory/'input'/str(profile['PLATFORM']+'.env'))
checks.append({'name':'SDK and architecture','passed':build['ipk_sdk']==platform['IPK_SDK_NAME']and build['ipk_arch']==platform['IPK_SDK_ARCH']and build['ipk_sdk_sha256']==platform['IPK_SDK_SHA256']})
checks.append({'name':'package selection','passed':build['packages']==profile['PACKAGES']})
patch=a.directory/'input/profile-patches/mise-runtime-candidate.patch';checks.append({'name':'candidate patch','passed':hashlib.sha256(patch.read_bytes()).hexdigest()==a.patch_sha})
report={'passed':all(c['passed']for c in checks),'build_id':a.directory.name,'checks':checks};a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'build_id':report['build_id'],'passed':report['passed'],'failed':[c['name']for c in checks if not c['passed']]}));raise SystemExit(0 if report['passed']else 1)
