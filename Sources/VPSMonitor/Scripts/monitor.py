import json, os, shutil, subprocess, time

def output(args):
    p = subprocess.run(args, capture_output=True, text=True, timeout=12)
    if p.returncode:
        raise RuntimeError(p.stderr.strip() or 'Command failed: ' + args[0])
    return p.stdout

def collect():
    with open('/proc/stat') as f:
        cpu = [int(x) for x in f.readline().split()[1:9]]
    with open('/proc/meminfo') as f:
        mem = {line.split(':')[0]: int(line.split()[1]) * 1024 for line in f}
    disk = shutil.disk_usage('/')
    with open('/proc/uptime') as f:
        uptime = float(f.read().split()[0])
    services, service_error = [], None
    try:
        raw = output(['systemctl', 'list-units', '--type=service', '--all', '--no-pager', '--plain', '--no-legend'])
        for line in raw.splitlines():
            fields = line.strip().lstrip('●').strip().split(None, 4)
            if len(fields) >= 4:
                services.append(dict(name=fields[0], state=fields[2], substate=fields[3], description=fields[4] if len(fields) > 4 else ''))
    except Exception as e:
        service_error = str(e)
    processes, process_error = [], None
    try:
        raw = output(['ps', '-eo', 'pid=,user=,pcpu=,pmem=,rss=,comm=', '--sort=-pcpu'])
        for line in raw.splitlines()[:250]:
            p = line.split(None, 5)
            if len(p) == 6:
                processes.append(dict(pid=int(p[0]), user=p[1], cpu=float(p[2]), memory=float(p[3]), rss=int(p[4])*1024, command=p[5]))
    except Exception as e:
        process_error = str(e)
    return dict(hostname=os.uname().nodename, kernel=os.uname().release, cores=os.cpu_count() or 1,
        cpuTotal=sum(cpu), cpuIdle=cpu[3]+cpu[4], load=list(os.getloadavg()),
        memoryTotal=mem['MemTotal'], memoryAvailable=mem.get('MemAvailable', mem.get('MemFree',0)),
        swapTotal=mem.get('SwapTotal',0), swapFree=mem.get('SwapFree',0),
        diskTotal=disk.total, diskUsed=disk.used, diskFree=disk.free, uptime=uptime,
        services=services, serviceError=service_error, processes=processes, processError=process_error)

if __name__ == '__main__':
    try:
        print(json.dumps(collect()))
    except Exception as e:
        import sys
        print(str(e), file=sys.stderr)
        sys.exit(1)
