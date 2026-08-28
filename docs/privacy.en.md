# Privacy and local data

Servergy works without a cloud service, user account, tracking, or telemetry.
The app creates only local network and SSH connections to the home server that
you configure.

The optional **“Search for server on network”** feature runs only after you
actively select it. For a few seconds, it checks possible SSH servers on the
currently connected local IPv4 network and may read local mDNS announcements.
Discovered IP addresses, server banners, and device names are neither stored
nor transmitted. On Android 17, the app requests the system permission for
the local network.

Non-secret profile data (name, host, ports, MAC address, and broadcast
address) is stored locally in the app preferences. Passwords, imported private
SSH keys, and confirmed SSH host keys are kept exclusively in the operating
system’s secure storage. Passphrases for encrypted keys are used only for the
active connection.

The optional diagnostic log remains local. It contains time, action, result,
error code, and duration, but never credentials, keys, usernames, complete host
addresses, or MAC addresses. An export is created only after an explicit choice
in the **Events** section.
