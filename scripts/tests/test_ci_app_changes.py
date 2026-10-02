import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'ci_app_changes', Path(__file__).resolve().parents[1] / 'ci_app_changes.py')
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)
BASE, HEAD = 'a' * 40, 'b' * 40


class ChangedPathsTests(unittest.TestCase):
    def test_site_only_push_skips_app(self):
        def diff(comparison):
            self.assertEqual(comparison, BASE + '..' + HEAD)
            return ['site/index.html', 'site/assets/new.webp']
        self.assertFalse(ci.app_changed('push', {'before': BASE, 'after': HEAD}, diff))

    def test_mixed_pr_runs_app_and_uses_merge_base(self):
        event = {'pull_request': {'base': {'sha': BASE}, 'head': {'sha': HEAD}}}
        def diff(comparison):
            self.assertEqual(comparison, BASE + '...' + HEAD)
            return ['site/index.html', 'lib/main.dart']
        self.assertTrue(ci.app_changed('pull_request', event, diff))
        self.assertFalse(ci.app_changed('pull_request', event, lambda _: ['site/styles.css']))

    def test_manual_and_new_branch_run_app(self):
        def unexpected(_):
            self.fail('No diff needed')
        self.assertTrue(ci.app_changed('workflow_dispatch', {}, unexpected))
        self.assertTrue(ci.app_changed('push', {'before': '0' * 40, 'after': HEAD}, unexpected))

    def test_move_from_app_into_site_still_runs_app(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.run(['git', '-C', str(root), *args], check=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.decode().strip()
            git('init')
            git('config', 'user.name', 'CI fixture')
            git('config', 'user.email', 'fixture@example.invalid')
            (root / 'lib').mkdir()
            (root / 'lib/tuner.dart').write_text('fixture', encoding='utf-8')
            git('add', '.')
            git('commit', '-m', 'before')
            base = git('rev-parse', 'HEAD')
            (root / 'site').mkdir()
            (root / 'lib/tuner.dart').rename(root / 'site/tuner.dart')
            git('add', '.')
            git('commit', '-m', 'move')
            head = git('rev-parse', 'HEAD')
            # Run the production git diff function inside the fixture repository.
            import os
            previous = Path.cwd()
            try:
                os.chdir(root)
                self.assertTrue(ci.app_changed('push', {'before': base, 'after': head}, ci.git_paths))
            finally:
                os.chdir(previous)


if __name__ == '__main__':
    unittest.main()
