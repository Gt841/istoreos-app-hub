import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
import urllib.request

APP = Path(__file__).resolve().parents[1]
HUB = APP.parents[1]


class FreshInstall(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("KAI_VERIFY_PUBLIC_RELEASE"), "explicit public release verification required")
    def test_published_binaries_match_recipe_version_hash_and_source(self):
        recipe = (APP / "kaiplus/Makefile").read_text()
        version = re.search(r"^PKG_VERSION:=(.+)$", recipe, re.MULTILINE).group(1)
        base = f"https://github.com/istoreos/istoreos-app-hub/releases/download/kaiplus-runtime-v{version}/"
        with urllib.request.urlopen(base + "release.json", timeout=60) as response:
            manifest = json.load(response)
        self.assertEqual(manifest["version"], version)
        artifacts = {item["arch"]: item for item in manifest["artifacts"]}
        for package_arch, go_arch, machine in [("x86_64", "amd64", 62), ("aarch64", "arm64", 183)]:
            with self.subTest(arch=package_arch):
                expected = re.search(rf"^KAIPLUS_HASH_{package_arch}:=([0-9a-f]{{64}})$", recipe, re.MULTILINE).group(1)
                with urllib.request.urlopen(base + f"kaiplus-linux-{go_arch}", timeout=120) as response:
                    body = response.read()
                self.assertEqual(hashlib.sha256(body).hexdigest(), expected)
                self.assertEqual(artifacts[go_arch]["sha256"], expected)
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
