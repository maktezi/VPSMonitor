import base64, json, os, stat, sys

try:
    mode = sys.argv[1]
    path = base64.b64decode(sys.argv[2]).decode('utf-8')
    path = os.path.abspath(os.path.expanduser(path))
    if mode == 'list':
        entries = []
        truncated = False
        with os.scandir(path) as items:
            for index, e in enumerate(items):
                if index >= 10000:
                    truncated = True
                    break
                try:
                    s = e.stat(follow_symlinks=False)
                    entries.append(dict(name=e.name, path=e.path, directory=e.is_dir(follow_symlinks=False),
                        symlink=e.is_symlink(), size=s.st_size, modified=s.st_mtime, permissions=stat.filemode(s.st_mode)))
                except OSError:
                    continue
        entries.sort(key=lambda e: (not e['directory'], e['name'].lower()))
        print(json.dumps(dict(path=path, entries=entries, truncated=truncated)))
    elif mode == 'preview':
        s = os.stat(path, follow_symlinks=False)
        if not stat.S_ISREG(s.st_mode):
            raise ValueError('Preview supports regular files only. Symlinks and device files are not opened.')
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
        with os.fdopen(fd, 'rb') as f:
            if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
                raise ValueError('This is not a regular file.')
            data = f.read(262145)
        if b'\x00' in data:
            raise ValueError('This appears to be a binary file. Text preview is unavailable.')
        print(json.dumps(dict(path=path, content=data[:262144].decode('utf-8', errors='replace'), truncated=len(data)>262144)))
    else:
        raise ValueError('Unknown file operation.')
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
