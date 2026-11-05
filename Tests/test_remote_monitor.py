import importlib.util, io, pathlib, shutil, subprocess, types, unittest
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'Sources/VPSMonitor/Scripts/monitor.py'
spec = importlib.util.spec_from_file_location('remote_monitor', SCRIPT)
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)

class RemoteMonitorTests(unittest.TestCase):
    def collect(self, fail_services=False):
        proc = {
            '/proc/stat': 'cpu  100 20 30 400 50 6 7 8 90 0\n',
            '/proc/meminfo': 'MemTotal: 8192000 kB\nMemAvailable: 6144000 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n',
            '/proc/uptime': '86400.50 100000.00\n',
        }
        def run(args, **kwargs):
            if args[0] == 'systemctl':
                if fail_services:
                    return subprocess.CompletedProcess(args, 1, '', 'System has not been booted with systemd')
                text = 'billo-queue.service loaded active running Billo Queue Worker\n● atlas-octane.service loaded failed failed Atlas Octane\npostgresql.service loaded active exited PostgreSQL RDBMS\n'
            else:
                text = '  123 root 125.2 4.5 102400 php\n  456 postgres 0.4 1.2 32768 postgres\n'
            return subprocess.CompletedProcess(args, 0, text, '')
        with patch('builtins.open', side_effect=lambda path: io.StringIO(proc[path])), \
             patch.object(monitor.subprocess, 'run', side_effect=run), \
             patch.object(monitor.os, 'uname', return_value=types.SimpleNamespace(nodename='demo-vps', release='6.8.0')), \
             patch.object(monitor.os, 'cpu_count', return_value=4), \
             patch.object(monitor.os, 'getloadavg', return_value=(3.31, 1.41, 0.89)), \
             patch.object(monitor.shutil, 'disk_usage', return_value=types.SimpleNamespace(total=100000, used=10000, free=90000)):
            return monitor.collect()

    def test_linux_metrics_cpu_accounting_and_units(self):
        result = self.collect()
        self.assertEqual(result['cpuTotal'], 621)  # guest time is already included in user time
        self.assertEqual(result['cpuIdle'], 450)
        self.assertEqual(result['memoryTotal'], 8192000 * 1024)
        self.assertEqual(result['memoryAvailable'], 6144000 * 1024)
        self.assertEqual(result['uptime'], 86400.5)
        self.assertEqual(result['diskUsed'], 10000)

    def test_failed_and_exited_services_and_multicore_process(self):
        result = self.collect()
        self.assertEqual(result['services'][1]['state'], 'failed')
        self.assertEqual(result['services'][2]['substate'], 'exited')
        self.assertEqual(result['processes'][0]['cpu'], 125.2)
        self.assertEqual(result['processes'][0]['rss'], 102400 * 1024)

    def test_service_failure_keeps_metrics_and_reports_error(self):
        result = self.collect(fail_services=True)
        self.assertEqual(result['cores'], 4)
        self.assertEqual(len(result['processes']), 2)
        self.assertEqual(result['services'], [])
        self.assertIn('systemd', result['serviceError'])

if __name__ == '__main__':
    unittest.main()
