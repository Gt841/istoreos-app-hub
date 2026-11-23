#!/usr/bin/env python3
"""Exercise the shipped shell entry with isolated UCI, network, npm and procd.

No host packages/services are installed. OPENCLAWMGR_TEST_NODE selects a real
supported Node for the separate runtime-check tests and tiny fixture CLI.
"""
import hashlib
import base64
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import signal
import subprocess
import tarfile
import tempfile
import time
import unittest

APP = Path(__file__).resolve().parents[1]
ROOT = APP / 'luci-app-openclawmgr/root'
SHARE = ROOT / 'usr/share/openclawmgr'
REAL_NODE = Path(os.environ.get('OPENCLAWMGR_TEST_NODE', shutil.which('node'))).resolve()
REAL_NPM = REAL_NODE.parent / 'npm'
SEMVER = REAL_NODE.parent.parent / 'lib/node_modules/npm/node_modules/semver'
TEST_SHELL = shlex.split(os.environ.get('OPENCLAWMGR_TEST_SHELL','sh'))

MOCK = r'''#!/usr/bin/python3
import os, sys, json, shutil, hashlib, base64, tarfile, time, subprocess
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
root = Path(os.environ['MOCK_ROOT'])
base = Path(os.environ.get('MOCK_BASE',str(root/'OpenClawMgr')))
def flag(key): return os.environ.get('MOCK_'+key, '') == '1'
def event(kind, values):
 with (root/'events').open('a') as f: f.write(json.dumps([kind, values])+'\n')
def finish(code=0): sys.exit(code)
if name == 'uci':
 if 'get' not in args: finish()
 key=args[-1]
 values={'openclawmgr.main.base_dir':str(base),'openclawmgr.main.enabled':os.environ.get('MOCK_ENABLED','0'),
 'openclawmgr.main.token':'fixture-token','openclawmgr.main.install_accelerated':os.environ.get('MOCK_ACCELERATED','0'),
 'istoreenhance.@istoreenhance[0].enabled':os.environ.get('MOCK_KS_ENABLED','1'),
 'istoreenhance.@istoreenhance[0].adminport':'54321','network.lan.ipaddr':'192.0.2.1'}
 if key not in values: finish(1)
 print(values[key])
elif name == 'uname': print(os.environ.get('MOCK_ARCH','x86_64'))
elif name == 'ldd': print('musl libc' if flag('MUSL') else 'GNU libc')
elif name == 'df':
 if flag('NO_DF_INODES') and any('i' in arg for arg in args if arg.startswith('-')):
  print('df: unrecognized option: i',file=sys.stderr); finish(1)
 print('Filesystem Blocks Used Available Use% Mounted')
 print('mockdisk 10000000 1000 %s 1%% /' % ('1' if flag('NO_SPACE') else '8000000'))
elif name == 'stat': print('1000000 '+('1' if flag('NO_INODES') else '900000'))
elif name == 'id':
 if args==['-u']: print(os.getuid())
 elif args==['-g']: print(os.getgid())
 else: finish(1)
elif name == 'ip': print('default via 192.0.2.254 dev eth0')
elif name == 'sleep': time.sleep(0.02)
elif name == 'ubus':
 pid=int(os.environ['MOCK_ALIVE_PID']) if (root/'running').exists() else ''
 print(json.dumps({'openclawmgr':{'instances':{'gateway':{'pid':pid}}}}))
elif name == 'jsonfilter':
 try:
  data=json.loads(Path(args[args.index('-i')+1]).read_text() if '-i' in args else sys.stdin.read())
  for part in args[args.index('-e')+1].lstrip('@$.').split('.'): data=data[part]
  print(str(data).lower() if isinstance(data,bool) else data)
 except Exception: pass
elif name == 'lua':
 sys.stdin.read()
 if flag('CONFIG_FAIL'): finish(14)
 if os.environ.get('CFG_PATH'):
  target=Path(os.environ['CFG_PATH']); target.parent.mkdir(parents=True,exist_ok=True)
  target.write_text(json.dumps({'gateway':{'port':18789,'bind':'lan','auth':{'token':'fixture-token'},'controlUi':{}}}))
  target.with_name('openclaw.env').write_text('')
elif name == 'openclawmgr':
 event('service',args)
 if args[0]=='stop': (root/'running').unlink(missing_ok=True)
 elif args[0] in ('start','restart'):
  if flag('START_FAIL'): finish(17)
  (root/'running').write_text('running')
elif name in ('node','node.real'):
 if args[:1]==['--require']: args=args[2:]
 if args==['--version']: print('v24.22.1'); finish()
 if args and args[0].endswith('runtime-check.cjs') and args[1]=='node':
  if flag('BAD_RUNTIME'): finish(18)
  print('24.22.1'); finish()
 if args and args[0].endswith('runtime-check.cjs') and args[1]=='metadata' and flag('REUSE_ENGINE_FAIL') and (Path(sys.argv[0]).parent/'reused').exists(): finish(61)
 actual_args=sys.argv[1:] if sys.argv[1:2]==['--require'] else args
 os.execv(os.environ['MOCK_REAL_NODE'],[os.environ['MOCK_REAL_NODE']]+actual_args)
elif name == 'npm':
 event('npm',args)
 event('npm-libc',os.environ.get('npm_config_libc'))
 if args==['--version']: print('11.12.1'); finish()
 version='2026.3.28'
 tarball=root/('openclaw-'+version+'.tgz')
 integrity='sha512-'+base64.b64encode(hashlib.sha512(tarball.read_bytes()).digest()).decode()
 if args[0]=='view':
  meta={'name':'openclaw','version':version,'engines':{'node':'>=99' if flag('BAD_ENGINES') else '>=22'},'dist':{'integrity':integrity}}
  if flag('BAD_METADATA'): meta['dist']={}
  print(json.dumps(meta) if '--json' in args else version)
 elif args[0]=='pack':
  dest=Path(args[args.index('--pack-destination')+1])/tarball.name
  shutil.copyfile(tarball,dest)
  if flag('BAD_PACK'): dest.write_bytes(b'tampered')
  print(json.dumps([{'name':'openclaw','version':version,'filename':tarball.name,'integrity':integrity}]))
 elif args[0]=='install':
  if flag('GIT_DEPENDENCY'):
   subprocess.run([os.environ['npm_config_git'],'clone','https://github.com/example/fixture.git'],check=True)
  if flag('BLOCK_INSTALL'):
   child=subprocess.Popen(['/usr/bin/python3','-c','import time; time.sleep(120)'])
   (root/'blocked').write_text(json.dumps([os.getpid(),child.pid]))
   time.sleep(120)
  if flag('FAIL_WITH_CHILD'):
   child=subprocess.Popen(['/usr/bin/python3','-c','import time; time.sleep(120)'])
   (root/'failed-child').write_text(str(child.pid))
   finish(42)
  if flag('NPM_FAIL'): finish(23)
  prefix=Path(next(x.split('=',1)[1] for x in args if x.startswith('--prefix=')))
  pkg=prefix/'lib/node_modules/openclaw'; pkg.mkdir(parents=True)
  with tarfile.open(args[2]) as t:
   for member in t.getmembers():
    member.name=member.name.removeprefix('package/')
    if member.name: t.extract(member,pkg,filter='data')
  if flag('NATIVE_FAIL'):
   meta=json.loads((pkg/'package.json').read_text()); meta['dependencies']={'sharp':'1'}
   (pkg/'package.json').write_text(json.dumps(meta))
  (prefix/'bin').mkdir(); (prefix/'bin/openclaw').symlink_to('../lib/node_modules/openclaw/openclaw.mjs')
 else: finish(25)
elif name in ('curl','ks-cli'):
 event(name,args)
 if name=='ks-cli' and args[0]=='npm': os.execvp('npm',['npm']+args[1:])
 if name=='ks-cli' and args[0]=='git': finish()
 if flag('DOWNLOAD_FAIL'): finish(7)
 option='-O' if name=='ks-cli' else '-o'
 out=Path(args[args.index(option)+1])
 if flag('BLOCK_DOWNLOAD'):
  Path(str(out)+'.syn').write_bytes(b'partial-native-sidecar')
  (root/'blocked-download').write_text(str(os.getpid()))
  time.sleep(120)
 if flag('BAD_ARCHIVE'): out.write_bytes(b'tampered')
 else: shutil.copyfile(root/'node.tar.xz',out)
else: raise Exception(name)
'''

