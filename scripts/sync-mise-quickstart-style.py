#!/usr/bin/env python3
"""Vendor reviewed QuickStart CSS; change selector scope, never declaration values."""
import argparse,hashlib,json,pathlib,re,subprocess
parser=argparse.ArgumentParser();parser.add_argument('--source',type=pathlib.Path,required=True);args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];target=root/'apps/mise/web/src/styles/quickstart';target.mkdir(parents=True,exist_ok=True)
manifest={'source':'quickstart/web','files':[],'policy':'Declarations copied verbatim. Only selector scope/aliases adapted; build has no checkout dependency.'}
try:manifest['commit']=subprocess.check_output(['git','-C',str(args.source),'rev-parse','HEAD'],text=True).strip()
except subprocess.CalledProcessError:pass
def source(name):
 p=args.source/name;s=p.read_text();manifest['files'].append({'path':name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()});return s
def style(name):return re.search(r'<style[^>]*>(.*?)</style>',source(name),re.S).group(1).strip()+'\n'
semantic=source('web/src/home/homeSemanticColors.css')
blocks=re.findall(r'([^{}]+)\{([^{}]+)\}',semantic)
light=next(body for selector,body in blocks if '--c-bg:#f3f5f7' in body)
dark=next(body for selector,body in blocks if '--c-bg:#191d24' in body)
(target/'palette.css').write_text('/* Exact production QuickStart semantic declarations; scoped to the product. */\n.mise-surface{'+light+'}\n.mise-surface[data-theme=dark]{'+dark+'}\n')
layout=style('web/src/pages/device/index.vue')
for old,new in [('.device-management','.runtime-product'),('.scope-heading','.page-heading'),('.primary-tabs','.tabs'),('.primary-content','.primary-content'),('.primary-tabs button.active','.tabs button.selected')]:layout=layout.replace(old,new)
layout=layout.replace('.tabs button.active','.tabs button.selected')
# Keep existing local component boundary; every rule is scoped by Vue SFC.
(target/'workspace.css').write_text('/* QuickStart device/index.vue scoped style; selectors adapted for mise. */\n'+layout)
card=style('web/src/pages/index/components/Card.vue');(target/'card.css').write_text(card)
dialog=style('web/src/home/NetworkWidgetDialog.vue')
for old,new in [('.network-dialog-shade','.mise-dialog-shade'),('.network-dialog-body','.dialog-body'),('.network-dialog-actions','.dialog-actions'),('.network-dialog','.mise-dialog')]:dialog=dialog.replace(old,new)
(target/'dialog.css').write_text('/* QuickStart NetworkWidgetDialog.vue; selector aliases only. */\n'+dialog)
device=source('web/src/pages/device/deviceVisualTokens.css')
sets=re.findall(r'([^{}]+)\{([^{}]+)\}',device)
light_device=next(body for selector,body in sets if '--device-panel:#fff' in body)
dark_device=next(body for selector,body in sets if '--device-panel:#2c2c2c' in body)
with (target/'palette.css').open('a') as f:f.write('\n.mise-surface{'+light_device+'}\n.mise-surface[data-theme=dark]{'+dark_device+'}\n')
center=style('web/src/pages/device/deviceCenterList.vue')
secondary=re.search(r'\.policy-action button, \.secondary-button\s*\{([^}]+)\}',center).group(1)
primary=re.search(r'\.add-device\s*\{([^}]+)\}',center).group(1)
(target/'buttons.css').write_text('/* Exact deviceCenterList declarations; semantic variables mapped to the same palette. */\n.mise-surface button{'+secondary+'}\n.mise-surface button.primary{'+primary+'}\n')
source('web/src/design/istoreHostShellPrototype.css')
(target/'sources.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Vendored QuickStart declaration sets:',len(manifest['files']))
