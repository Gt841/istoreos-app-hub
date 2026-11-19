import hashlib
import io
import json
import os
import re
import subprocess
import tarfile
import tempfile
import unittest
import urllib.request
from pathlib import Path

H = Path(__file__).resolve().parents[3]
HELPER = H / "apps/changeguard/changeguard/files/usr/libexec/changeguard-package"


class Contract(unittest.TestCase):
    def test_runtime_recipes_use_tabs_and_immutable_release(self):
        for name, version in [("changeguard", "0.3.3"), ("linkspace", "0.3.2")]:
            recipe = (H / f"apps/{name}/{name}/Makefile").read_text()
            self.assertRegex(recipe, rf"(?m)^PKG_VERSION:={re.escape(version)}$")
            self.assertRegex(recipe, r"(?m)^PKG_RELEASE:=2$")
            self.assertIn(f"releases/download/{name}-runtime-v$(PKG_VERSION)/", recipe)
            match = re.search(rf"^define Package/{name}/install\n(.*?)^endef$", recipe, re.M | re.S)
            self.assertIsNotNone(match)
            for line in match.group(1).splitlines():
                if line.strip():
                    self.assertTrue(line.startswith("\t"), line)

    def test_one_product_identity_and_headless_dependencies(self):
        self.assertFalse(list((H / "apps/changeguard").glob("app-meta-*")))
        meta = (H / "apps/kaiplus/app-meta-kaiplus/Makefile").read_text()
        self.assertIn("+kaiplus", meta)
        mapping = re.split(r"\n    \S", (H / "syncapps.yaml").read_text().split("\n    changeguard:\n", 1)[1], maxsplit=1)[0]
        self.assertNotIn("app-meta-", mapping)
        self.assertIn("meta: []", mapping)
        self.assertFalse((H / "apps/optimemachine").exists())
        self.assertIn("+changeguard", (H / "apps/kaiplus/kaiplus/Makefile").read_text())
        self.assertIn("+linkspace", (H / "apps/changeguard/changeguard/Makefile").read_text())
        self.assertFalse(list((H / "apps/changeguard/changeguard/files").rglob("*plugin.json")))
        for name in ["changeguard", "linkspace"]:
            self.assertNotIn("optimemachine", (H / f"apps/{name}/{name}/Makefile").read_text())
        self.assertNotIn("optimemachine", HELPER.read_text())

    def test_offline_hooks_preserve_all_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            keep = root / "configuration"
            keep.write_text("unchanged")
            for phase in ["preinst", "postinst", "prerm"]:
                subprocess.run(["sh", str(HELPER), phase], env={**os.environ, "IPKG_INSTROOT": directory}, check=True)
            self.assertEqual(keep.read_text(), "unchanged")
            self.assertEqual(list(root.iterdir()), [keep])

    def test_native_lifecycle_initializes_and_preserves_service_intent(self):
        for configured, running, enabled, allowed in [(False, False, False, True), (True, True, True, True), (True, False, False, True), (True, True, True, False)]:
            with self.subTest(configured=configured, running=running, allowed=allowed), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                config = root / "config.json"
                if configured:
                    config.write_text("{}")
                log = root / "calls"
                binary = root / "changeguard_bin"
                binary.write_text('#!/bin/sh\nprintf "cli %s\\n" "$1" >> "$CG_TEST_LOG"\ncase "$1" in\n status) [ "$CG_TEST_RUNNING" = 1 ] ;;\n maintenance-check) [ "$CG_TEST_ALLOWED" = 1 ] ;;\n initialize) printf "{}" > "$CG_TEST_CONFIG" ;;\n *) exit 0 ;;\nesac\n')
                binary.chmod(0o755)
                service = root / "service"
                service.write_text('#!/bin/sh\nprintf "service %s\\n" "$1" >> "$CG_TEST_LOG"\nif [ "$1" = enabled ]; then [ "$CG_TEST_ENABLED" = 1 ]; else exit 0; fi\n')
                service.chmod(0o755)
                body = HELPER.read_text().replace("/usr/sbin/changeguard_bin", str(binary)).replace("/etc/init.d/changeguard", str(service)).replace("/etc/changeguard/config.json", str(config)).replace("/var/run/", str(root) + "/")
                env = {**os.environ, "IPKG_INSTROOT": "", "CG_TEST_LOG": str(log), "CG_TEST_CONFIG": str(config), "CG_TEST_RUNNING": str(int(running)), "CG_TEST_ENABLED": str(int(enabled)), "CG_TEST_ALLOWED": str(int(allowed))}
                result = subprocess.run(["sh", "-s", "postinst"], input=body, text=True, env=env, capture_output=True)
                calls = log.read_text().splitlines()
                self.assertEqual(result.returncode == 0, allowed, result.stderr)
                if not allowed:
                    self.assertEqual(calls, ["cli maintenance-check"])
                    continue
                for operation in ["cli initialize", "cli sync-backend", "cli refresh-runtime"]:
                    self.assertIn(operation, calls)
                self.assertEqual("service stop" in calls, running)
                self.assertEqual("service start" in calls, not configured or running)
                self.assertEqual("service enable" in calls, not configured or enabled)
                self.assertEqual(config.read_text(), "{}")

    @unittest.skipUnless(os.environ.get("CG_VERIFY_PUBLIC_RELEASE"), "explicit public release verification required")
    def test_public_assets_match_hashes_and_layout(self):
        for name, version, executable in [("changeguard", "0.3.3", "changeguard_bin"), ("linkspace", "0.3.2", "linkspace")]:
            hashes = (H / f"apps/{name}/{name}/release.mk").read_text()
            for arch in ["x86_64", "aarch64"]:
                expected = re.search(rf"^{name.upper()}_HASH_{arch}:=([0-9a-f]{{64}})$", hashes, re.M).group(1)
                url = f"https://github.com/istoreos/istoreos-app-hub/releases/download/{name}-runtime-v{version}/{name}-{version}-{arch}.tar.gz"
                with urllib.request.urlopen(url, timeout=60) as response:
                    body = response.read()
                self.assertEqual(hashlib.sha256(body).hexdigest(), expected)
                with tarfile.open(fileobj=io.BytesIO(body), mode="r:gz") as package:
                    names = package.getnames()
                self.assertIn(f"./{name}-{version}/{executable}", names)
                self.assertEqual(f"./{name}-{version}/dependency.json" in names, name == "linkspace")


if __name__ == "__main__":
    unittest.main()
