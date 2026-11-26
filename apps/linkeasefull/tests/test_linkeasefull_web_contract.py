from pathlib import Path
import json
import re
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class LinkEaseFullWebContractTest(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_core_web_is_an_independent_architecture_neutral_package(self):
        web = self.read("linkeasefull-web/Makefile")
        runtime = self.read("linkeasefull/Makefile")

        self.assertIn("PKG_NAME:=linkeasefull-web", web)
        self.assertRegex(web, r"(?m)^PKG_VERSION:=[0-9]+\.[0-9]+\.[0-9]+$")
        self.assertIn("PKGARCH:=all", web)
        self.assertIn("+linkeasefull-web", runtime)
        self.assertRegex(runtime, r"(?m)^PKG_RELEASE:=[1-9][0-9]*$")
        self.assertIn("web/v1/core/$(PKG_NAME)/$(PKG_VERSION)/$(LINKEASE_WEB_VARIANT)", web)
        self.assertIn("desktop-shell.web.zip", web)
        self.assertIn("release-set.json", web)
        self.assertIn("package.json", web)
        self.assertIn(
            "/usr/share/linkeasefull/web-core/$(PKG_VERSION)/$(LINKEASE_WEB_VARIANT)",
            web,
        )
        self.assertIn(
            'temporary="$${base}/.current.$$$$"',
            web,
        )
        self.assertIn('mv -fT "$${temporary}" "$${current}"', web)
        self.assertIn('readlink "$${current}"', web)

    def test_app_entry_has_no_web_package_knowledge(self):
        entry_makefile = self.read("linkease-app-entry/Makefile")
        entry_init = self.read("linkease-app-entry/files/linkease-app-entry.init")
        entry = entry_makefile + "\n" + entry_init

        for forbidden in (
            "linkeasefull-web",
            "web-release-set",
            "web-core",
            "LINKEASE_WEB_",
            "desktop-shell.web.zip",
            "binary/LinkEase/web",
        ):
            self.assertNotIn(forbidden, entry)

    def test_downloads_are_content_addressed_and_have_official_fallbacks(self):
        web = self.read("linkeasefull-web/Makefile")

        for base in (
            "https://github.com/istoreos/istoreos-app-hub/releases/download/linkeasefull-web-v$(PKG_VERSION)",
            "https://fw.linkease.com/binary/LinkEase/",
            "https://dl.istoreos.com/binary/LinkEase/",
            "https://fw.d4ctech.com/binary/LinkEase/",
            "https://fw20.koolcenter.com/binary/LinkEase/",
            "https://fw.koolcenter.com/binary/LinkEase/",
        ):
            self.assertIn(base, web)
        hashes = re.findall(r"^\s*HASH:=([a-f0-9]{64})$", web, re.M)
        self.assertEqual(len(hashes), 5)
        self.assertNotIn("0" * 64, hashes)

    def test_offline_nas_registration_install_upgrade_and_removal(self):
        sys.path.insert(0, str(ROOT.parents[1] / "tools/tests"))
        from test_app_registration import PackageStage
        with tempfile.TemporaryDirectory() as temporary:
            package = PackageStage("linkeasefull/linkeasefull-web", Path(temporary))
            # Replace inert payloads with a representative downloaded registration;
            # execute the real recipe again, rather than emulating its install.
            registration = {"schemaVersion": 1, "id": "device-binding", "name": "易有云", "webPackage": "linkease-nas-web", "desktop": {"mode": "module", "entry": "desktop-entry.js", "props": {"requiresStorage": True}}}
            (package.build / "device-binding.json").write_text(json.dumps(registration))
            (package.build / "linkease-nas-web.zip").write_bytes(b"PK\x03\x04NAS fixture")
            package.make("stage")
            package.hook("postinst")
            canonical = package.stage / "usr/share/linkease/apps.d/device-binding.json"
            legacy = package.stage / "usr/share/linkeasefull/desktop-apps.d/device-binding.json"
            self.assertEqual(canonical.readlink(), legacy.readlink())
            current = package.stage / "usr/share/linkeasefull/web-core/current"
            installed = package.stage / str(canonical.readlink()).lstrip("/")
            self.assertEqual(json.loads(installed.read_text())["id"], "device-binding")
            self.assertTrue((installed.parent / "linkease-nas-web.zip").read_bytes().startswith(b"PK"))
            self.assertFalse((package.stage / "mnt").exists(), "installation must not choose a data root")
            legacy.unlink(); legacy.write_text("custom registration")
            package.hook("postinst")
            self.assertEqual(legacy.read_text(), "custom registration")
            current.unlink(); current.symlink_to("newer/nas-full")
            package.hook("prerm")
            self.assertEqual(str(current.readlink()), "newer/nas-full")
            self.assertEqual(legacy.read_text(), "custom registration")


if __name__ == "__main__":
    unittest.main()
