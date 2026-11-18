import hashlib,io,json,os,re,subprocess,tarfile,tempfile,unittest,urllib.request
from pathlib import Path
H=Path(__file__).resolve().parents[3]
F=Path(__file__).parent/'fixtures'
class Contract(unittest.TestCase):
 def test_openwrt_install_recipes_use_tabs(self):
  for relative,name in [
   ('apps/changeguard/changeguard/Makefile','changeguard'),
   ('apps/linkspace/linkspace/Makefile','linkspace'),
  ]:
   recipe=(H/relative).read_text()
   match=re.search(r'^define Package/'+re.escape(name)+r'/install\n(.*?)^endef$',recipe,re.M|re.S)
   self.assertIsNotNone(match,relative)
   for line in match.group(1).splitlines():
    if line.strip():
     self.assertTrue(line.startswith('\t'),f'{relative}: install recipe must start with a TAB: {line!r}')

 def test_runtime_packages_use_formal_immutable_release(self):
  for relative,name,tag in [
   ('apps/changeguard/changeguard/Makefile','changeguard','changeguard-runtime-v$(PKG_VERSION)'),
   ('apps/linkspace/linkspace/Makefile','linkspace','linkspace-runtime-v$(PKG_VERSION)'),
  ]:
   recipe=(H/relative).read_text()
   self.assertIsNotNone(re.search(r'^PKG_VERSION:=0\.3\.2$',recipe,re.M),relative)
   self.assertIsNotNone(re.search(r'^PKG_RELEASE:=1$',recipe,re.M),relative)
   self.assertIn(f'PKG_SOURCE_URL:=https://github.com/istoreos/istoreos-app-hub/releases/download/{tag}/',recipe)
   self.assertNotIn('-cg1',recipe)
   hashes=(H/f'apps/{name}/{name}/release.mk').read_text()
   self.assertNotIn('not publicly published',hashes)
   self.assertIsNotNone(re.search(rf'^{name.upper()}_HASH_x86_64:=[0-9a-f]{{64}}$',hashes,re.M),relative)
   self.assertIsNotNone(re.search(rf'^{name.upper()}_HASH_aarch64:=[0-9a-f]{{64}}$',hashes,re.M),relative)

 @unittest.skipUnless(os.environ.get('CG_VERIFY_PUBLIC_RELEASE'),'explicit public release verification required')
 def test_public_runtime_assets_match_recipe_hashes_and_layout(self):
  for name,tag,executable in [
   ('changeguard','changeguard-runtime-v0.3.2','changeguard_bin'),
   ('linkspace','linkspace-runtime-v0.3.2','linkspace'),
  ]:
   hashes=(H/f'apps/{name}/{name}/release.mk').read_text()
   for arch in ['x86_64','aarch64']:
    expected=re.search(rf'^{name.upper()}_HASH_{arch}:=([0-9a-f]{{64}})$',hashes,re.M).group(1)
    url=f'https://github.com/istoreos/istoreos-app-hub/releases/download/{tag}/{name}-0.3.2-{arch}.tar.gz'
    with urllib.request.urlopen(url,timeout=60) as response:
     body=response.read()
     self.assertEqual(response.status,200,url)
    self.assertEqual(hashlib.sha256(body).hexdigest(),expected,url)
    with tarfile.open(fileobj=io.BytesIO(body),mode='r:gz') as package:
     names=package.getnames()
    self.assertIn(f'./{name}-0.3.2/{executable}',names,url)
    self.assertEqual(f'./{name}-0.3.2/dependency.json' in names,name=='linkspace',url)

 def test_headless_dependencies_and_one_product_identity(self):
  self.assertIn('+linkspace',(H/'apps/changeguard/changeguard/Makefile').read_text())
  self.assertIn('+changeguard',(H/'apps/kaiplus/kaiplus/Makefile').read_text())
  meta=(H/'apps/optimemachine/app-meta-optimemachine/Makefile').read_text()
  self.assertIn('META_TITLE:=变更保护',meta);self.assertNotIn('/admin/system/optimemachine',meta)
  self.assertFalse((H/'apps/changeguard/app-meta-changeguard').exists())
  self.assertFalse(list((H/'apps/changeguard/changeguard/files').rglob('*plugin.json')))

 def test_custom_entries_survive_obsolete_file_collection(self):
  helper=H/'apps/changeguard/changeguard/files/usr/libexec/changeguard-package'
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);custom=root/'usr/share/linkease/apps.d/25-optimemachine.json';custom.parent.mkdir(parents=True)
   custom.write_text('{"id":"user-modified-entry"}\n')
   known=root/'usr/share/luci/menu.d/luci-app-optimemachine.json';known.parent.mkdir(parents=True);known.write_bytes((F/'legacy-menu.json').read_bytes())
   link=root/'usr/share/linkeasefull/desktop-apps.d/25-optimemachine.json';link.parent.mkdir(parents=True);link.symlink_to('/usr/share/optimemachine/optimemachine-plugin.json')
   backup=root/'etc/optimemachine/state/keep';backup.parent.mkdir(parents=True);backup.write_text('retained history')
   rc=root/'etc/rc.d/S15optimemachine';rc.parent.mkdir(parents=True);rc.symlink_to('../init.d/optimemachine')
   user_rc=root/'etc/rc.d/K89optimemachine';user_rc.symlink_to('/custom/service')
   env={**os.environ,'IPKG_INSTROOT':str(root)}
   subprocess.run(['sh',str(helper),'preinst'],env=env,check=True)
   custom.unlink() # An old package collects its obsolete owned path.
   subprocess.run(['sh',str(helper),'postinst'],env=env,check=True)
   self.assertEqual(custom.read_text(),'{"id":"user-modified-entry"}\n')
   self.assertFalse(known.exists());self.assertFalse(link.is_symlink());self.assertEqual(backup.read_text(),'retained history');self.assertFalse(rc.is_symlink());self.assertEqual(os.readlink(user_rc),'/custom/service')
   subprocess.run(['sh',str(helper),'postinst'],env=env,check=True)
   self.assertEqual(custom.read_text(),'{"id":"user-modified-entry"}\n')

 def test_unknown_broken_link_preserved(self):
  helper=H/'apps/changeguard/changeguard/files/usr/libexec/changeguard-package'
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);custom=root/'usr/share/linkease/apps.d/25-optimemachine.json';custom.parent.mkdir(parents=True);custom.symlink_to('/user/custom-missing.json')
   env={**os.environ,'IPKG_INSTROOT':str(root)}
   subprocess.run(['sh',str(helper),'preinst'],env=env,check=True);custom.unlink()
   subprocess.run(['sh',str(helper),'postinst'],env=env,check=True)
   self.assertEqual(os.readlink(custom),'/user/custom-missing.json')

 @unittest.skipUnless(os.environ.get('CG_CANDIDATE_PACKAGES'),'explicit candidate packages required')
 def test_actual_package_ownership_and_offline_hooks(self):
  report=json.loads(Path(os.environ['CG_CANDIDATE_PACKAGES']).read_text())
  for name,item in report['packages'].items():
   with self.subTest(name=name),tarfile.open(item['path'],'r:gz') as outer:
    control=tarfile.open(fileobj=io.BytesIO(outer.extractfile('./control.tar.gz').read()),mode='r:gz')
    data=tarfile.open(fileobj=io.BytesIO(outer.extractfile('./data.tar.gz').read()),mode='r:gz');names=data.getnames()
    self.assertEqual('./usr/share/linkspace/dependency.json' in names,name=='linkspace')
    self.assertNotIn('./usr/share/optimemachine/dependency.json',names)
    self.assertFalse(any('/luci/menu.d/' in n or n.endswith('optimemachine-plugin.json') for n in names))
    self.assertEqual('./usr/sbin/changeguard_bin' in names,name=='changeguard')
    self.assertNotIn('./etc/changeguard/config.json',names) # Generated once, never package-owned.
    with tempfile.TemporaryDirectory() as directory:
     root=Path(directory);data.extractall(root,filter='fully_trusted')
     if name in ['changeguard','optimemachine','luci-app-optimemachine']:
      # Offline postinst uses the new owning helper, as in coordinated unpack.
      helper=root/'usr/libexec/changeguard-package';helper.parent.mkdir(parents=True,exist_ok=True)
      helper.write_bytes((H/'apps/changeguard/changeguard/files/usr/libexec/changeguard-package').read_bytes());helper.chmod(0o755)
     keep=root/'existing-backup';keep.write_text('preserved')
     for phase in ['preinst','postinst','prerm']:
      try:body=control.extractfile('./'+phase).read()
      except KeyError:continue
      script=root/(phase+'.sh');script.write_bytes(body);subprocess.run(['sh','-n',str(script)],check=True)
      subprocess.run(['sh',str(script)],env={**os.environ,'IPKG_INSTROOT':str(root)},check=True)
     self.assertEqual(keep.read_text(),'preserved')
if __name__=='__main__':unittest.main()
