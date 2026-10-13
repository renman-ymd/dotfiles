## Passphrase keychains

Research date: 2026-10-13. Revisions seen: nixpkgs `b6c98e9e` (the repo's `flake.lock`, nixpkgs-unstable of 2026-09-22; checked against master `db81a1d5` and `release-26.05` `612b6b07`, both 2026-10-13), Home Manager `0b2f1129` (`flake.lock`, 2026-09-23; master `c58f54c7`, 2026-10-10), nix-darwin `4cff07de` (2026-08-16), macOS 26.5.2 with Apple OpenSSH_10.2p1, nixpkgs OpenSSH 10.5p1, GnuPG 2.4.9 (nixpkgs `gnupg`; upstream stable is 2.5.24, master `bf4fbff8`), pinentry-mac 1.1.1.1, pinentry 1.3.2, gnome-keyring 50.0, gcr 4.4.0.1, systemd 261.2, greetd 0.10.3. Module sources were read from the nixpkgs and Home Manager revisions in `flake.lock`; "evaluated" means I evaluated the module system against that revision (x86_64-linux NixOS, or standalone Home Manager) and read the result, without building anything. Nothing on the Air was changed: the only commands run there were read-only checks, plus a scratch `gpg-agent` in its own throwaway home directory (run in `--server` mode, no sockets) to test config parsing.

### 1. macOS: the SSH key

**Which `ssh` is used.** Apple's `/usr/bin/ssh`, not a nixpkgs OpenSSH.

- Home Manager's `programs.ssh.package` defaults to `null` ("By default, the client provided by your system is used"), and `home.packages` only gets the package when it is non-null ([ssh.nix L613-617, L869](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/ssh.nix#L613-L617)). Locally `which -a ssh` lists only `/usr/bin/ssh` (OpenSSH_10.2p1, LibreSSL 3.3.6).
- nixpkgs OpenSSH has no keychain support: no match for `UseKeychain` or `apple-use-keychain` anywhere under `pkgs/` or `nixos/` at the locked revision. Running the nixpkgs 10.5p1 `ssh -G` against the real `~/.ssh/config` fails with `line 7: Bad configuration option: usekeychain`.
- `IgnoreUnknown UseKeychain` fixes that: with it as the first option, both Apple's `ssh` and nixpkgs' 10.5p1 `ssh -G` accept the config (tested on a scratch file). Apple documents exactly this idiom for configs shared with clients that do not know the keyword ([TN2449](https://developer.apple.com/library/archive/technotes/tn2449/_index.html)). Home Manager emits `IgnoreUnknown` first inside its block ([ssh.nix L509-511](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/ssh.nix#L509-L511)); evaluated output for `settings."*" = { IgnoreUnknown = "UseKeychain"; AddKeysToAgent = "yes"; UseKeychain = "yes"; }` is `Host *` with the three lines in that order.
- The current config has no `IgnoreUnknown`. It works today because no nixpkgs `ssh` is on `PATH`. Two ways that changes: `programs.ssh.package = pkgs.openssh`, and `pkgs.gitFull`, whose `withSsh = true` hard-codes `${openssh}/bin/ssh` ([git package.nix L143-165](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/by-name/gi/git/package.nix#L143-L165), [all-packages.nix L1051-1057](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/top-level/all-packages.nix#L1051-L1057)). The repo uses Home Manager's default `pkgs.git` (`withSsh = false`), so `git`, `jj` (subprocess) and `gh` call whatever `ssh` is on `PATH`.
- The same shared Home Manager module on the Framework would break nixpkgs OpenSSH if it set `UseKeychain` unguarded. Gate it with `pkgs.stdenv.hostPlatform.isDarwin` or keep `IgnoreUnknown`.

**What the two settings do.** From `man ssh_config` on the Air and Apple's note:

- `UseKeychain yes`: "search for passphrases in the user's keychain when attempting to use a particular key", and store the passphrase after the user typed a correct one. Default `no`.
- `AddKeysToAgent yes`: after authenticating with a key, add it to the agent. Since macOS 10.12.2 `ssh` no longer loads keys into the agent by itself ([TN2449](https://developer.apple.com/library/archive/technotes/tn2449/_index.html)).
- Together: the first `ssh` after login reads the passphrase from the keychain, authenticates, and puts the key in the agent. No dialog.
- `ssh-add --apple-use-keychain` stores a passphrase while adding; `ssh-add --apple-load-keychain` adds every keychain-stored identity to the agent. `-K` and `-A` are the older spellings and still work with a warning (`man ssh-add`, `APPLE_SSH_ADD_BEHAVIOR`).
- Apple's agent is `/usr/bin/ssh-agent -l`, started on demand by launchd on the `SSH_AUTH_SOCK` socket, and loads nothing by itself (`/System/Library/LaunchAgents/com.openssh.ssh-agent.plist`).

**Observed on the Air.** The key is passphrase-protected (`ssh-keygen -y -P ""` answers "incorrect passphrase supplied"). `ssh-add -l` lists it in the launchd agent, which fits `AddKeysToAgent yes`. It does not prove the passphrase is in the keychain; I did not touch the keychain.

**What stays imperative.** The passphrase can never be declarative (ADR 0003 keeps secrets out of the repo): once per machine, run `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` (or just `ssh -T git@github.com` and type it once with `UseKeychain yes` set).

**Optional eager load at login** (not needed while only Apple's `ssh` talks to the agent): a nix-darwin `launchd.user.agents.<name>.serviceConfig` running `/usr/bin/ssh-add --apple-load-keychain` with `RunAtLoad = true`. It would help a nixpkgs client or `ssh-keygen -Y sign` that reads the agent without going through Apple's `ssh`. Unverified: that the job sees `SSH_AUTH_SOCK` (launchd's own environment does: `launchctl getenv SSH_AUTH_SOCK` returns the agent socket).

### 2. macOS: GPG passphrase, pinentry-mac and the keychain

**Does pinentry-mac offer "Save in Keychain"? Yes.** Read from the source of the version nixpkgs builds (GPGTools/pinentry `v1.1.1.1`, [KeychainSupport.m](https://github.com/GPGTools/pinentry/blob/v1.1.1.1/macosx/KeychainSupport.m), [AppDelegate.m](https://github.com/GPGTools/pinentry/blob/v1.1.1.1/macosx/AppDelegate.m)):

- gpg-agent sends `SETKEYINFO n/<keygrip>` before asking (`n`, `u` or `s` is the cache mode). The key id is the keygrip of the key being unlocked, so each machine's signing subkey has its own entry ([call-pinentry.c L1490-1502](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/agent/call-pinentry.c#L1490-L1502), [findkey.c L827-868](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/agent/findkey.c#L827-L868)).
- pinentry-mac skips the keychain only for mode `u` (symmetric encryption). Otherwise it first looks up a generic password with service `GnuPG` and account `<keygrip>` and, when found and non-empty, returns it without showing any window.
- It tries the keychain once per pinentry process, and not when gpg-agent reports an error (wrong passphrase). In that case the dialog appears.
- The dialog has a checkbox "Save in Keychain", visible only when a keygrip was sent. On OK with the box ticked and a non-empty passphrase it stores or updates the item (label `Name <email> (keyid)`).
- The nixpkgs build includes it. The bundled prebuilt `Pinentry.nib` contains the strings `Save in Keychain`, `canUseKeychain` and `saveInKeychain`, and the binary contains `GnuPG`, `UseKeychain`, `DisableKeychain`, `KeychainPath` ([mac.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/tools/security/pinentry/mac.nix)).
- Defaults: `UseKeychain` is registered as `YES` in code; `DisableKeychain` and `KeychainPath` are unset. The preference domain is the bundle id `org.gpgtools.pinentry-mac` (plus the `org.gpgtools.common` suite). On the Air neither domain exists, so nothing needs configuring declaratively. The checkbox is ticked by default.
- The nixpkgs pin is one release behind upstream (tag `v1.3.1.1` exists), but the compare view between the tags shows `macosx/Version.config` as the only changed file under `macosx/`, so the keychain code is identical ([compare](https://github.com/GPGTools/pinentry/compare/v1.1.1.1...v1.3.1.1)).
- `no-allow-external-cache` in `gpg-agent.conf` only controls the libsecret path of the Gnome and Qt pinentries; pinentry-mac does not read it (no reference in `macosx/*.m`). The repo does not set it.

**Does it survive gpg-agent restarts? Yes.** The passphrase lives in the login keychain, not in gpg-agent. After `gpgconf --kill gpg-agent`, a reboot or the 10-minute `default-cache-ttl` expiring, gpg-agent asks pinentry again and the keychain answers silently. The TTLs in `gpg-agent.conf` then only decide how often the keychain is read. A changed passphrase shows the dialog once (wrong-passphrase error); ticking the box again overwrites the item. A new subkey has a new keygrip and needs one dialog.

**The one real trap: code identity.** pinentry-mac uses the legacy file-keychain API (`SecKeychain*`, `kSecUseKeychain`).

- The item is created by the pinentry-mac that was running. The store copy is ad-hoc linker-signed (`codesign -dv` on `/nix/store/…-pinentry-mac-1.1.1.1/Applications/pinentry-mac.app`: `flags=0x20002(adhoc,linker-signed)`), so every rebuild is a new identity. If that makes the keychain ask again, it asks for the keychain password, which is exactly the typing this ticket wants gone. If the keychain denies access, the source falls back to the dialog and hides the checkbox (`errSecUserCanceled` and `errSecAuthFailed` paths in `KeychainSupport.m`). Unverified: what macOS 26 does when the signing identity of a keychain item's creator changes. It mirrors the TCC problem already solved in `modules/home.nix`.
- That solution is already in place for this app. `home.activation.resignAdhocApps` re-signs `~/Applications/Home Manager Apps/pinentry-mac.app` with `nix-selfsign`: `codesign -dr -` there prints `designated => identifier "org.gpgtools.pinentry-mac" and certificate leaf = H"e0806991…"`, a requirement that does not change when the store path does. Home Manager copies apps there because `targets.darwin.copyApps.enable` defaults to true for `stateVersion >= 25.11` and the directory is `Applications/Home Manager Apps` ([copyapps.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/targets/darwin/copyapps.nix)).
- `gpg-agent.conf` currently points `pinentry-program` at the store wrapper, which `exec`s the ad-hoc store binary. Pointing it at `~/Applications/Home Manager Apps/pinentry-mac.app/Contents/MacOS/pinentry-mac` gives the stable identity for free.
- A space in the path is fine: an isolated `gpg-agent --server` with `pinentry-program /…/with space/fakepin` ran that program on `GET_PASSPHRASE` (GnuPG 2.4.9).
- Fallback, since `resignAdhocApps` only signs when the `nix-selfsign` certificate exists: without it the copy stays ad-hoc and the setup still works, only with the unstable identity.

### 3. macOS: is Home Manager's `services.gpg-agent` launchd agent usable?

**No, not at the locked Home Manager, and not on master as of 2026-10-10.**

**What the module does.** On Darwin `services.gpg-agent` defines `launchd.agents.gpg-agent` with `ProgramArguments = [ gpg-agent --supervised ]`, `RunAtLoad = cfg.enableSshSupport`, and launchd `Sockets` at `/private/var/run/org.nix-community.home.gpg-agent/S.gpg-agent` (and `.ssh`, `.extra`) ([gpg-agent.nix L455-478](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/services/gpg-agent.nix#L455-L478), socket path L57-65). Master differs from the locked file only in `gcr_3` instead of `gcr`.

**What `--supervised` means.**

- The agent is started by a supervisor that has already bound and is listening on the sockets. It takes them from file descriptor 3 upwards, announced through the systemd `LISTEN_PID`, `LISTEN_FDS` and `LISTEN_FDNAMES` variables (`std`, `ssh`, `extra`, `browser`). Without those variables it logs errors and, if fd 3 is not open, dies with "file descriptor 3 must be valid in --supervised mode" ([gpg-agent.c L670-800, GnuPG 2.4.9](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/agent/gpg-agent.c#L670-L800)).
- launchd does not set those variables. A job with `Sockets` must fetch the descriptors itself through the `launch_activate_socket(3)` API (`man launchd.plist`, `Sockets`), and gpg-agent has no such call (no `launch_activate_socket` in `agent/gpg-agent.c`, 2.4.9 or master). The repo's `modules/darwin.nix` comment ("died at startup on every launch and KeepAlive respawned it") is the expected behaviour, not an accident of that unit.
- Home Manager's own open fix, [PR #8545](https://github.com/nix-community/home-manager/pull/8545) (2026-01), says so and adds a C wrapper that calls `launch_activate_socket`. The Home Manager maintainer asked for it to live in nixpkgs first; it is stalled (`dirty` mergeable state). [PR #5901](https://github.com/nix-community/home-manager/pull/5901) (2024, open) proposed replacing `--supervised` with `--daemon`.
- Independent second problem: where gpg looks for sockets. On the Air `gpgconf --list-dirs socketdir` is `~/.gnupg`: GnuPG only uses `/run/user/<uid>` or `/var/run/user/<uid>` style directories when they exist, and falls back to the home directory otherwise ([homedir.c L1090-1150](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/common/homedir.c#L1090-L1150)). Home Manager's sockets under `/private/var/run/org.nix-community.home.gpg-agent/` are never consulted, so even a working launchd job would sit beside the agent gpg starts itself. Unverified: whether a user agent can create that directory under root-owned `/private/var/run` (`root:daemon`, `drwxrwxr-x`).
- Deprecation: `--supervised` has been deprecated since GnuPG 2.3.6 and was renamed `--deprecated-supervised` in 2.5.3 "as preparation for their removal" ([NEWS](https://github.com/gpg/gnupg/blob/bf4fbff85ad3d5a838b209a6bdb23143ecc30191/NEWS), [doc](https://github.com/gpg/gnupg/blob/bf4fbff85ad3d5a838b209a6bdb23143ecc30191/doc/gpg-agent.texi)). 2.4.9 still prints a deprecation warning. Upstream's table marks 2.4 end-of-life on 2026-06-30 and 2.5.24 as the stable release ([gnupg.org](https://gnupg.org/download/index.html)), while nixpkgs `gnupg` is still `gnupg24` = 2.4.9 on master ([all-packages.nix](https://github.com/NixOS/nixpkgs/blob/db81a1d5ba9fc2b2ac5305557a7342a594e709e4/pkgs/top-level/all-packages.nix)). The day nixpkgs moves `gnupg` to 2.5.x, every `--supervised` unit breaks. That covers the Linux units too: Home Manager's `systemd.user.services.gpg-agent` (evaluated: `ExecStart = gnupg-2.4.9/bin/gpg-agent --supervised`) and NixOS's `programs.gnupg.agent` ([gnupg.nix L122](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/programs/gnupg.nix#L122)). I did not find a nixpkgs or Home Manager issue about it.

**What is usable instead.**

- Nothing: gpg starts the agent on demand (`gpg-agent --homedir … --use-standard-socket --daemon`, running since 25 Sep, PID 4098) in the user's Aqua session, and the keychain mechanism of section 2 does not need a supervisor.
- nix-darwin's `programs.gnupg.agent.enable` runs `gpg-connect-agent /bye` as a launchd agent (`RunAtLoad` only with `enableSSHSupport`), so it only pre-warms the agent and never uses `--supervised` ([gnupg.nix](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/programs/gnupg.nix)). It also puts `GPG_TTY` and optionally `SSH_AUTH_SOCK` into the shell init, which this nushell setup does not use. Not needed.
- Using the typed Home Manager options without the broken job: `services.gpg-agent.enable = true; launchd.agents.gpg-agent.enable = lib.mkForce false;` evaluates and writes `gpg-agent.conf` (with `pinentry.package = pkgs.pinentry_mac`, `defaultCacheTtl`, `maxCacheTtl`) without any launchd plist. The module adds `grab` by default; set `grabKeyboardAndMouse = false` to match today's file. Not recommended here: it hides a forced-off job that stops being forced once PR #8545 or an equivalent lands, and `pinentry.package` cannot express the re-signed app path.

**Stale comments.** `modules/home.nix` ("HM services.gpg-agent is systemd only") is wrong, since the module has a launchd agent on Darwin. `modules/darwin.nix`'s conclusion ("no launchd agent for gpg-agent on purpose") still holds, but its stated cause is incomplete (also the socket directory, and the GnuPG deprecation).

### 4. macOS: recommended setup

Everything below uses option names that exist at the locked revisions (evaluated for the `programs.ssh` and `home.file` forms).

```nix
{ config, pkgs, lib, ... }:
let
  appsDir = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}";
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        IgnoreUnknown = "UseKeychain";
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
      };
      "github.com" = { User = "git"; IdentityFile = "~/.ssh/id_ed25519"; };
    };
  };

  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${appsDir}/pinentry-mac.app/Contents/MacOS/pinentry-mac
    default-cache-ttl 600
    max-cache-ttl 7200
  '';
}
```

`pinentry_mac` stays in `home.packages`. No `services.gpg-agent`, no launchd job for gpg-agent.

**One-time manual steps per Air, per key** (the secret never enters the repo, ADR 0003):

1. `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`, typing the passphrase.
2. Sign something with the signing key (`jj`, or `echo x | gpg --clearsign`), tick "Save in Keychain" in the pinentry-mac dialog. Repeat once per new signing subkey (new keygrip).

**Trade-offs.**

- The passphrases sit in the login keychain, protected by the login password and the legacy per-item ACL. Anything that may read the item (the signed pinentry-mac, or another app after a user "Allow") gets the passphrase without a prompt. This is what the ticket asks for.
- Typed prompts come back if the login keychain is locked (idle or sleep lock in Keychain Access settings) or the item's access is denied. Unverified: the Air's keychain lock settings.
- `IgnoreUnknown` costs nothing on Apple's ssh and protects against the nixpkgs client cases above.

**Live tests on the Air (Renaud):** see "Unverified" at the end.

### 5. Linux: SSH agent options compared

NixOS options read in [gnome-keyring.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/desktops/gnome/gnome-keyring.nix), [gcr-ssh-agent.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/desktops/gnome/gcr-ssh-agent.nix) and [ssh.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/programs/ssh.nix); on master these files are identical to the locked ones, and `release-26.05` differs only in `pkgs.gcr` instead of `pkgs.gcr_3`.

| | Plain ssh-agent | gcr-ssh-agent | gnome-keyring's own SSH component |
|---|---|---|---|
| NixOS option | `programs.ssh.startAgent = true` (systemd user unit running `ssh-agent -a %t/ssh-agent`; `environment.extraInit` exports `SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent`) | `services.gnome.gcr-ssh-agent.enable`. Its default is `config.services.gnome.gnome-keyring.enable`, so enabling gnome-keyring turns it on (evaluated: `true`). Package option `services.gnome.gcr-ssh-agent.package`, default `gcr_4` | Not available: gnome-keyring 48.0 made `ssh-agent` a meson option defaulting to false ([NEWS](https://gitlab.gnome.org/GNOME/gnome-keyring/-/blob/50.0/NEWS), [meson_options.txt](https://gitlab.gnome.org/GNOME/gnome-keyring/-/blob/50.0/meson_options.txt)), and the nixpkgs derivation does not enable it ([package.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/by-name/gn/gnome-keyring/package.nix)). Home Manager's `services.gnome-keyring.components = [ "ssh" ]` therefore has nothing to start (inference from the build flags; not run) |
| Where the passphrase is stored | Nowhere. The agent holds the decrypted key for the session; `AddKeysToAgent yes` loads it on first use and asks via `SSH_ASKPASS` (default `x11_ssh_askpass`) or the tty | The login keyring through libsecret. Its prompt has a checkbox "Automatically unlock this key whenever I'm logged in"; when ticked it stores the passphrase (schema `org.freedesktop.Secret.Generic`, attribute `unique`), and later requests look it up first ([gcr-ssh-agent-interaction.c](https://gitlab.gnome.org/GNOME/gcr/-/blob/4.4.0.1/gcr/gcr-ssh-agent-interaction.c)) | n/a |
| Key discovery | `ssh-add` or `AddKeysToAgent` | Preloads every `~/.ssh/*.pub` and unlocks lazily on first signature; it wraps a stock `ssh-agent` ([gcr-ssh-agent-preload.c L93](https://gitlab.gnome.org/GNOME/gcr/-/blob/4.4.0.1/gcr/gcr-ssh-agent-preload.c#L93), [gcr-ssh-agent.c L73](https://gitlab.gnome.org/GNOME/gcr/-/blob/4.4.0.1/gcr/gcr-ssh-agent.c#L73)). The key needs a `.pub` beside it | n/a |
| Socket and `SSH_AUTH_SOCK` | `$XDG_RUNTIME_DIR/ssh-agent`, exported for you | `$XDG_RUNTIME_DIR/gcr/ssh`; the socket unit runs `systemctl --user set-environment SSH_AUTH_SOCK=…`, but the NixOS module sets no session variable ([gcr-ssh-agent.socket.in](https://gitlab.gnome.org/GNOME/gcr/-/blob/4.4.0.1/gcr/gcr-ssh-agent.socket.in)). A compositor started by a display manager outside the user manager may not inherit it. Unverified: whether the Hyprland session sees it (UWSM would; plain `Hyprland` from greetd or a tty may not). A fixed `environment.sessionVariables.SSH_AUTH_SOCK` would cover it; also unverified |
| Conflicts | Assertion: cannot be enabled together with `gcr-ssh-agent` | Same assertion | |
| Meets "never typed after login" | No (typed once per login, or needs a separate askpass that stores it) | Yes, once the checkbox was ticked and the keyring is unlocked by PAM | n/a |

Home Manager's `services.ssh-agent` runs nixpkgs `ssh-agent` (a launchd agent on macOS too, [ssh-agent.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/services/ssh-agent.nix)). It stores nothing, so it does not help either platform. On macOS it would also bypass Apple's agent.

Not evaluated: KDE's `ksshaskpass` with KWallet as a store for plain `ssh-agent`; the newer `oo7` and `rosec` PAM options in `pam.nix`.

### 6. Linux: pinentry that saves to the Secret Service

- nixpkgs builds every pinentry flavour with libsecret: `withLibsecret ? true` and `--enable-libsecret` ([pinentry/default.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/tools/security/pinentry/default.nix)). The saving logic is in pinentry's common code, not in one flavour ([password-cache.c](https://gnupg.org/ftp/gcrypt/pinentry/pinentry-1.3.2.tar.bz2), [pinentry.c L1630-1651, L1743-1751](https://github.com/gpg/pinentry/blob/pinentry-1.3.2/pinentry/pinentry.c#L1630-L1651), tag `pinentry-1.3.2`).
- It does `secret_password_lookup` by attribute `keygrip` (schema `org.gnupg.Passphrase`) before asking, and `secret_password_store_sync` into `SECRET_COLLECTION_DEFAULT` after a successful entry when the user ticked the box. Same key as on macOS: the keygrip from `SETKEYINFO`. The lookup needs `OPTION allow-external-password-cache`, which gpg-agent sends unless `no-allow-external-cache` is set.
- `pinentry-gnome3` is a GCR prompt. Its checkbox says "Save in password manager" (`default-pwmngr` from gpg-agent) or "Automatically unlock this key, whenever I'm logged in", and it needs the GCR prompter D-Bus service ([pinentry-gnome3.c L221-235](https://github.com/gpg/pinentry/blob/pinentry-1.3.2/gnome3/pinentry-gnome3.c#L221-L235)). `services.gnome.gnome-keyring.enable` adds `pkgs.gcr_3` to `services.dbus.packages`, and `programs.gnupg.agent` also adds D-Bus packages when the chosen pinentry has the `gnome3` flavour. Home Manager's option text warns that `pinentry-gnome3` may not work off GNOME and suggests `gcr_3` (master) or `gcr` (locked) in `home.packages`.
- `pinentry-qt` shows a "save passphrase" checkbox under `HAVE_LIBSECRET` ([pinentrydialog.cpp L255-258](https://github.com/gpg/pinentry/blob/pinentry-1.3.2/qt/pinentrydialog.cpp#L255-L258)). On a KDE session (`XDG_SESSION_DESKTOP=KDE`) the external cache is off unless `PINENTRY_KDE_USE_WALLET` is set ([pinentry.c L1195-1200](https://github.com/gpg/pinentry/blob/pinentry-1.3.2/pinentry/pinentry.c#L1195-L1200)). Under Hyprland it is on. Qt pulls `qt6.qtbase`, `qtwayland` and `kguiaddons`.
- Both write to whichever Secret Service owns `org.freedesktop.secrets`. With gnome-keyring that is the login keyring, so after PAM unlock the lookup is silent. If the keyring is still locked, I expect a keyring-unlock prompt, which is typing (not tested).
- Option names (evaluated): Home Manager `services.gpg-agent.pinentry.package` (renamed from `pinentryPackage`; default `null`, so set it) and `.pinentry.program` (default `meta.mainProgram` = `pinentry`); NixOS `programs.gnupg.agent.pinentryPackage` (default `pinentry-curses`). Use one of the two, not both.
- Recommendation: `pinentry-gnome3`, because gnome-keyring's own prompter is already on D-Bus; `pinentry-qt` only when KWallet is the Secret Service.

### 7. Linux: unlocking the login keyring at login

**Mechanism.** `pam_gnome_keyring.so` stashes the password in the auth stage and, in the session stage with `auto_start`, starts `gnome-keyring-daemon` and hands it the password so the `login` keyring unlocks ([gkr-pam-module.c L880-950](https://gitlab.gnome.org/GNOME/gnome-keyring/-/blob/50.0/pam/gkr-pam-module.c#L880-L950)). With no password (no auth stage ran) it still starts the daemon, but the keyring stays locked and the first request prompts. So the keyring password must equal the login password.

**NixOS options (evaluated unless noted).**

- `security.pam.services.<name>.enableGnomeKeyring` (default false) adds `auth optional pam_gnome_keyring.so`, `password optional … use_authtok` and `session optional … auto_start`.
- `services.gnome.gnome-keyring.enable` sets `security.pam.services.login.enableGnomeKeyring = true`, adds the `gnome-keyring` and `gcr_3` D-Bus packages, the `xdg.portal` portal, and a `security.wrappers.gnome-keyring-daemon` with `cap_ipc_lock=ep` ([gnome-keyring.nix L28-46](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/desktops/gnome/gnome-keyring.nix#L28-L46)).
- `security.pam.services.<name>.kwallet.enable` (+ `.package`, `.forceRun`) is the KWallet equivalent (`pam_kwallet5.so`, the file name KWallet 6's `kwallet-pam` still ships). The Plasma 6 module sets it on `login` and `kde` ([plasma6.nix L331-345](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/desktop-managers/plasma6.nix#L331-L345)).
- Home Manager `services.gnome-keyring` (`enable`, `package`, `components`) is only a systemd user unit running `gnome-keyring-daemon --start --foreground` ([gnome-keyring.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/services/gnome-keyring.nix)). It has no PAM and no `cap_ipc_lock` wrapper. On NixOS use the NixOS module instead.
- The login rules are shared. `login` carries the keyring rules, and several display-manager PAM services pull `login` in; the others do their own thing.

**Per login-manager family** (NixOS locked revision, PAM text evaluated for greetd, SDDM and GDM with `services.gnome.gnome-keyring.enable = true`; tty `login` evaluated too):

| Family | PAM service and wiring | Keyring unlocked after a password login | Autologin |
|---|---|---|---|
| greetd (`services.greetd`; tuigreet, regreet, gtkgreet) | `greetd`: `auth`/`password` `substack login`, `account`/`session` `include login` on unstable and the locked revision ([greetd.nix L79-110](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/display-managers/greetd.nix#L79-L110)). `release-26.05` instead has `enableGnomeKeyring = lib.mkDefault config.services.gnome.gnome-keyring.enable`. | Yes with just `services.gnome.gnome-keyring.enable = true`; both branches end with the three `pam_gnome_keyring` lines. | `services.greetd.settings.initial_session` starts an unauthenticated session: greetd 0.10.3 skips `pam_authenticate` for it (`if authenticate {` in [worker.rs L129](https://git.sr.ht/~kennylevinsen/greetd/tree/0.10.3/item/greetd/src/session/worker.rs); `start_user_session` calls `start_unauthenticated_session`, [context.rs](https://git.sr.ht/~kennylevinsen/greetd/tree/0.10.3/item/greetd/src/context.rs)). No authtok exists, so keyring stays locked and `pam_systemd_loadkey`, an auth module, cannot run (inference from source). Unit has `KeyringMode = "shared"`. |
| SDDM (`services.displayManager.sddm`) | `sddm`: `include`/`substack login` for all four stages; `sddm-autologin`: auth only `nologin`, `succeed_if uid >= 1000`, `permit`; the other stages `include sddm` ([sddm.nix L371-500](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/display-managers/sddm.nix#L371-L500)). | Yes with `services.gnome.gnome-keyring.enable = true`. For KWallet set `security.pam.services.login.kwallet.enable = true`. `security.pam.services.sddm.kwallet.enable` and `.enableGnomeKeyring` are no-ops: `sddm` has `useDefaultRules = false` and its rules are only the `login` includes (evaluated). | `sddm-autologin` has no password stage: keyring locked. Documented route: add `pam_systemd_loadkey` and `pam_gnome_keyring` to that service's auth stack (see below). Evaluated option shape works on GDM; not evaluated on SDDM. `display-manager.service` has default `KeyringMode=private`, which hides root's keyring; needs `shared` or `inherit` (unverified). |
| GDM (`services.displayManager.gdm`) | `gdm-password`: `substack login`; `gdm-autologin`: `nologin`, `succeed_if`, `pam_gdm.so`, then `pam_gnome_keyring` (both gated on `login.enableGnomeKeyring`), `permit` ([gdm.nix L493-565](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/display-managers/gdm.nix#L493-L565)). | Yes with `services.gnome.gnome-keyring.enable = true`. | The only manager whose autologin stack already contains `pam_gnome_keyring`. Without an authtok it still stays locked. `pam_systemd_loadkey` is one added rule (evaluated, below), but its place relative to `pam_gdm.so` (`[success=ok default=1]`) is unverified. `KeyringMode = "shared"` is already set. |
| None / tty (`login`, `getty`) | `login` itself: auth `pam_unix` (early, optional) then `pam_gnome_keyring`, then `pam_unix`; session `pam_gnome_keyring … auto_start` (evaluated). | Yes with `services.gnome.gnome-keyring.enable = true`; then start Hyprland from the shell (`programs.hyprland.enable` or UWSM). Unverified: that the secrets D-Bus activation attaches to the daemon PAM started when the session bus comes up later. | `services.getty.autologinUser` runs agetty's autologin, which skips authentication (inference): keyring stays locked, `loadkey` not applicable. |

Other managers seen in the source: `ly` uses the same `include login` pattern, `lemurs` sets `enableGnomeKeyring = lib.mkDefault config.services.gnome.gnome-keyring.enable`, `cosmic-greeter` and `plasma-login-manager` were not checked for keyring wiring.

**LUKS, autologin and one passphrase.** systemd 255 added `pam_systemd_loadkey.so` for "auto-unlock of the GNOME Keyring / KDE Wallet when autologin is configured" ([NEWS, CHANGES WITH 255](https://github.com/systemd/systemd/blob/v261/NEWS), [man page](https://github.com/systemd/systemd/blob/v261/man/pam_systemd_loadkey.xml)). It reads the passphrase `systemd-cryptsetup@.service` stored in root's kernel `user` keyring (key name `cryptsetup`) and sets it as the PAM authtok, so `pam_gnome_keyring` unlocks with the LUKS passphrase. Requirements stated by the man page:

- the keyring password equals the LUKS passphrase;
- `auth optional pam_systemd_loadkey.so` before `auth optional pam_gnome_keyring.so`, and `KeyringMode=inherit` on the display manager's unit, so it can read root's keyring (`shared` also links the unit's user keyring, [systemd.exec](https://github.com/systemd/systemd/blob/v261/man/systemd.exec.xml); not tested);
- a service whose auth stack actually runs: not greetd's `initial_session`, not agetty autologin.

NixOS exposes no option for this module (no `loadkey` match under `nixos/`). It can be added with the generic rule interface; evaluated against the locked revision for `gdm-autologin`, producing `auth optional …/pam_systemd_loadkey.so # systemd_loadkey (order 10390)` just before `pam_gnome_keyring` (order 10400):

```nix
security.pam.services.gdm-autologin.rules.auth.systemd_loadkey = {
  order = config.security.pam.services.gdm-autologin.rules.auth.gnome_keyring.order - 10;
  control = "optional";
  modulePath = "${config.systemd.package}/lib/security/pam_systemd_loadkey.so";
};
```

`pam_systemd_loadkey.so` exists in the `systemd-261.2` output of the locked nixpkgs (`lib/security/` on cache.nixos.org lists `pam_systemd.so`, `pam_systemd_home.so`, `pam_systemd_loadkey.so`). Whether the cryptsetup passphrase reaches the keyring requires `boot.initrd.systemd.enable = true` (inference: systemd-cryptsetup only runs in a systemd initrd; the option exists, not evaluated for this effect). Unverified end to end on NixOS. The ordinary alternative is no autologin: one greeter password, no more typing, and nothing to wire.

### 8. Linux: recommended setup (provisional, waits for ticket 19)

For every family, assuming a password login (greeter or tty):

```nix
# NixOS
services.gnome.gnome-keyring.enable = true;   # PAM unlock via `login`, D-Bus secrets, gcr prompter, gcr-ssh-agent on
# programs.ssh.startAgent stays false (assertion with gcr-ssh-agent)
# no per-family PAM option needed for greetd, SDDM, GDM or tty

# Home Manager
services.gpg-agent = {
  enable = true;
  pinentry.package = pkgs.pinentry-gnome3;
};
programs.ssh.settings."*".AddKeysToAgent = "yes";   # harmless with gcr-ssh-agent
# `SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh` must reach the Hyprland session (unverified how)
```

Per family: the only differences are PAM-side and show up with autologin (section 7 table). With KWallet as the Secret Service (SDDM + Plasma), swap in `security.pam.services.login.kwallet.enable = true` and `pinentry-qt`.

Trade-offs: gcr-ssh-agent needs the `.pub` file next to each key and the GNOME prompter; the keyring password must stay equal to the login password; the first use of each key and subkey needs one tick of the "unlock automatically" checkbox; both gpg-agent unit generators use the deprecated `--supervised`.

### 9. Consequences for other tickets

- **Ticket 06:** the comment `# HM services.gpg-agent is systemd only` is wrong but the fix should not enable the module on Darwin. Suggested wording: Home Manager's `services.gpg-agent` has a launchd agent on Darwin, unusable because it runs `gpg-agent --supervised` without `LISTEN_FDS` and uses sockets GnuPG does not look in; gpg-agent starts on demand.
- **Ticket 15 (keys feature):** the Darwin part should set `IgnoreUnknown`, point `pinentry-program` at the re-signed copy under `Applications/Home Manager Apps`, and not enable `services.gpg-agent`. The Linux part uses `services.gpg-agent` (with the `--supervised` risk) and `pinentry-gnome3`. `UseKeychain` must not reach a nixpkgs client unguarded. First-use steps (keychain seed, tick the box) belong in the machine enrollment steps, one per signing subkey.
- **Ticket 19 (login manager):** with a password login nothing in the choice matters for keyring unlock (greetd, SDDM, GDM, tty all reuse `login`). Autologin is the discriminator: greetd `initial_session` and getty autologin cannot unlock the keyring at all; SDDM and GDM can in principle via `pam_systemd_loadkey` plus a systemd initrd and a shared LUKS/login/keyring passphrase, untested. SDDM needs the extra `KeyringMode` change; GDM already ships the pieces except the `loadkey` rule.

### Unverified

On the Air (Renaud to test; none of this was run, and the keychain was not touched):

1. After the `pinentry-program` change, `echo x | gpg --clearsign -u <signing key>` shows the dialog once; tick "Save in Keychain". Then `gpgconf --kill gpg-agent` and sign again: no dialog. Also after the 600 s TTL.
2. After logout and login (or reboot): `ssh -T git@github.com` asks nothing; `ssh-add -l` then lists the key. Run `ssh-add -D` first to start from an empty agent.
3. Whether the keychain asks again after `pinentry_mac` is rebuilt (store path change) with the re-signed copy as `pinentry-program`; and what it does with the current store-wrapper path. `security find-generic-password -s GnuPG` (without `-w`, attributes only) shows what items exist and who may read them.
4. Keychain lock settings (Keychain Access, login keychain, "Lock after … minutes" and "Lock when sleeping").
5. The re-signed `pinentry-mac.app` was confirmed on this Air (`Authority=nix-selfsign`, stable requirement). On a Mac without the `nix-selfsign` certificate the script only warns and the copy stays ad-hoc; that is read from the script, not run.

Not established by sources or tests:

- Whether macOS 26 prompts for keychain access when the creating binary's signing identity changes (section 2).
- Whether a user launchd agent can create `/private/var/run/org.nix-community.home.gpg-agent/` (section 3), which only matters if that module is ever used.
- Everything Linux that needs a running NixOS session: `SSH_AUTH_SOCK` reaching a Hyprland session, the tty-login D-Bus attachment, gcr-ssh-agent plus pinentry-gnome3 end to end, `pam_systemd_loadkey` with `boot.initrd.systemd`, its position against `pam_gdm.so`, `KeyringMode` on SDDM. Also whether `cosmic-greeter` and `plasma-login-manager` wire the keyring.
- Whether `components = [ "ssh" ]` in Home Manager's `services.gnome-keyring` is silently ignored by the nixpkgs build (inferred from the missing meson flag).
- Which nixpkgs release first bumps `gnupg` to 2.5.x, and whether Home Manager and NixOS will have dropped `--supervised` by then.

### Sources

- Repo files read: `modules/home.nix` (`programs.ssh`, `programs.gpg`, `home.file.".gnupg/gpg-agent.conf"`, `resignAdhocApps`), `modules/darwin.nix` (gpg-agent comment), `flake.lock`, `Workspace/research/docs/research/multi-machine-nix/02-secrets.md`, `README.md`, ADRs 0001 and 0003.
- Local read-only observations on the Air: `which -a ssh`, `ssh -V`, `ssh -G`, `man ssh_config`, `man ssh-add`, `man launchd.plist`, `ssh-add -l`, `ssh-keygen -y -P ""`, `launchctl getenv SSH_AUTH_SOCK`, `/System/Library/LaunchAgents/com.openssh.ssh-agent.plist`, `gpgconf --list-dirs`, `gpgconf --list-options gpg-agent`, `codesign -dv` / `-dr -` on the store and Home Manager copies of pinentry-mac, `defaults read org.gpgtools.*`, `ls -ld /private/var/run`, and the scratch tests described above.
- Apple: [TN2449 OpenSSH updates in macOS 10.12.2](https://developer.apple.com/library/archive/technotes/tn2449/_index.html).
- pinentry-mac: [KeychainSupport.m](https://github.com/GPGTools/pinentry/blob/v1.1.1.1/macosx/KeychainSupport.m), [AppDelegate.m](https://github.com/GPGTools/pinentry/blob/v1.1.1.1/macosx/AppDelegate.m), [PinentryMac.m](https://github.com/GPGTools/pinentry/blob/v1.1.1.1/macosx/PinentryMac.m), [Info.plist](https://github.com/GPGTools/pinentry/blob/v1.1.1.1/macosx/Info.plist), [compare v1.1.1.1...v1.3.1.1](https://github.com/GPGTools/pinentry/compare/v1.1.1.1...v1.3.1.1); nixpkgs [mac.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/tools/security/pinentry/mac.nix).
- GnuPG: [gpg-agent.c 2.4.9](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/agent/gpg-agent.c), [call-pinentry.c 2.4.9](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/agent/call-pinentry.c), [findkey.c 2.4.9](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/agent/findkey.c), [homedir.c 2.4.9](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/common/homedir.c), [gpg-agent.c master](https://github.com/gpg/gnupg/blob/bf4fbff85ad3d5a838b209a6bdb23143ecc30191/agent/gpg-agent.c), [NEWS master](https://github.com/gpg/gnupg/blob/bf4fbff85ad3d5a838b209a6bdb23143ecc30191/NEWS), [gpg-agent.texi master](https://github.com/gpg/gnupg/blob/bf4fbff85ad3d5a838b209a6bdb23143ecc30191/doc/gpg-agent.texi), [download page with end-of-life table](https://gnupg.org/download/index.html).
- pinentry 1.3.2 (tag `pinentry-1.3.2`): [pinentry.c](https://github.com/gpg/pinentry/blob/pinentry-1.3.2/pinentry/pinentry.c), [password-cache.c](https://github.com/gpg/pinentry/blob/pinentry-1.3.2/pinentry/password-cache.c), [pinentry-gnome3.c](https://github.com/gpg/pinentry/blob/pinentry-1.3.2/gnome3/pinentry-gnome3.c), [pinentrydialog.cpp](https://github.com/gpg/pinentry/blob/pinentry-1.3.2/qt/pinentrydialog.cpp); nixpkgs [pinentry/default.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/tools/security/pinentry/default.nix).
- Home Manager at `0b2f1129`: [gpg-agent.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/services/gpg-agent.nix), [ssh.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/ssh.nix), [gnome-keyring.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/services/gnome-keyring.nix), [ssh-agent.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/services/ssh-agent.nix), [copyapps.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/targets/darwin/copyapps.nix); [PR #8545](https://github.com/nix-community/home-manager/pull/8545), [PR #5901](https://github.com/nix-community/home-manager/pull/5901), [PR #5786](https://github.com/nix-community/home-manager/pull/5786) (added the launchd agent), [commit 7a62d637](https://github.com/nix-community/home-manager/commit/7a62d637072e1f5609fac7031b287e1adfd26771) (gui domain).
- nix-darwin: [programs/gnupg.nix at 4cff07de](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/programs/gnupg.nix).
- nixpkgs at `b6c98e9e`: [gnome-keyring.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/desktops/gnome/gnome-keyring.nix), [gcr-ssh-agent.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/desktops/gnome/gcr-ssh-agent.nix), [programs/ssh.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/programs/ssh.nix), [programs/gnupg.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/programs/gnupg.nix), [security/pam.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/security/pam.nix), [greetd.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/display-managers/greetd.nix), [sddm.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/display-managers/sddm.nix), [gdm.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/display-managers/gdm.nix), [ly.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/display-managers/ly.nix), [lemurs.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/display-managers/lemurs.nix), [plasma6.nix](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/nixos/modules/services/desktop-managers/plasma6.nix), [gnome-keyring package](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/by-name/gn/gnome-keyring/package.nix), [gcr_4 package](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/by-name/gc/gcr_4/package.nix), [git package](https://github.com/NixOS/nixpkgs/blob/b6c98e9e6633ee64753b594ff4a5febf0367fc00/pkgs/by-name/gi/git/package.nix); master `db81a1d5` and `release-26.05` `612b6b07` versions of the keyring, gcr, gnupg, ssh and greetd modules compared by `diff`.
- GNOME: [gnome-keyring 50.0 NEWS](https://gitlab.gnome.org/GNOME/gnome-keyring/-/blob/50.0/NEWS), [meson_options.txt](https://gitlab.gnome.org/GNOME/gnome-keyring/-/blob/50.0/meson_options.txt), [pam/gkr-pam-module.c](https://gitlab.gnome.org/GNOME/gnome-keyring/-/blob/50.0/pam/gkr-pam-module.c); gcr 4.4.0.1: [gcr-ssh-agent.socket.in](https://gitlab.gnome.org/GNOME/gcr/-/blob/4.4.0.1/gcr/gcr-ssh-agent.socket.in), [gcr-ssh-agent.service.in](https://gitlab.gnome.org/GNOME/gcr/-/blob/4.4.0.1/gcr/gcr-ssh-agent.service.in), [gcr-ssh-agent-interaction.c](https://gitlab.gnome.org/GNOME/gcr/-/blob/4.4.0.1/gcr/gcr-ssh-agent-interaction.c), [gcr-ssh-agent-preload.c](https://gitlab.gnome.org/GNOME/gcr/-/blob/4.4.0.1/gcr/gcr-ssh-agent-preload.c), [gcr-ssh-agent.c](https://gitlab.gnome.org/GNOME/gcr/-/blob/4.4.0.1/gcr/gcr-ssh-agent.c).
- systemd v261: [NEWS](https://github.com/systemd/systemd/blob/v261/NEWS), [pam_systemd_loadkey.xml](https://github.com/systemd/systemd/blob/v261/man/pam_systemd_loadkey.xml), [crypttab.xml](https://github.com/systemd/systemd/blob/v261/man/crypttab.xml), [systemd.exec.xml](https://github.com/systemd/systemd/blob/v261/man/systemd.exec.xml).
- greetd 0.10.3: [context.rs](https://git.sr.ht/~kennylevinsen/greetd/tree/0.10.3/item/greetd/src/context.rs), [session/worker.rs](https://git.sr.ht/~kennylevinsen/greetd/tree/0.10.3/item/greetd/src/session/worker.rs).
- Evaluation scratch files (not committed): `/private/tmp/claude-501/-Users-renman-ymd--config-nix-darwin/87e8b36d-45ee-404b-b1de-4ecd627155f6/scratchpad/t03/` (`eval.nix`, `cfg*.nix`, `hm-ssh.nix`, `hm-linux.nix`).
