from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class LinkEaseAppEntryContractTest(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_package_owns_one_binary_with_two_process_roles(self):
        makefile = self.read("linkease-app-entry/Makefile")
        full_makefile = self.read("linkeasefull/Makefile")
        entry_init = self.read("linkease-app-entry/files/linkease-app-entry.init")
        compatibility_init = self.read("linkeasefull/files/linkeasefull.init")

        self.assertIn("PKG_NAME:=linkease-app-entry", makefile)
        self.assertIn("define Package/$(PKG_NAME)", makefile)
        self.assertIn("/bin/linkease-app-entry", makefile)
        self.assertIn("/usr/sbin/linkease-app-entry", makefile)
        self.assertNotIn("linkease-app-entryd", makefile)
        self.assertNotIn("linkease-app-gateway", makefile)
        self.assertIn("+luci-lib-linkeaseauth", makefile)
        self.assertNotIn("+linkeasefull", makefile)
        self.assertIn("+linkease-app-entry", full_makefile)
        self.assertNotIn("define Package/linkease-app-entry", full_makefile)
        self.assertNotIn("linkease-app-entryd", full_makefile)
        self.assertNotIn("linkease-app-gateway", full_makefile)
        self.assertIn("PKG_VERSION:=3.0.24", makefile)
        self.assertIn("PKG_RELEASE:=1", makefile)
        self.assertIn(
            "PKG_SOURCE:=linkease-app-entry-runtime-$(PKG_VERSION)-linux-$(LINKEASE_RUNTIME_ARCH).tar.gz",
            makefile,
        )
        self.assertIn(
            "PKG_BUILD_DIR:=$(BUILD_DIR)/linkease-app-entry-runtime-$(PKG_VERSION)-linux-$(LINKEASE_RUNTIME_ARCH)",
            makefile,
        )
        self.assertIn(
            "72cbaa9df83899467223d1812204f198d9fdd9d51f821f2c203936ecbce79440",
            makefile,
        )
        self.assertIn(
            "07d1bf936cda0f2c81fbb32ea75f526393eaf39437bc8ae1d7737cfba35fe431",
            makefile,
        )
        self.assertNotIn(
            "PKG_BUILD_DIR:=$(BUILD_DIR)/linkease-app-entry-runtime-$(PKG_VERSION)-linux-$(LINKEASE_RUNTIME_ARCH)",
            full_makefile,
        )
        self.assertIn('ENTRY=/usr/sbin/linkease-app-entry', entry_init)
        self.assertIn('procd_set_param command "$ENTRY" supervisor', entry_init)
        self.assertIn('--fallback "$ENTRY"', entry_init)
        self.assertIn('--fallback-arg gateway', entry_init)
        self.assertNotIn("linkease-app-entryd", entry_init)
        self.assertNotIn("linkease-app-gateway", entry_init)
        self.assertIn('--primary-enabled="$primary"', entry_init)
        self.assertIn("LINKEASE_AUTH_PROVIDER=openwrt", entry_init)
        self.assertNotIn("procd_open_instance", compatibility_init)
        self.assertIn('"$ENTRY_INIT" restart', compatibility_init)

    def test_luci_enable_reconciles_the_selected_worker(self):
        compatibility_init = self.read("linkeasefull/files/linkeasefull.init")
        defaults = self.read("linkeasefull/files/linkeasefull.uci-default")
        luci_model = self.read(
            "luci-app-linkeasefull/luasrc/model/cbi/linkeasefull.lua"
        )

        self.assertIn("sync_force_gateway", compatibility_init)
        self.assertIn('uci -q get linkeasefull.@linkeasefull[0].enabled', compatibility_init)
        self.assertIn('rm -f "$FORCE_GATEWAY"', compatibility_init)
        self.assertIn(': > "$FORCE_GATEWAY"', compatibility_init)
        self.assertIn("add ucitrack linkeasefull", defaults)
        self.assertIn("set ucitrack.@linkeasefull[-1].init=linkeasefull", defaults)
        self.assertIn("function enabled.write", luci_model)
        self.assertIn("/var/run/linkease-app-entry/force-gateway", luci_model)
        self.assertIn("fs.remove(force_gateway)", luci_model)
        self.assertIn("fs.writefile(force_gateway", luci_model)

    def test_uhttpd_mapping_is_stable_and_idempotent(self):
        defaults = self.read("linkease-app-entry/files/linkease-app-entry.uci-default")
        self.assertIn("/apps=http://127.0.0.1:19290", defaults)
        self.assertIn("add_list", defaults)
        self.assertIn("found", defaults)

    def test_install_on_stock_uhttpd_migrates_only_the_shipped_listener(self):
        for listen in ("127.0.0.1:19290", "127.0.0.2:19290"):
            for supported in (False, True):
                with self.subTest(listen=listen, supported=supported), tempfile.TemporaryDirectory() as directory:
                    stage = Path(directory)
                    init = stage / "init"
                    init.mkdir()
                    for name in ("linkease-app-entry", "uhttpd"):
                        path = init / name
                        path.write_text('#!/bin/sh\nexit 0\n')
                        path.chmod(0o755)
                    defaults = self.read("linkease-app-entry/files/linkease-app-entry.uci-default")
                    defaults = defaults.replace(". /lib/functions.sh", ":").replace("/etc/init.d/", str(init) + "/")
                    harness = r'''
config_load() { :; }
config_list_foreach() { :; }
uci() {
    if [ "$*" = '-q get linkease_app_entry.main.listen' ]; then
        printf '%s' "$TEST_LISTEN"
        return
    fi
    printf '%s\n' "$*" >> "$TEST_LOG"
}
grep() {
    [ "$1" = -qr ] && [ "$TEST_PROXY_SUPPORT" = 1 ]
}
''' + defaults
                    log = stage / "uci.log"
                    env = dict(os.environ, TEST_LISTEN=listen, TEST_LOG=str(log), TEST_PROXY_SUPPORT=str(int(supported)))
                    subprocess.run(["sh", "-c", harness], env=env, check=True, capture_output=True, text=True)
                    calls = log.read_text() if log.exists() else ""
                    self.assertEqual("set linkease_app_entry.main.listen=0.0.0.0:19290" in calls, listen == "127.0.0.1:19290")
                    self.assertEqual("add_list uhttpd.main.proxy_prefix=" in calls, supported)

    def test_product_meta_packages_keep_core_and_bundle_boundaries(self):
        apps_root = ROOT.parent
        core = self.read("app-meta-linkeasefull/Makefile")
        bundle = (apps_root / "istorex/app-meta-istorex/Makefile").read_text(
            encoding="utf-8"
        )

        self.assertIn("+linkeasefull", core)
        self.assertIn("+luci-app-linkeasefull-embed", core)
        for package in (
            "app-meta-dockermanager",
            "app-meta-kaiplus",
            "app-meta-baidudrive",
            "app-meta-istoreenhance",
        ):
            self.assertNotIn("+" + package, core, package)
            self.assertIn("+" + package, bundle, package)
        self.assertNotIn("+app-meta-kaiplus", core)
        self.assertIn("+app-meta-linkeasefull", bundle)


if __name__ == "__main__":
    unittest.main()
