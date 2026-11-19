import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

APP = Path(__file__).resolve().parents[1]
HUB = APP.parents[1]


class FreshInstall(unittest.TestCase):
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
