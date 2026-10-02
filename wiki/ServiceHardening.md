# ServiceHardening

LaunchPad replaces systemd, so the confinement half of a unit file has to be
declared in the `.service` file and applied by the daemon. This page is the
per service policy for the live ISO and the installed system.

The format is documented in the LaunchPad library wiki, page
[ServiceHardening format](https://github.com/TontooOS/Libs) under
`wiki/Hardening.md`. The application order and the failure behavior are in the
LaunchPad daemon wiki under `wiki/Hardening.md`.

## Policy Matrix

| Service | User | no_new_privs | private_tmp | protect_system | Limits | Notes |
|---|---|---|---|---|---|---|
| `seatd` | root | yes | yes | full | 256M / 512 | No capability list, see below |
| `dbus` | root | yes | yes | full | 256M / 512 | |
| `networkmanager` | root | yes | yes | full | 512M / 1024 | No capability list, see below |
| `network-fix` | root | yes | yes | full | 128M / 256 | |
| `live-setup` | root | yes | yes | full | 512M / 1024 | Creates the session account |
| `FishPerms` | root | yes | yes | full | 256M / 512 | Reads `/System`, `/Applications` |
| `SettingsDaemon` | root | yes | yes | full | 512M / 1024 | Reads `/System`, `/Applications` |
| `tapp-binfmt` | root | yes | yes | full | 128M / 256 | Registers the `binfmt_misc` handler |
| `ttyS0` | root | yes | yes | full | none | agetty |
| `pipewire` | session | yes | yes | full | 256M / 512 | Was `root` |
| `wireplumber` | session | yes | yes | full | 256M / 512 | Was `root` |
| `pipewire-pulse` | session | yes | yes | full | 256M / 512 | Was `root` |
| `compositor` | liveuser | yes | yes | full | 1G / 4096 | |
| `dock` | liveuser | yes | yes | full | 512M / 1024 | |
| `menubar` | liveuser | yes | yes | full | 512M / 1024 | |
| `theme` | liveuser | yes | yes | full | 256M / 256 | |
| `sshd` | root | **no** | **no** | **no** | 256M / 512 | Deliberately unconfined, see below |

Limits are `memory_max` over `tasks_max`. No service uses `cpu_quota`, because
a desktop daemon that gets CPU throttled shows up as stutter rather than as an
error, and a wrong value is hard to attribute.

`protect_system: full` only remounts `/usr` and `/boot`. Every starter script
in `/usr/local/bin` writes to `/run`, `/run/user` or
`/proc/sys/fs/binfmt_misc` and nothing to `/usr`, so `full` is safe for all of
them. `strict` is used by nothing: it also covers `/var` and `/run`, which
breaks every daemon that keeps state.

## Audio Runs As The Session User

`pipewire`, `wireplumber` and `pipewire-pulse` were `user: root`. PipeWire is
designed as a per user daemon, and a root audio server means a parser bug in
the microphone or screen capture path is a root bug.

They now use `user: session`, which the daemon resolves at spawn time. That is
also why the installer no longer has to rewrite them: the account is the same
on the live ISO (`liveuser`) and on an installed system.

`pipewire` depends on `live-setup`, because on the live ISO the account is
created by that service and the audio server would otherwise try to resolve an
account that does not exist yet. On an installed system `live-setup` is absent
and a missing dependency is skipped, so the same file works for both.

The session account is resolved from `TONTOO_SESSION_USER`, then the `utmp`
record of the logged in user, then the first regular account in `/etc/passwd`.
The last step is what makes the audio stack work before anyone logs in.

## Deliberate Gaps

Three services are not fully confined, on purpose. Each one is a case where
guessing wrong costs a broken machine rather than a warning in a log.

| Service | What is missing | Why |
|---|---|---|
| `sshd` | `no_new_privs`, `private_tmp`, `protect_system` | Privilege separation needs its capability set and a private `/tmp`. Getting either wrong locks out remote access to a machine with no console |
| `networkmanager` | `capabilities` | Needs a wide set for netlink, DHCP privilege dropping and network namespaces. A wrong list breaks DHCP silently |
| `seatd` | `capabilities` | Behaves like a mini logind and needs `CAP_SYS_ADMIN` plus the session capability set |

`compositor`, `dock`, `menubar` and `theme` still hardcode `user: liveuser`
and are rewritten by the installer. Switching them to `user: session` is a
follow up; the placeholder exists and works, it just has not been done yet so
the installer keeps its current, tested rewrite path.

## Device Filter Is Not In Use

`device_allow` is implemented in the daemon but no service file uses it. The
cgroup v2 device filter is hand assembled BPF, and the only proof that the
bytecode is correct is the kernel verifier accepting it:

```bash
sudo cargo test bpf::tests::the_kernel_verifier_accepts_the_program -- --nocapture
```

That check cannot run under WSL2 or in most containers, where the `bpf` syscall
is refused even for a two instruction program. Until the test has passed on
real hardware, no service may depend on the filter, because a service that
declared a device list and could not get one would refuse to start.

## Verifying A Change

Every `.service` file must parse through the real parser, not by eye. A quick
check from the LaunchPad library:

```bash
cargo test --lib types
```

The parser rejects an unknown capability, a malformed device rule, a bad enum
value and a misspelled boolean at load time, so a typo in these files fails
loudly instead of silently granting the wrong privilege.

## Cross References

- [Installer.md](Installer.md) - Which service files reach the target
- [MAIN.md](MAIN.md) - Changelog
