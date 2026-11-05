import base64, json, os, pathlib, subprocess, tempfile, unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'Sources/VPSMonitor/Scripts/files.py'

class RemoteFilesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, mode, path):
        return subprocess.run(['python3', str(SCRIPT), mode, base64.b64encode(str(path).encode()).decode()], capture_output=True, text=True, timeout=5)

    def test_names_with_shell_characters_are_literal(self):
        file = self.root / "a' $(echo no);.txt"
        file.write_text('hello\nworld')
        (self.root / 'folder').mkdir()
        result = self.run_script('list', self.root)
        self.assertEqual(result.returncode, 0, result.stderr)
        listing = json.loads(result.stdout)
        self.assertTrue(listing['entries'][0]['directory'])
        self.assertEqual(listing['entries'][1]['name'], file.name)
        self.assertEqual(json.loads(self.run_script('preview', file).stdout)['content'], 'hello\nworld')

    def test_preview_truncates_large_files(self):
        file = self.root / 'large.txt'
        file.write_text('x' * 300000)
        preview = json.loads(self.run_script('preview', file).stdout)
        self.assertTrue(preview['truncated'])
        self.assertEqual(len(preview['content']), 262144)

    def test_binary_and_symlink_are_rejected(self):
        binary = self.root / 'binary'; binary.write_bytes(b'abc\x00def')
        self.assertNotEqual(self.run_script('preview', binary).returncode, 0)
        link = self.root / 'link'; link.symlink_to(binary)
        self.assertNotEqual(self.run_script('preview', link).returncode, 0)

    def test_fifo_does_not_block(self):
        fifo = self.root / 'pipe'; os.mkfifo(fifo)
        self.assertNotEqual(self.run_script('preview', fifo).returncode, 0)

    def test_missing_directory_reports_error(self):
        result = self.run_script('list', self.root / 'missing')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('No such file', result.stderr)

if __name__ == '__main__':
    unittest.main()
