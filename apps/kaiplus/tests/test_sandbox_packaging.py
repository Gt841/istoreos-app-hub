import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

APP = Path(__file__).resolve().parents[1]


class SandboxPackaging(unittest.TestCase):
    def test_native_and_confined_dependencies_are_separate(self):
        recipe = (APP / "kaiplus/Makefile").read_text()
        native = re.search(r"define Package/\$\(PKG_NAME\)\n(.*?)\nendef", recipe, re.S).group(1)
        confined = re.search(r"define Package/kaiplus-sandbox\n(.*?)\nendef", recipe, re.S).group(1)
        self.assertNotIn("bubblewrap", native)
        self.assertIn("+kaiplus +bubblewrap", confined)
        # The optional backend must not silently rewrite runtime config.
        self.assertNotIn("Package/kaiplus-sandbox/postinst", recipe)

    def test_real_backend_install_owns_binary_and_licenses_without_setuid(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            (base / "include").mkdir()
            (base / "rules.mk").write_text("")
            (base / "include/package.mk").write_text("")
            (base / "include/meson.mk").write_text("")
            source, staged, root = base / "source", base / "staged", base / "root"
            source.mkdir()
            (staged / "usr/bin").mkdir(parents=True)
            (staged / "usr/bin/bwrap").write_text("#!/bin/sh\nexit 0\n")
            for name in ["COPYING", "COPYING.LIB", "LICENSE"]:
                (source / name).write_text(name)
            makefile = base / "fixture.mk"
            makefile.write_text(f"""TOPDIR:={base}
INCLUDE_DIR:={base}/include
include Makefile
PKG_BUILD_DIR:={source}
PKG_INSTALL_DIR:={staged}
INSTALL_DIR:=install -d -m0755
INSTALL_BIN:=install -m0755
INSTALL_DATA:=install -m0644
.PHONY: fixture
fixture:
	$(call Package/bubblewrap/install,{root})
""")
            subprocess.run(["make", "--no-print-directory", "-f", str(makefile), "fixture"], cwd=APP / "bubblewrap", check=True, capture_output=True)
            self.assertEqual((root / "usr/bin/bwrap").stat().st_mode & 0o7777, 0o755)
            for name in ["COPYING", "COPYING.LIB", "LICENSE", "libcap-license.txt"]:
                self.assertTrue((root / "usr/share/licenses/bubblewrap" / name).is_file())

    @unittest.skipUnless(os.environ.get("BWRAP_SOURCE_DIR"), "official source path required for patch verification")
    def test_static_libcap_patch_applies_to_verified_upstream_source(self):
        source = Path(os.environ["BWRAP_SOURCE_DIR"])
        patch = APP / "bubblewrap/patches/010-static-libcap.patch"
        subprocess.run(["patch", "--dry-run", "-p1", "-i", str(patch)], cwd=source, check=True, capture_output=True)


if __name__ == "__main__":
    unittest.main()
