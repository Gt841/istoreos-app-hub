from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class LinkEaseFullWebContractTest(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_core_web_is_an_independent_architecture_neutral_package(self):
        web = self.read("linkeasefull-web/Makefile")
        runtime = self.read("linkeasefull/Makefile")

        self.assertIn("PKG_NAME:=linkeasefull-web", web)
        self.assertIn("PKG_VERSION:=0.1.0", web)
        self.assertIn("PKGARCH:=all", web)
        self.assertIn("+linkeasefull-web", runtime)
        self.assertIn("PKG_RELEASE:=2", runtime)
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
            "https://fw.linkease.com/binary/LinkEase/",
            "https://dl.istoreos.com/binary/LinkEase/",
            "https://fw.d4ctech.com/binary/LinkEase/",
            "https://fw20.koolcenter.com/binary/LinkEase/",
            "https://fw.koolcenter.com/binary/LinkEase/",
        ):
            self.assertIn(base, web)
        for digest in (
            "ab13b11bba8cca0188143d0925028ee411db64011284e20f1a171617bd8c051e",
            "724ef554ce5d68e4f1890c67301c2dae41ca54519ff2c11563e8084ffb3e381b",
            "a67d1ab0d7dc06b15933f2e5106c592ebb1c91da2bc4fa9823bf85514ad424b3",
        ):
            self.assertIn(digest, web)


if __name__ == "__main__":
    unittest.main()
