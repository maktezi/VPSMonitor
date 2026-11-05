# Validation

Verified on this Mac with Swift 6.4 / Xcode and macOS 27:

- Release build succeeds; packaged app is 1.5 MB and has no third-party dependencies.
- Ad hoc app and helper signatures pass `codesign --verify --deep --strict`.
- Packaged executable `--self-check` confirms the Python resources and SSH helper are present.
- Seven Swift core tests pass: connection validation, literal shell quoting, subprocess failure/timeout handling, application-service grouping, file sorting/filtering, and known-hosts path quoting through the real OpenSSH configuration parser.
- Eight Python tests pass: file listing, text previews, size limits, binary/symlink/FIFO rejection, missing folders, Linux CPU and memory parsing, service/process parsing, and partial service-query failure.
- One native render test passes and captures light/dark layouts, minimum window size, connection, overview, services, processes, and file browsing with synthetic fixtures.
- Independent native interface review scored its Files sorting finding resolved and returned `ship` for that fix.

Not verified: live VPS authentication, real Keychain prompts, live monitoring/file browsing, or a normal packaged GUI launch. No VPS credentials were supplied. The tool environment cannot launch a regular Mac window: macOS LaunchServices fails before application UI initialization. Native views were rendered through XCTest instead. Open the app from Finder to test the real connection flow.

Compiler warnings concern macOS’s deprecated legacy Keychain ACL APIs used to grant access to the separate OpenSSH password helper; compilation and packaging succeed. Tests use synthetic data and never connect to a VPS.

Version 1.0.1 fixes the known-hosts option: the space in `Application Support` was being interpreted as a separator between filenames. The fix quotes the path inside OpenSSH’s `-o` configuration value. An offline regression test reproduces the original split-path failure and verifies that the corrected option parses successfully. Saved host keys are preserved and strict host checking remains enabled. A live handshake probe was prevented by the tool sandbox’s network restriction, so reconnecting in the app remains the final runtime check.
