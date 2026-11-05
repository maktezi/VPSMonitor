# VPS Monitor

<!-- impeccable:product-schema 1 -->

## Platform
Native macOS.

## Stack
SwiftUI, Foundation Process, system OpenSSH, and macOS Keychain. The user accepted the recommended native app.

## Users
Developers, self-hosters, and server administrators who use a Mac to inspect and monitor a Linux VPS over SSH.

## Product Purpose
Connect with SSH credentials, inspect files, and monitor resources and running services in a Mac app like Activity Monitor.

## Capabilities and Constraints
Live CPU, RAM, swap, storage, uptime, processes, systemd services, directory browsing, and file previews. Read-only remote operations. Credentials entered in the app. Linux with Python 3 and systemd. Server fingerprint explicitly trusted before sending credentials. No agent installed on the VPS.

The initial Overview has fixed application-service presets for Billo, ATLAS, and CorGo, plus PostgreSQL, MySQL, and Redis. These presets came from the original use case; they do not define the audience. The Services view supports loaded systemd services generally. Configurable service groups are not implemented yet. The app currently remembers one server profile.

## Brand Commitments
Native Mac interface in the tradition of Activity Monitor, explicitly requested by the user.
