import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class KaiPlusAuthContractTest(unittest.TestCase):
    def test_gateway_passthrough_keeps_strict_auth_in_the_backend(self):
        plugin = json.loads(
            (ROOT / "kaiplus/files/kaiplus-plugin.json").read_text(encoding="utf-8")
        )
        self.assertEqual(plugin.get("auth"), {"mode": "passthrough"})

    def test_package_installs_rpcd_acl_used_by_backend_validation(self):
        makefile = (ROOT / "kaiplus/Makefile").read_text(encoding="utf-8")
        acl_path = ROOT / "kaiplus/files/kaiplus.json"
        self.assertTrue(acl_path.is_file())
        acl = json.loads(acl_path.read_text(encoding="utf-8"))
        self.assertIn("kaiplus", acl)
        self.assertIn("/usr/share/rpcd/acl.d", makefile)
        self.assertIn("./files/kaiplus.json", makefile)


if __name__ == "__main__":
    unittest.main()