CLI = '''import fs from 'node:fs';
if (process.argv.includes('--version')) console.log(process.env.MOCK_CLI_WRONG === '1' ? 'wrong-version' : '2026.3.28');
else if (process.argv.includes('health')) {
 if (process.argv.includes('--no-color')) { console.error('unknown option --no-color'); process.exit(1); }
 if (process.env.MOCK_HEALTH_DELAY_MS) await new Promise(resolve => setTimeout(resolve,Number(process.env.MOCK_HEALTH_DELAY_MS)));
 if (process.env.MOCK_MIGRATE === '1') fs.writeFileSync(process.env.OPENCLAW_STATE_DIR+'/sentinel','new');
 if (process.env.MOCK_BLOCK_HEALTH === '1') {
  fs.writeFileSync(process.env.MOCK_ROOT+'/blocked-health',String(process.pid));
  await new Promise(resolve => setTimeout(resolve,120000));
 }
 const oldRelease = process.env.MOCK_OLD_RELEASE;
 const isOld = oldRelease && fs.realpathSync(process.argv[1]).startsWith(oldRelease+'/');
 if (process.env.MOCK_HEALTH_FAIL === '1' && !isOld) process.exitCode=19;
 else console.log('healthy');
}
'''


class Device:
    def __init__(self, prefix='.openclawmgr-test-', base_name='OpenClawMgr'):
        # The actual entry rejects /tmp and /var as installation roots. Keep the
        # tiny disposable device fixture under this repo, not a host system path.
        self.temp = tempfile.TemporaryDirectory(prefix=prefix, dir=APP)
        self.root = Path(self.temp.name)
        self.base = self.root/base_name
        self.base.mkdir()
        self.share = self.root/'share'
        shutil.copytree(SHARE, self.share)
        self.glibc = self.root/'glibc-package'
        self.glibc.mkdir()
        self.exe(self.glibc/'ld.so', '#!/bin/sh\nshift 2\nexec "$@"\n')
        (self.glibc/'SOURCE').write_text('fixture-glibc')
        manifest=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in sorted(self.glibc.iterdir()))
        (self.glibc/'SHA256SUMS').write_text(manifest)
        self.bin = self.root/'mock-bin'
        self.bin.mkdir()
        self.env = {**os.environ, 'MOCK_ROOT':str(self.root), 'MOCK_REAL_NODE':str(REAL_NODE),
                    'MOCK_BASE':str(self.base),
                    'MOCK_ALIVE_PID':str(os.getpid()), 'PATH':str(self.bin)+':'+os.environ['PATH']}
        for name in ['uci','uname','ldd','df','stat','id','ip','sleep','ubus','jsonfilter','lua','curl','ks-cli','openclawmgr']:
            self.exe(self.bin/name, MOCK)
        if os.environ.get('OPENCLAWMGR_TEST_BUSYBOX'):
            for name in ['mv','cp','ln','readlink','setsid']:
                (self.bin/name).symlink_to(os.environ['OPENCLAWMGR_TEST_BUSYBOX'])
        node_tree = self.root/'node-package/node-v24.22.1'
        self.exe(node_tree/'bin/node', MOCK)
        npm = node_tree/'lib/node_modules/npm/bin/npm-cli.js'
        self.exe(npm, MOCK.replace("name = Path(sys.argv[0]).name", "name = 'npm'"))
        (node_tree/'bin/npm').symlink_to('../lib/node_modules/npm/bin/npm-cli.js')
        (npm.parent.parent/'node_modules').mkdir()
        (npm.parent.parent/'node_modules/semver').symlink_to(SEMVER)
        with tarfile.open(self.root/'node.tar.xz','w:xz') as tar:
            tar.add(node_tree,arcname=node_tree.name)
        digest = hashlib.sha256((self.root/'node.tar.xz').read_bytes()).hexdigest()
        pins = self.share/'node-pins.sh'
        pins.write_text(re.sub(r'(?<=OC_NODE_SHA256=)[0-9a-f]{64}',digest,pins.read_text()))
        pkg = self.root/'package'
        pkg.mkdir()
        (pkg/'package.json').write_text(json.dumps({'name':'openclaw','version':'2026.3.28','dependencies':{}}))
        (pkg/'openclaw.mjs').write_text(CLI)
        with tarfile.open(self.root/'openclaw-2026.3.28.tgz','w:gz') as tar: tar.add(pkg,arcname='package')
        self.entry = self.root/'openclawmgr.sh'
        self.entry.write_text((ROOT/'usr/libexec/istorec/openclawmgr.sh').read_text())
        for file in [self.entry, self.share/'install-runtime.sh', self.share/'openclawmgr-cli.sh', self.share/'cli-bin/npm', self.share/'npm-env.sh']:
            text=file.read_text().replace('/usr/share/openclawmgr-glibc',str(self.glibc)).replace('/usr/share/openclawmgr',str(self.share))
            text=text.replace('/etc/init.d/openclawmgr',str(self.bin/'openclawmgr'))
            text=text.replace('/tmp/openclawmgr-installer.lock',str(self.root/'lock'))
            text=text.replace(':/usr/sbin:/usr/bin:/sbin:/bin',f':{self.bin}:/usr/sbin:/usr/bin:/sbin:/bin')
            text=text.replace('for source in "$old_node" /usr;', 'for source in "$old_node" /nonexistent-system-node;')
            file.write_text(text)

    @staticmethod
    def exe(path, text):
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(text)
        path.chmod(0o755)

    def run(self, action='install', **flags):
        env={**self.env,**{f'MOCK_{k}':str(v) for k,v in flags.items()}}
        if action=='upgrade' and (self.base/'current').is_symlink():
            env['MOCK_OLD_RELEASE']=str((self.base/'current').resolve())
        return subprocess.run([*TEST_SHELL,str(self.entry),action],env=env,text=True,capture_output=True,timeout=45)

    def legacy(self, running=False):
        shutil.copytree(self.root/'node-package/node-v24.22.1',self.base/'node',symlinks=True)
        pkg=self.base/'global/lib/node_modules/openclaw'
        pkg.mkdir(parents=True)
        (pkg/'openclaw.mjs').write_text("console.log('old');")
        (pkg/'package.json').write_text('{"name":"openclaw","version":"2026.1.1"}')
        state=self.base/'data/.openclaw'; state.mkdir(parents=True)
        (state/'sentinel').write_text('old')
        if running: (self.root/'running').write_text('running')

    def events(self):
        return [json.loads(x) for x in (self.root/'events').read_text().splitlines()] if (self.root/'events').exists() else []

    def close(self): self.temp.cleanup()


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.device=Device()
        self.addCleanup(self.device.close)

    def ok(self, result): self.assertEqual(result.returncode,0,result.stdout+'\n'+result.stderr)

    def test_fresh_install_commits_receipt_and_compatibility_paths(self):
        d=self.device; self.ok(d.run())
        self.assertTrue((d.base/'node/bin/node').is_file())
        self.assertEqual((d.base/'global').readlink(),Path('current/global'))
        receipt=json.loads((d.base/'current/receipt.json').read_text())
        self.assertEqual(receipt['version'],'2026.3.28')
        self.assertEqual(receipt['source'],'origin')
        self.assertEqual(len(receipt['nodeExecutableSha256']),64)
        self.assertFalse((d.root/'lock').exists())
        self.assertFalse(list(d.base.glob('.install.*')))

    def test_empty_runtime_json_does_not_block_journal_recovery(self):
        d=self.device
        state=d.base/'data/.openclaw'; state.mkdir(parents=True)
        (state/'openclaw.json').write_text('')
        txn=d.base/'.install.interrupted'; txn.mkdir()
        for name,value in {'phase':'preparing','release':'interrupted','old-current':'',
                           'old-previous':'','legacy':'','was-running':'0'}.items():
            (txn/name).write_text(value+'\n')
        self.ok(d.run('recover_install'))
        self.assertFalse(txn.exists())
        self.assertFalse((d.root/'lock').exists())

    def test_invalid_snapshot_refuses_recovery_without_moving_live_data(self):
        d=self.device; self.ok(d.run())
        old=(d.base/'current').readlink(); previous=(d.base/'previous').readlink()
        (d.base/'data/sentinel').write_text('preserve')
        failed=d.base/'releases/interrupted'; failed.mkdir()
        (d.base/'current').unlink(); (d.base/'current').symlink_to('releases/interrupted')
        backup=d.base/'backups/interrupted'; backup.mkdir(); (backup/'data.tar').write_bytes(b'')
        txn=d.base/'.install.interrupted'; txn.mkdir()
        for name,value in {'phase':'activated','release':'interrupted','old-current':str(old),
                           'old-previous':str(previous),'legacy':'','was-running':'0'}.items():
            (txn/name).write_text(value+'\n')
        result=d.run('recover_install')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('snapshot is missing or invalid',result.stdout+result.stderr)
        self.assertEqual((d.base/'data/sentinel').read_text(),'preserve')
        self.assertEqual((d.base/'current').readlink(),Path('releases/interrupted'))
        self.assertTrue(txn.exists())
        self.assertFalse((backup/'failed-data').exists())

    def test_install_is_idempotent(self):
        d=self.device; self.ok(d.run()); current=(d.base/'current').readlink()
        self.ok(d.run()); self.assertEqual((d.base/'current').readlink(),current)

    def test_latest_is_resolved_once_and_pack_uses_exact_version(self):
        d=self.device; d.env['INSTALL_CHANNEL']='latest'; self.ok(d.run())
        views=[v for k,v in d.events() if k=='npm' and v[0]=='view']
        packs=[v for k,v in d.events() if k=='npm' and v[0]=='pack']
        self.assertEqual(views,[['view','openclaw@latest','--json']])
        self.assertEqual(packs[0][1],'openclaw@2026.3.28')

    def test_download_failure_retains_exit_status(self):
        d=self.device; r=d.run(DOWNLOAD_FAIL=1)
        self.assertEqual(r.returncode,7,r.stdout+r.stderr)
        self.assertFalse((d.base/'current').exists())
        self.assertIn('exit=7',(d.base/'log/installer.log').read_text())

    def test_bad_archive_is_rejected_before_extraction(self):
        d=self.device; self.assertNotEqual(d.run(BAD_ARCHIVE=1).returncode,0)
        self.assertFalse((d.base/'current').exists())

    def test_corrupt_cached_archive_is_redownloaded(self):
        d=self.device; cache=d.base/'npm-cache'; cache.mkdir()
        (cache/'node-24.22.1-x64-glibc.tar.xz').write_bytes(b'old-invalid-cache')
        self.ok(d.run()); self.assertTrue(any(k=='curl' for k,v in d.events()))

    def test_platform_urls(self):
        for arch, musl, artifact, host in [
            ('aarch64',1,'linux-arm64.tar.xz','nodejs.org'),
            ('aarch64',0,'linux-arm64.tar.xz','nodejs.org'),
            ('x86_64',1,'linux-x64.tar.xz','nodejs.org'),
            ('x86_64',0,'linux-x64.tar.xz','nodejs.org')]:
            with self.subTest(arch=arch,musl=musl):
                d=Device(); self.addCleanup(d.close); self.ok(d.run(ARCH=arch,MUSL=musl))
                urls=[v[-1] for k,v in d.events() if k=='curl']
                self.assertIn(artifact,urls[0]); self.assertIn(host,urls[0])

    def test_missing_glibc_package_fails_before_network(self):
        d=self.device; shutil.rmtree(d.glibc)
        result=d.run()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('private glibc runtime',result.stdout)
        self.assertFalse(d.events())

    def test_corrupt_glibc_package_fails_before_network(self):
        d=self.device; (d.glibc/'SOURCE').write_text('corrupt')
        self.assertNotEqual(d.run().returncode,0)
        self.assertFalse(d.events())

    def test_committed_node_wrapper_survives_relocation_and_fork(self):
        d=self.device; self.ok(d.run())
        node=d.base/'node/bin/node'
        env={**d.env,'PATH':str(node.parent)+':'+d.env['PATH']}
        child=d.base/'fork-child.cjs'
        child.write_text("process.send(process.execPath,()=>process.disconnect());")
        code="const c=require('node:child_process').fork(process.argv[1],[],{stdio:['ignore','inherit','inherit','ipc']});c.on('message',m=>console.log(m));c.on('exit',n=>{process.exitCode=n;});"
        r=subprocess.run([str(node),'-e',code,str(child)],env=env,text=True,capture_output=True,timeout=10)
        self.ok(r)
        self.assertIn('/releases/',r.stdout)
        self.assertNotIn('/.install.',r.stdout)

    def test_runtime_package_update_keeps_previous_glibc_isolated(self):
        d=self.device; self.ok(d.run())
        (d.glibc/'SOURCE').write_text('fixture-glibc-updated')
        manifest=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in sorted(d.glibc.iterdir()) if p.name!='SHA256SUMS')
        (d.glibc/'SHA256SUMS').write_text(manifest)
        self.ok(d.run('upgrade'))
        self.assertEqual((d.base/'current/node/glibc/SOURCE').read_text(),'fixture-glibc-updated')
        self.assertEqual((d.base/'previous/node/glibc/SOURCE').read_text(),'fixture-glibc')

    def test_musl_host_forces_glibc_optional_dependencies(self):
        d=self.device; self.ok(d.run(MUSL=1))
        values=[v for kind,v in d.events() if kind=='npm-libc']
        self.assertTrue(values)
        self.assertEqual(set(values),{'glibc'})
        r=subprocess.run([str(d.base/'node/bin/node'),'-p','process.env.npm_config_libc'],env=d.env,text=True,capture_output=True,timeout=10)
        self.ok(r); self.assertEqual(r.stdout.strip(),'glibc')

    def test_unsupported_architecture_fails_before_network(self):
        d=self.device; self.assertNotEqual(d.run(ARCH='mips').returncode,0)
        self.assertFalse(d.events())

    def test_insufficient_space_fails_before_network(self):
        d=self.device; self.assertNotEqual(d.run(NO_SPACE=1).returncode,0)
        self.assertFalse(d.events())

    def test_openwrt_df_without_inode_option_uses_stat(self):
        self.ok(self.device.run(NO_DF_INODES=1))

    def test_insufficient_inodes_fails_before_network(self):
        d=self.device; self.assertNotEqual(d.run(NO_INODES=1).returncode,0)
        self.assertFalse(d.events())

    def test_acceleration_uses_ks_cli_and_custom_admin_port(self):
        d=self.device; self.ok(d.run(ACCELERATED=1))
        calls=[v for k,v in d.events() if k=='ks-cli']
        self.assertTrue(any(v[0]=='download' and 'http://127.0.0.1:54321' in v for v in calls))
        self.assertTrue(any(v[:2]==['npm','install'] for v in calls))
        self.assertFalse(any(k=='curl' for k,v in d.events()))

    def test_disabled_accelerator_is_not_started(self):
        d=self.device; self.assertNotEqual(d.run(ACCELERATED=1,KS_ENABLED=0).returncode,0)
        self.assertFalse(d.events())

    def test_npm_failure_preserves_old_runtime_and_service(self):
        d=self.device; d.legacy(running=True); result=d.run('upgrade',NPM_FAIL=1)
        self.assertEqual(result.returncode,23,result.stdout+result.stderr)
        self.assertEqual(json.loads((d.base/'global/lib/node_modules/openclaw/package.json').read_text())['version'],'2026.1.1')
        self.assertTrue((d.root/'running').exists())
        self.assertFalse(any(k=='service' for k,v in d.events()))

    def test_engine_failure_preserves_old_runtime(self):
        d=self.device; d.legacy(); self.assertNotEqual(d.run('upgrade',BAD_ENGINES=1).returncode,0)
        self.assertFalse((d.base/'current').exists())

    def test_pack_tampering_preserves_old_runtime(self):
        d=self.device; d.legacy(); self.assertNotEqual(d.run('upgrade',BAD_PACK=1).returncode,0)
        self.assertFalse(any(k=='service' for k,v in d.events()))

    def test_missing_required_native_module_prevents_activation(self):
        d=self.device; d.legacy(); self.assertNotEqual(d.run('upgrade',NATIVE_FAIL=1).returncode,0)
        self.assertFalse(any(k=='service' for k,v in d.events()))

    def test_successful_legacy_upgrade_keeps_previous_and_data_backup(self):
        d=self.device; d.legacy(running=True); self.ok(d.run('upgrade'))
        self.assertEqual(json.loads((d.base/'previous/global/lib/node_modules/openclaw/package.json').read_text())['version'],'2026.1.1')
        self.assertEqual((d.base/'data/.openclaw/sentinel').read_text(),'old')
        self.assertTrue(list((d.base/'backups').glob('*/data.tar')))
        self.assertTrue((d.root/'running').exists())

    def test_health_failure_restores_legacy_runtime_and_snapshot(self):
        d=self.device; d.legacy(running=True); r=d.run('upgrade',HEALTH_FAIL=1,MIGRATE=1)
        self.assertNotEqual(r.returncode,0)
        self.assertFalse((d.base/'current').exists())
        self.assertFalse((d.base/'global').is_symlink())
        self.assertEqual((d.base/'data/.openclaw/sentinel').read_text(),'old')
        self.assertTrue(list((d.base/'backups').glob('*/failed-data/.openclaw/sentinel')))
        self.assertTrue((d.root/'running').exists())

    def test_slow_cold_health_cli_can_commit(self):
        d=self.device
        self.ok(d.run(ENABLED=1,HEALTH_DELAY_MS=11000))
        self.assertTrue((d.base/'current/receipt.json').is_file())
        self.assertTrue((d.root/'running').exists())

    def test_configuration_failure_restores_old_runtime(self):
        d=self.device; d.legacy(running=True); self.assertNotEqual(d.run('upgrade',CONFIG_FAIL=1).returncode,0)
        self.assertTrue((d.root/'running').exists())
        self.assertFalse((d.base/'global').is_symlink())

    def test_recovery_can_be_retried_after_service_restore_failure(self):
        d=self.device; d.legacy(running=True)
        self.assertNotEqual(d.run('upgrade',START_FAIL=1).returncode,0)
        self.assertTrue(list(d.base.glob('.install.*')))
        self.ok(d.run('recover_install'))
        self.assertTrue((d.root/'running').exists())
        self.assertEqual((d.base/'data/.openclaw/sentinel').read_text(),'old')
        self.assertFalse(list(d.base.glob('.install.*')))

    def test_continuous_upgrades_and_failed_upgrade_preserve_both_pointers(self):
        d=self.device; self.ok(d.run()); first=(d.base/'current').readlink()
        self.ok(d.run('upgrade',ENABLED=1)); second=(d.base/'current').readlink()
        self.assertNotEqual(first,second); self.assertEqual((d.base/'previous').readlink(),first)
        self.assertNotEqual(d.run('upgrade',HEALTH_FAIL=1,ENABLED=1).returncode,0)
        self.assertEqual((d.base/'current').readlink(),second)
        self.assertEqual((d.base/'previous').readlink(),first)
        self.assertFalse(list(d.base.glob('.install.*')))

    def test_reused_node_that_fails_engines_falls_back_to_pinned_node(self):
        d=self.device; self.ok(d.run()); (d.base/'node/bin/reused').write_text('older-node'); (d.root/'events').unlink()
        self.ok(d.run('upgrade',REUSE_ENGINE_FAIL=1))
        self.assertFalse((d.base/'node/bin/reused').exists())
        self.assertEqual(len([v for k,v in d.events() if k=='npm' and v[0]=='view']),1)

    def test_invalid_runtime_and_missing_integrity_prevent_activation(self):
        d=self.device
        self.assertNotEqual(d.run(BAD_RUNTIME=1).returncode,0)
        self.assertNotEqual(d.run(BAD_METADATA=1).returncode,0)
        self.assertFalse((d.base/'current').exists())

    def test_wrong_cli_version_prevents_activation(self):
        d=self.device; self.assertNotEqual(d.run(CLI_WRONG=1).returncode,0)
        self.assertFalse((d.base/'current').exists())

    def test_paths_with_spaces(self):
        d=Device(base_name='OpenClaw Manager'); self.addCleanup(d.close)
        self.ok(d.run())
        self.assertTrue((d.base/'current/receipt.json').is_file())

    def test_snapshot_permissions(self):
        d=self.device; self.ok(d.run())
        self.assertEqual((d.base/'backups').stat().st_mode & 0o777,0o700)
        self.assertEqual((d.base/'data/.openclaw/openclaw.json').stat().st_mode & 0o777,0o600)

    def test_interactive_npm_shim_survives_exec_without_recursion(self):
        d=self.device; self.ok(d.run())
        result=subprocess.run([*TEST_SHELL,str(d.share/'openclawmgr-cli.sh'),'cli-env'],
            env={**d.env,'MOCK_ACCELERATED':'1'},input='npm --version\nexit\n',capture_output=True,text=True,timeout=12)
        self.ok(result)
        self.assertIn(['ks-cli',['npm','--version']],d.events())
        self.assertFalse((d.base/'data/.gitconfig').exists())

    def test_npm_git_dependencies_use_explicit_adapter(self):
        d=self.device; self.ok(d.run(ACCELERATED=1,GIT_DEPENDENCY=1))
        self.assertIn(['ks-cli',['git','clone','https://github.com/example/fixture.git']],d.events())

    def test_start_and_apply_propagate_failures(self):
        d=self.device; self.ok(d.run())
        self.assertNotEqual(d.run('start',START_FAIL=1).returncode,0)
        self.assertNotEqual(d.run('apply_config',CONFIG_FAIL=1,ENABLED=1).returncode,0)

    def test_hard_interruption_after_activation_recovers_snapshot(self):
        d=self.device; d.legacy(running=True)
        proc=subprocess.Popen([*TEST_SHELL,str(d.entry),'upgrade'],env={**d.env,'MOCK_BLOCK_HEALTH':'1','MOCK_MIGRATE':'1'},
                              stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        pgid=None
        try:
            deadline=time.monotonic()+12
            while not (d.root/'blocked-health').exists() and time.monotonic()<deadline: time.sleep(.05)
            self.assertTrue((d.root/'blocked-health').exists())
            pgid=os.getpgid(int((d.root/'blocked-health').read_text()))
            proc.kill(); proc.wait(timeout=5)
            os.killpg(pgid,signal.SIGKILL); pgid=None
            self.assertNotEqual(d.run('install').returncode,0)
            self.ok(d.run('recover_install'))
            self.assertEqual((d.base/'data/.openclaw/sentinel').read_text(),'old')
            self.assertFalse((d.base/'global').is_symlink())
            self.assertTrue((d.root/'running').exists())
        finally:
            if pgid:
                try: os.killpg(pgid,signal.SIGKILL)
                except ProcessLookupError: pass
            if proc.poll() is None: proc.kill(); proc.wait(timeout=5)

    def test_uninstall_removes_managed_runtime_but_retains_data(self):
        d=self.device; self.ok(d.run()); self.ok(d.run('uninstall'))
        self.assertFalse((d.base/'releases').exists())
        self.assertTrue((d.base/'data').exists())

    def test_cancellation_joins_npm_children_and_preserves_old_runtime(self):
        d=self.device; d.legacy(running=True)
        proc=subprocess.Popen([*TEST_SHELL,str(d.entry),'upgrade'],env={**d.env,'MOCK_BLOCK_INSTALL':'1'},stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            deadline=time.monotonic()+12
            while not (d.root/'blocked').exists() and time.monotonic()<deadline: time.sleep(.05)
            self.assertTrue((d.root/'blocked').exists())
            pids=json.loads((d.root/'blocked').read_text())
            self.ok(d.run('cancel_install'))
            self.assertEqual(proc.wait(timeout=15),143)
            for pid in pids:
                stat=Path(f'/proc/{pid}/stat')
                self.assertTrue(not stat.exists() or stat.read_text().split()[2]=='Z',f'child {pid} is still running')
            self.assertTrue((d.root/'running').exists())
            self.assertFalse((d.root/'lock').exists())
        finally:
            if proc.poll() is None: proc.terminate(); proc.wait(timeout=15)

    def test_cancelled_download_cleans_native_sidecars(self):
        d=self.device
        proc=subprocess.Popen([*TEST_SHELL,str(d.entry),'install'],
            env={**d.env,'MOCK_BLOCK_DOWNLOAD':'1','MOCK_ACCELERATED':'1'},stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            deadline=time.monotonic()+10
            while not (d.root/'blocked-download').exists() and time.monotonic()<deadline: time.sleep(.05)
            self.assertTrue((d.root/'blocked-download').exists())
            self.ok(d.run('cancel_install'))
            self.assertEqual(proc.wait(timeout=15),143)
            self.assertFalse(list(d.base.rglob('*.syn')))
            self.assertFalse(list(d.base.glob('.install.*')))
        finally:
            if proc.poll() is None: proc.terminate(); proc.wait(timeout=15)

    def test_failed_wrapper_joins_its_remaining_native_child(self):
        d=self.device; d.legacy(running=True)
        result=d.run('upgrade',FAIL_WITH_CHILD=1)
        self.assertEqual(result.returncode,42,result.stdout+result.stderr)
        pid=int((d.root/'failed-child').read_text())
        stat=Path(f'/proc/{pid}/stat')
        self.assertTrue(not stat.exists() or stat.read_text().split()[2]=='Z')
        self.assertTrue((d.root/'running').exists())


class RuntimeChecks(unittest.TestCase):
    def check(self, *args):
        return subprocess.run([str(REAL_NODE),str(SHARE/'runtime-check.cjs'),*map(str,args)],text=True,capture_output=True,timeout=20)

    def test_real_node_sqlite_round_trip(self):
        r=self.check('node','x64')
        self.assertEqual(r.returncode,0,r.stderr)

    def test_wrong_architecture_is_rejected(self):
        self.assertNotEqual(self.check('node','arm64').returncode,0)

    def test_wrong_libc_is_rejected(self):
        self.assertNotEqual(self.check('node','x64','musl').returncode,0)

    def sqlite_vec_fixture(self, version):
        temporary=tempfile.TemporaryDirectory(prefix='openclawmgr-native-')
        self.addCleanup(temporary.cleanup)
        root=Path(temporary.name); global_dir=root/'global'
        pkg=global_dir/'lib/node_modules/openclaw'; module=pkg/'node_modules/sqlite-vec'
        module.mkdir(parents=True)
        (pkg/'package.json').write_text(json.dumps({'name':'openclaw','version':version,'dependencies':{'sqlite-vec':'0.1.7'}}))
        (module/'index.js').write_text("exports.load = () => { throw new Error('fixture unsupported native symbol'); };\n")
        metadata=root/'metadata.json'; metadata.write_text(json.dumps({'version':version}))
        return global_dir,metadata

    def test_stable_requires_sqlite_vec_instead_of_silently_degrading(self):
        global_dir,metadata=self.sqlite_vec_fixture('2026.3.28')
        result=self.check('native',global_dir,metadata)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('unsupported native symbol',result.stderr)

    def test_unreviewed_version_cannot_silently_skip_sqlite_vec(self):
        global_dir,metadata=self.sqlite_vec_fixture('2099.1.1')
        result=self.check('native',global_dir,metadata)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('unsupported native symbol',result.stderr)

    def pty_fixture(self, version):
        global_dir,metadata=self.sqlite_vec_fixture(version)
        pkg=global_dir/'lib/node_modules/openclaw'
        (pkg/'package.json').write_text(json.dumps({'name':'openclaw','version':version,'dependencies':{'@lydell/node-pty':'1'}}))
        module=pkg/'node_modules/@lydell/node-pty'; module.mkdir(parents=True)
        (module/'index.js').write_text("throw new Error('fixture missing pty native module');")
        return global_dir,metadata

    def test_verified_stable_records_pty_fallback_capability(self):
        global_dir,metadata=self.pty_fixture('2026.3.28')
        result=self.check('native',global_dir,metadata)
        self.assertEqual(result.returncode,0,result.stderr)
        capabilities=json.loads(result.stdout)
        self.assertFalse(capabilities['nodePty']['available'])
        self.assertTrue(capabilities['childProcess']['available'])

    def test_unreviewed_version_cannot_silently_skip_pty(self):
        global_dir,metadata=self.pty_fixture('2099.1.1')
        result=self.check('native',global_dir,metadata)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('missing pty native module',result.stderr)

    @unittest.skipUnless(os.environ.get('OPENCLAWMGR_TEST_VEC'), 'Set OPENCLAWMGR_TEST_VEC for real extension query test')
    def test_real_sqlite_vec_nearest_neighbor(self):
        global_dir,metadata=self.sqlite_vec_fixture('2026.3.28')
        module=global_dir/'lib/node_modules/openclaw/node_modules/sqlite-vec'
        shutil.rmtree(module); module.symlink_to(Path(os.environ['OPENCLAWMGR_TEST_VEC']).resolve(),target_is_directory=True)
        result=self.check('native',global_dir,metadata)
        self.assertEqual(result.returncode,0,result.stderr)
        check=json.loads(result.stdout)['sqliteVec']
        self.assertTrue(check['available'])
        self.assertTrue(check['nearestNeighbor'])
        self.assertEqual(check['version'],'v0.1.7')

    def test_new_npm_receives_allow_scripts_without_disabling_other_scripts(self):
        self.assertEqual(self.check('scripts','11.16.0',REAL_NPM).stdout.strip(),'--allow-scripts=openclaw')
        self.assertEqual(self.check('scripts','11.15.0',REAL_NPM).stdout.strip(),'')

    def test_openwrt_package_contract(self):
        recipe=(APP/'luci-app-openclawmgr/Makefile').read_text()
        for dep in ['+openclawmgr-glibc','+ks-cli','+coreutils-timeout','+coreutils-stat','+libstdcpp','+libatomic','+git-http']:
            self.assertIn(dep,recipe)
        self.assertIn('PKG_RELEASE:=3',(APP/'app-meta-openclawmgr/Makefile').read_text())
        self.assertTrue(os.access(SHARE/'cli-bin/npm',os.X_OK))
        self.assertTrue(os.access(SHARE/'npm-git.sh',os.X_OK))


if __name__=='__main__': unittest.main(verbosity=2)
