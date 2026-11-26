import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import unittest
import urllib.request
import zipfile

APP = Path(__file__).resolve().parents[1]
HUB = APP.parents[1]


class FreshInstall(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("KAI_VERIFY_PUBLIC_RELEASE") or os.environ.get("KAI_RUNTIME_RELEASE_DIR"), "public or local release verification required")
    def test_published_binaries_match_recipe_version_hash_and_source(self):
        recipe = (APP / "kaiplus/Makefile").read_text()
        version = re.search(r"^PKG_VERSION:=(.+)$", recipe, re.MULTILINE).group(1)
        base = f"https://github.com/istoreos/istoreos-app-hub/releases/download/kaiplus-runtime-v{version}/"
        def read_release(name):
            if os.environ.get("KAI_RUNTIME_RELEASE_DIR"):
                return (Path(os.environ["KAI_RUNTIME_RELEASE_DIR"]) / name).read_bytes()
            with urllib.request.urlopen(base + name, timeout=120) as response:
                return response.read()
        manifest = json.loads(read_release("release.json"))
        self.assertEqual(manifest["version"], version)
        name = f"kaiplus-binary-{version}.tar.gz"
        package = read_release(name)
        expected = re.search(r"^KAIPLUS_HASH:=([0-9a-f]{64})$", recipe, re.MULTILINE).group(1)
        self.assertEqual(hashlib.sha256(package).hexdigest(), expected)
        self.assertEqual(next(item for item in manifest["packages"] if item["file"] == name)["sha256"], expected)
        prefix = f"kaiplus-binary-{version}/"
        with tarfile.open(fileobj=io.BytesIO(package), mode="r:gz") as archive:
            self.assertEqual(set(archive.getnames()), {prefix[:-1], prefix + "kaiplus-web.zip", prefix + "kaiplus.x86_64", prefix + "kaiplus.aarch64"})
            web = archive.extractfile(prefix + "kaiplus-web.zip").read()
            self.assertEqual(hashlib.sha256(web).hexdigest(), manifest["webArchive"]["sha256"])
            self.assertEqual(web, read_release(manifest["webArchive"]["file"]))
            with zipfile.ZipFile(io.BytesIO(web)) as assets:
                self.assertIn("index.html", assets.namelist())
                self.assertTrue(any(entry.filename.startswith("__zipserve__/v1/br/assets/") for entry in assets.infolist()))
                self.assertTrue(all(entry.compress_type == zipfile.ZIP_STORED for entry in assets.infolist()))
            for package_arch, go_arch, machine in [("x86_64", "amd64", 62), ("aarch64", "arm64", 183)]:
                with self.subTest(arch=package_arch):
                    body = archive.extractfile(prefix + f"kaiplus.{package_arch}").read()
                    self.assertEqual(body[:6], b"\x7fELF\x02\x01")
                    self.assertEqual(int.from_bytes(body[18:20], "little"), machine)
                    if go_arch == "amd64" and os.uname().machine == "x86_64":
                        with tempfile.TemporaryDirectory() as directory:
                            binary = Path(directory) / "kaiplus"
                            binary.write_bytes(body)
                            binary.chmod(0o755)
                            built = json.loads(subprocess.check_output([str(binary), "version", "--json"], text=True, timeout=15))
                        self.assertEqual(built["version"], version)
                        self.assertTrue(built["git_commit"])
                        self.assertTrue(manifest["commit"].startswith(built["git_commit"]))

    def test_runtime_installs_zip_without_unpacking_web_assets(self):
        # Execute the real Prepare/install recipes using buildroot command stubs.
        # Both ARCH selections must install the matching executable and one ZIP.
        recipe = (APP / "kaiplus/Makefile").read_text()
        version = re.search(r"^PKG_VERSION:=(.+)$", recipe, re.MULTILINE).group(1)
        digest = re.search(r"^KAIPLUS_HASH:=(.+)$", recipe, re.MULTILINE).group(1)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "include").mkdir()
            (root / "downloads").mkdir()
            (root / "rules.mk").write_text("INCLUDE_DIR:=$(TOPDIR)/include\nBUILD_DIR:=$(TOPDIR)/build\nDL_DIR:=$(TOPDIR)/downloads\nINSTALL_DIR:=mkdir -p\nINSTALL_BIN:=install -m0755\nINSTALL_DATA:=install -m0644\nINSTALL_CONF:=install -m0600\n")
            (root / "include/package.mk").write_text("")
            package = root / "downloads" / f"kaiplus-binary-{version}.tar.gz-{digest}"
            with tarfile.open(package, "w:gz") as archive:
                for filename, body in [("kaiplus.x86_64", b"x86_64 executable"), ("kaiplus.aarch64", b"aarch64 executable"), ("kaiplus-web.zip", b"opaque web ZIP")]:
                    entry = tarfile.TarInfo(f"kaiplus-binary-{version}/{filename}")
                    entry.size = len(body)
                    archive.addfile(entry, io.BytesIO(body))
            wrapper = root / "test.mk"
            wrapper.write_text(f'include {APP}/kaiplus/Makefile\nprepare:\n\t$(Build/Prepare)\ninstall:\n\t$(call Package/kaiplus/install,$(DESTDIR))\n')
            for arch in ["x86_64", "aarch64"]:
                dest = root / arch
                subprocess.run(["make", "--no-print-directory", "-f", str(wrapper), f"TOPDIR={root}", f"ARCH={arch}", f"DESTDIR={dest}", "prepare", "install"], cwd=APP / "kaiplus", check=True, capture_output=True)
                self.assertEqual((dest / "usr/sbin/kaiplus_bin").read_bytes(), f"{arch} executable".encode())
                self.assertEqual((dest / "usr/share/kaiplus/kaiplus-web.zip").read_bytes(), b"opaque web ZIP")
                self.assertFalse((dest / "usr/share/kaiplus/www").exists())
                installed_init = (dest / "etc/init.d/kaiplus").read_text()
                self.assertIn("--web-zip /usr/share/kaiplus/kaiplus-web.zip", installed_init)
                self.assertIn('KAIPLUS_BACKUP_DIR="$backup_dir"', installed_init)
                self.assertNotIn('backup_dir="$(dirname', installed_init)

    def test_market_config_sets_home_and_propagates_start_failure(self):
        for dont_start, restart_status in [(False, 0), (True, 0), (False, 1)]:
            with self.subTest(dont_start=dont_start, restart_status=restart_status), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                bin_dir = root / "bin"
                bin_dir.mkdir()
                uci = bin_dir / "uci"
                uci.write_text('#!/bin/sh\ncat > "$TEST_UCI_INPUT"\n')
                uci.chmod(0o755)
                service = bin_dir / "kaiplus"
                service.write_text('#!/bin/sh\nprintf "%s" "$*" > "$TEST_SERVICE_INPUT"\nexit "$TEST_RESTART_STATUS"\n')
                service.chmod(0o755)
                # Run the shipped shell body with only its service path redirected.
                script = (APP / "app-meta-kaiplus/config.sh").read_text().replace("/etc/init.d/kaiplus", str(service))
                env = {**os.environ, "PATH": str(bin_dir) + ":" + os.environ["PATH"],
                       "ISTORE_CONF_DIR": str(root / "Configs"), "ISTORE_DONT_START": "1" if dont_start else "",
                       "TEST_UCI_INPUT": str(root / "uci-input"), "TEST_SERVICE_INPUT": str(root / "service-input"),
                       "TEST_RESTART_STATUS": str(restart_status)}
                result = subprocess.run(["sh"], input=script, text=True, env=env, capture_output=True)
                self.assertEqual(result.returncode, restart_status, result.stderr)
                config = (root / "uci-input").read_text()
                self.assertIn(f'set kaiplus.@kaiplus[0].data_dir="{root}/Configs/KAIPlus"', config)
                self.assertIn(f'set kaiplus.@kaiplus[0].backup_dir="{root}/TimeMachine"', config)
                self.assertIn(f"set kaiplus.@kaiplus[0].enabled={0 if dont_start else 1}", config)
                self.assertEqual((root / "service-input").read_text(), "restart")
                self.assertTrue((root / "Configs/KAIPlus").is_dir())
                self.assertNotIn("storage-configure", script)

    def test_runtime_minimum_dependencies_prevent_mixed_install(self):
        packages = [
            (APP / "kaiplus/Makefile", "changeguard", HUB / "apps/changeguard/changeguard/Makefile"),
            (HUB / "apps/changeguard/changeguard/Makefile", "linkspace", HUB / "apps/linkspace/linkspace/Makefile"),
        ]
        for consumer, dependency, provider in packages:
            with self.subTest(consumer=consumer.parent.name, dependency=dependency):
                consumer_text = consumer.read_text()
                provider_text = provider.read_text()
                version = re.search(r"^PKG_VERSION:=(.+)$", provider_text, re.MULTILINE).group(1)
                release = re.search(r"^PKG_RELEASE:=(.+)$", provider_text, re.MULTILINE).group(1)
                declared = f"{dependency} (>={version}-$(if $(CONFIG_USE_APK),r){release})"
                self.assertIn(f"EXTRA_DEPENDS:={declared}", consumer_text)
                self.assertEqual(
                    declared.replace("$(if $(CONFIG_USE_APK),r)", ""),
                    f"{dependency} (>={version}-{release})",
                )
                self.assertEqual(
                    declared.replace("$(if $(CONFIG_USE_APK),r)", "r"),
                    f"{dependency} (>={version}-r{release})",
                )


if __name__ == "__main__":
    unittest.main()
