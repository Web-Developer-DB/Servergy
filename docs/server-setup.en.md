# Set up a home server for Servergy

This guide prepares a home server so Servergy can control it and shut it down
with the smallest practical set of permissions.

## 1. Enable Wake-on-LAN

Enable an option such as **Wake on LAN**, **Power on by PCI-E**, or **Resume by
LAN** in the server BIOS/UEFI. Its exact name depends on the mainboard.

On Ubuntu/Debian, inspect the network adapter state:

~~~bash
sudo apt install ethtool
ip link
sudo ethtool <network-interface>
~~~

The output should contain `Wake-on: g`. If the adapter supports it, enable it:

~~~bash
sudo ethtool -s <network-interface> wol g
~~~

The setting can be lost after a restart. If necessary, create a systemd
service that runs this command at startup.

Note the MAC address of the wired network adapter:

~~~bash
ip link show <network-interface>
~~~

After successful SSH verification, Servergy can read this MAC address from the
default-route adapter and suggest the phone’s local broadcast address. Still
verify the displayed values when using several adapters, VLANs, or a VPN. The
automatic detection needs no sudo access and does not replace a real WOL test
after shutdown.

Wake-on-LAN over Wi-Fi is reliably supported by only a few adapters. A wired
connection is the robust choice.

## 2. Create an SSH user

On Ubuntu/Debian:

~~~bash
sudo adduser servergy
~~~

**Do not add this user to the `sudo` group.** Servergy may call only the
explicitly allowed shutdown helper; group membership would grant far broader
access than necessary.

The app supports two separate SSH authentication methods: a private key
(recommended) or password authentication. In password mode, the app securely
stores the password in the operating system’s secure storage after a successful
connection test so that it does not need to be entered again. A password is not
stored as a fallback next to a key. Create a dedicated key for the recommended
method:

~~~bash
ssh-keygen -t ed25519 -f ~/.ssh/servergy_ed25519 -C 'Servergy homeserver control'
sudo install -d -o servergy -g servergy -m 0700 /home/servergy/.ssh
sudo install -o servergy -g servergy -m 0600 ~/.ssh/servergy_ed25519.pub /home/servergy/.ssh/authorized_keys
~~~

Then import the **private** `servergy_ed25519` file into Servergy. The file
stays in the secure storage of the controlling device. If it is protected by a
passphrase, the app asks for it on every use and never saves it.

Ensure that sshd is running:

~~~bash
sudo systemctl enable --now ssh
sudo systemctl status ssh
~~~

## 3. Create the shutdown unit and narrow helper

### Convenient method: prepare once with Servergy

Once the SSH connection has been verified in Servergy, open
**Settings → Safe shutdown → Prepare server**. After an explicit confirmation,
the app asks once for the configured SSH user’s sudo password. This password is
used only through the existing SSH connection; it is neither displayed nor
stored.

The app installs exactly the systemd unit, root-owned helper, and single
restricted sudoers rule shown below. It does not start the helper during setup:
the server stays powered on. The first real shutdown from Servergy is the
functional verification.

The graphical setup requires Debian with systemd, an already confirmed SSH
fingerprint, and an SSH user allowed to run sudo for this one-time installation.
The app cannot add users to groups or create administrator rights. If sudo
access is unavailable, follow the manual method at the server console.

### Manual method

The unit accepts the request first and waits briefly before actually powering
off the machine. This allows Servergy to receive the confirmed request over SSH
instead of incorrectly reporting a successful shutdown as a failure because the
network connection closed too early.

Create the unit as root:

~~~bash
sudo install -o root -g root -m 0644 /dev/stdin /etc/systemd/system/servergy-poweroff.service
~~~

Paste this content and finish input with Ctrl-D:

~~~ini
[Unit]
Description=Power off this host after a Servergy request

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 2
ExecStart=/usr/bin/systemctl poweroff --no-block
~~~

Activate the changed unit file:

~~~bash
sudo systemctl daemon-reload
~~~

Create exactly this helper as root:

~~~bash
sudo install -o root -g root -m 0755 /dev/stdin /usr/local/sbin/servergy-poweroff
~~~

The command waits for input. Paste these two lines and finish input with
Ctrl-D:

~~~sh
#!/bin/sh
set -eu
/usr/bin/systemctl start --no-block servergy-poweroff.service
printf '%s\n' 'servergy-poweroff-accepted'
~~~

Check the content and permissions:

~~~bash
sudo cat /usr/local/sbin/servergy-poweroff
sudo stat -c '%U %G %a %n' /usr/local/sbin/servergy-poweroff
~~~

The expected owner is `root root` and the expected permissions are `755`.

## 4. Allow only this helper without a password

Open the sudoers configuration safely with `visudo`:

~~~bash
sudo visudo -f /etc/sudoers.d/servergy
~~~

Add this line. Replace `servergy` if you created a different SSH user:

~~~sudoers
servergy ALL=(root) NOPASSWD: /usr/local/sbin/servergy-poweroff
~~~

Set the correct file permissions:

~~~bash
sudo chmod 0440 /etc/sudoers.d/servergy
~~~

It is deliberately **not** permitted to allow shutdown, a shell, or an
arbitrary command in sudoers.

## 5. Test from another computer

First test SSH authentication:

~~~bash
ssh servergy@<server-ip>
~~~

Then test the restricted helper:

~~~bash
ssh servergy@<server-ip> 'sudo -n /usr/local/sbin/servergy-poweroff'
~~~

This command first confirms `servergy-poweroff-accepted` and then really shuts
the server down. After it has started again, show the host-key fingerprint:

~~~bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
~~~

Compare it with the fingerprint shown by Servergy during first connection. Do
not accept an unknown or changed key without this comparison.

## 6. Enter data in Servergy

1. Start the server for initial setup and select **“Find server”** in Servergy,
   or enter its address manually.
2. Check the SSH connection and compare the shown SHA-256 fingerprint.
3. Set up Wake-on-LAN afterwards or skip the step for now.

- **Hostname or IP address:** local IP or a fixed local DNS name
- **SSH port:** normally 22
- **SSH username:** for example `servergy`
- **MAC address:** MAC of the WOL-capable wired adapter
- **Broadcast address:** usually the subnet broadcast address, for example
  `192.168.178.255`; `255.255.255.255` does not work on every network
- **UDP port:** normally 9

Then test the SSH connection first, try the shutdown, and finally test
Wake-on-LAN.

## Troubleshooting and VPNs

- Wake-on-LAN needs a route for IPv4 broadcast packets. Many VPNs do not
  forward those packets. To start the server in that case, connect to the home
  network or run a suitable WOL relay in your own network.
- If a new SSH fingerprint appears, cancel the connection and compare it at the
  server with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256`.
  Never trust a changed key blindly.
- If “Shutdown command denied” appears, use `sudo -l -U servergy` to verify
  that only `/usr/local/sbin/servergy-poweroff` is allowed.
- The fact that `sudo shutdown now` works after manually entering a password is
  deliberately not sufficient for Servergy. The app does not run a general
  shutdown command and never stores a sudo password. Install the unit,
  argument-free helper, and single `NOPASSWD` sudoers rule described above;
  only then can the server confirm the safe request with
  `servergy-poweroff-accepted`.
- The app’s diagnostic log contains only time, action, error code, and duration;
  it never exports credentials, keys, host addresses, or MAC addresses.
