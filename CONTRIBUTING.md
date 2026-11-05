# Contributing to VPS Monitor

Thanks for helping improve VPS Monitor. Contributions can be as small as clarifying a sentence, reproducing a bug, or improving an error message. Swift, Python, design, accessibility, and testing contributions are all welcome.

## Find something to work on

Check the repository’s issues and existing pull requests before starting. For a substantial feature or behavior change, open an issue first so the approach can be discussed. Small fixes can go straight to a pull request.

Useful areas to explore include configurable application-service groups, multiple server profiles, connection recovery, accessibility, and broader Linux compatibility. These are ideas for discussion, not promises or assigned work.

## Set up locally

You need a Mac running macOS 14 or later, Xcode with a Swift 6 toolchain, and Python 3 for the Python tests.

1. Fork the repository on GitHub and clone your fork.
2. Open the cloned project directory in Terminal.
3. Create a branch for your change, for example `git switch -c fix/connection-error`.
4. Build and open the packaged app:

```sh
zsh scripts/build.sh
open 'dist/VPS Monitor.app'
```

You can open `Package.swift` in Xcode to browse and edit the project. Use the packaged app for manual password-login testing: it includes the SSH password helper, resource scripts, and local code signatures.

No production VPS is needed for the automated tests. Use a server you own or are authorized to access for manual SSH checks. Put credentials into the app, never into source files, fixtures, screenshots, issues, or pull requests.

## Project structure

| Path | Purpose |
| --- | --- |
| `Sources/VPSMonitor/App.swift` | App entry point, window, menu commands, and package self-check. |
| `Sources/VPSMonitor/Views.swift` | Connection, monitoring, service, process, file-browser, and preview screens. |
| `Sources/VPSMonitor/MonitorModel.swift` | Connection state, polling, readings, and file requests. |
| `Sources/VPSMonitor/Core.swift` | SSH execution, Keychain access, host trust, and data models. |
| `Sources/VPSMonitor/Scripts/monitor.py` | Linux resource, process, and systemd collection. |
| `Sources/VPSMonitor/Scripts/files.py` | Directory listings and bounded text previews. |
| `Sources/VPSAskPass/main.swift` | OpenSSH password helper backed by Keychain. |
| `Tests/VPSMonitorTests/` | Swift behavior tests and optional native screen captures. |
| `Tests/test_*.py` | Python collector and file-operation tests. |
| `scripts/` | App packaging and icon generation. |
| `DESIGN.md` | Implemented native interface conventions. |

## Make a focused change

Follow the surrounding Swift and Python style. Keep unrelated refactors out of a fix, explain changes to behavior, and avoid adding dependencies without discussing the need first.

Preserve these existing behaviors when touching connection or remote-operation code:

- Verify host keys before sending credentials; retain strict checking for subsequent connections.
- Keep passwords out of logs, command-line arguments, profile data, and test fixtures.
- Quote both remote shell arguments and values parsed by OpenSSH’s configuration parser. Paths containing spaces need regression coverage.
- Keep remote operations read-only unless a separately discussed feature explicitly introduces writes.
- Bound file previews and preserve rejection of symlinks, binary files, and special files.
- Show errors and stale readings clearly, and prevent responses from disconnected sessions from replacing current data.

For interface changes, follow [DESIGN.md](DESIGN.md), use native controls and semantic colors, and check light/dark appearance, keyboard access, and the 960 × 640 minimum window size. For collector changes, preserve units, JSON field names, and useful error reporting, or update their Swift consumers together.

## Run the relevant checks

Run the suites affected by your change:

```sh
swift test --disable-sandbox
python3 -m unittest discover -s Tests -p 'test_*.py'
```

The native render test skips by default. To render the screens with demo data:

```sh
VPS_RENDER_DIR="$PWD/.build/screenshots" \
  swift test --disable-sandbox --filter VisualTests
```

Inspect the resulting images for clipping, unreadable text, and inconsistent states. Test renders do not establish that real SSH authentication, Keychain prompts, or window interaction work.

For packaging or helper changes, rebuild and verify the bundle:

```sh
zsh scripts/build.sh
'dist/VPS Monitor.app/Contents/MacOS/VPSMonitor' --self-check
codesign --verify --deep --strict 'dist/VPS Monitor.app'
```

Add regression coverage for a bug when it can meaningfully reproduce the failure. Documentation-only changes do not need a full app rebuild; check commands, links, and any feature claims you change.

## Check a real connection when relevant

For changes to SSH, Keychain, polling, or file browsing, manually exercise the affected flow against an authorized test server. Useful checks include first-connection fingerprint verification, wrong credentials, reconnection, password storage, refresh failure and recovery, directory permissions, and file-preview limits.

Do not weaken host verification to make a test pass. Report which manual checks you performed and which you could not perform. A synthetic render or passing unit test should not be described as a verified live connection.

## Report a bug or propose a feature

For bugs, include your macOS version, app version or commit, relevant Linux distribution, steps to reproduce, expected behavior, and the actual error. A sanitized screenshot or exact error message is helpful. Include build/toolchain details for compilation failures.

For features, describe the task you are trying to complete, the proposed behavior, and any alternatives you have tried. Include enough context to discuss the change without needing access to your server.

Use example addresses and sample data. Remove passwords, private keys, tokens, private file contents, and identifying server details before posting. For a suspected credential-exposure or host-verification vulnerability, keep reproduction details private and ask a maintainer for a private reporting channel rather than posting secrets in a public issue.

## Submit a pull request

Push your branch to your fork and open a pull request against the repository’s default branch. Describe the problem, the resulting behavior, and how you verified it. Link a related issue when one exists.

For visible changes, include before/after screenshots with demo data. For fixes, include the triggering case and relevant regression coverage. State any remaining limitations or checks you could not run, and respond to review feedback with focused follow-up commits.

Generated builds, local credentials, and personal server data do not belong in a pull request. `.build/` and `dist/` are ignored. Keep committed documentation screenshots in `docs/images/` and use synthetic fixtures when regenerating them.

## Support the project

If the app is useful to you, consider starring the repository, sharing it, or helping another user reproduce an issue. Using or cloning the project never requires a star.
