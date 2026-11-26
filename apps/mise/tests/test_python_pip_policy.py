"""Run the shipped policy against installed pip, including older flat config APIs.

Device tests separately cover public wrappers, pip 26.3 and real wheel installs.
No pip configuration parser or interpreter is mocked here.
"""
import ast
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / 'mise-runtime/files/python-venv.py'
TREE = ast.parse(SOURCE.read_text())
POLICY = next(
    ast.literal_eval(node.value)
    for node in ast.walk(TREE)
    if isinstance(node, ast.Assign)
    and any(isinstance(target, ast.Name) and target.id == 'policy' for target in node.targets)
)


class PipConfigurationPolicy(unittest.TestCase):
    def run_policy(self, content):
        with tempfile.TemporaryDirectory(prefix='mise-pip-policy-') as directory:
            config = Path(directory) / 'pip.conf'
            config.write_text(content)
            env = os.environ.copy()
            for key in ('PIP_TARGET', 'PIP_PREFIX', 'PIP_ROOT', 'PIP_USER', 'PIP_PYTHON'):
                env.pop(key, None)
            env['PIP_CONFIG_FILE'] = str(config)
            return subprocess.run([sys.executable, '-c', POLICY], env=env, capture_output=True, text=True)

    def test_destination_options_in_both_sections_are_rejected(self):
        for section in ('global', 'install'):
            for option in ('target', 'prefix', 'root', 'python', 'user'):
                with self.subTest(section=section, option=option):
                    value = 'true' if option == 'user' else '/tmp/unused-destination'
                    result = self.run_policy(f'[{section}]\n{option} = {value}\n')
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(f'clear {section}.{option}', result.stderr)

    def test_normal_private_index_and_user_false_are_preserved(self):
        secret = 'fixture-only-private-index-value'
        result = self.run_policy(
            f'[global]\nindex-url = https://test:{secret}@example.invalid/simple\n'
            'no-index = true\n[install]\nuser = false\n'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(secret, result.stdout + result.stderr)

    def test_omitted_destination_options_are_allowed(self):
        result = self.run_policy('[install]\nno-deps = true\n')
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
