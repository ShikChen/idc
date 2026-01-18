# devicectl Overview

`devicectl` is a command line tool that exercises CoreDevice functionality for
connected Apple devices. Standard output is for humans and is not guaranteed to
be stable across releases. For automation, use `--json-output <path>` because
JSON output to a file is the only supported interface for scripts.

## Common Options

These options are supported by most subcommands:

- `--verbose` / `--quiet`: adjust logging output
- `--timeout <seconds>`: overall command timeout
- `--json-output <path>`: write machine-readable results to a file
- `--log-output <path>`: write all logging to a file

## Device Selector

Most device subcommands require a device identifier via `--device`:

- `uuid`
- `ecid`
- `serial_number`
- `udid`
- `name`
- `dns_name`

Example:

```sh
xcrun devicectl device info details --device <udid>
```

## Top-Level Commands

- `list`: list things CoreDevice knows about
- `device`: interact with a specific device
- `manage`: manage pairing and host state
- `diagnose`: gather diagnostic information

---

# list

## list devices

Lists devices known to CoreDevice. Supports filtering and column selection.

```sh
xcrun devicectl list devices
```

## list preferredDDI

Shows which Developer Disk Image (DDI) CoreDevice would use for a platform.

```sh
xcrun devicectl list preferredDDI --platform iOS
```

---

# device

## device info

Commands that provide information about a specific device:

- `apps`: list installed apps (supports include options and filters)
- `processes`: list running processes
- `files`: list files on the device (domain-based)
- `details`: device details
- `displays`: display information
- `lockState`: lock state
- `authListing`: auth listing identifiers
- `ddiServices`: DDI services status
- `appIcon`: request app icon generation

Example:

```sh
xcrun devicectl device info apps --device <udid> --include-all-apps
```

## device install

Installs content onto a device.

- `app`: install an app bundle (a `.app` path)

```sh
xcrun devicectl device install app --device <udid> <path-to-app>
```

## device uninstall

Uninstalls content from a device.

- `app`: uninstall by bundle identifier

```sh
xcrun devicectl device uninstall app --device <udid> <bundle-id>
```

## device copy

Copy files to or from a device. Uses file service domains:

- `temporary`
- `appDataContainer`
- `appGroupDataContainer`
- `systemCrashLogs`

Subcommands:

- `to`: copy to device
- `from`: copy from device

```sh
xcrun devicectl device copy to \
  --device <udid> \
  --source <local-path> \
  --domain-type appDataContainer \
  --domain-identifier <bundle-id>
```

## device notification

Post or observe Darwin notifications on a device.

- `post`
- `observe`

## device orientation

Query or set the simulated physical orientation (only supported devices).

- `get`
- `set`
- `rotate`

## device process

Interact with processes on the device:

- `launch`: launch an app (bundle id or path), pass args/env, optional activate
- `terminate`: terminate a process by PID
- `signal`: send a signal
- `suspend` / `resume`
- `sendMemoryWarning`

```sh
xcrun devicectl device process launch --device <udid> <bundle-id> --activate
```

## device reboot

Reboot a device (full or userspace). Can wait for device availability.

```sh
xcrun devicectl device reboot --device <udid> --style full --wait-for-device
```

## device sysdiagnose

Gather a sysdiagnose archive for a device.

```sh
xcrun devicectl device sysdiagnose --device <udid>
```

---

# manage

Manage device pairing and host state.

- `ddis clean`: remove DDIs on the host
- `ddis update`: update DDIs on the host
- `loggingProfile register`: enable CoreDevice host logging profile
- `pair`: pair with a device
- `unpair`: unpair a manually paired device

---

# diagnose

Collect diagnostics from the host and connected devices (devices must have a
mounted DDI). Supports archiving options and timeouts.

```sh
xcrun devicectl diagnose --timeout 3600
```
