## Handing over to the Lix uninstaller

Research date: 2026-10-13. Versions read: lix-installer `main` at commit [40ef289](https://git.lix.systems/lix-project/lix-installer/commit/40ef289e4c83cbe671f523224d874137203d7400) (Cargo version 3.95.0, last commit 2026-03-22; the bootstrap script served at `install.lix.systems/lix` is byte-identical to this commit's `lix-installer.sh`, diffed today) and the latest git tag, [2.94.0](https://git.lix.systems/lix-project/lix-installer/src/tag/2.94.0/) (commit 81a5d13, 2025-11-18, on the `legacy` branch, Cargo version 0.17.1). Both were read as source tarballs; nothing was built or run. "Observed locally" means a read-only command on this Mac (macOS 26.5.2) that has a Lix installer 3.95.0 install (receipt `version` is `3.95.0`, installed 2026-04-02). The command is named where it matters. Anything marked **Unverified** is not established by a primary source, and the throwaway-instance test (checklist in section 8) must observe it.

Which binary `install.lix.systems/lix` serves today is **Unknown**: the git tags stop at 2.94.0, while this Mac's receipt and the served script match `main`. So `main` is treated as the reference and the tag is compared where it differs. Links below are pinned to `main@40ef289` unless they say `tag 2.94.0`.

### 1. What the uninstaller does, in order

- The plan is reverted in reverse order, one action at a time. An error in one action is collected and the loop goes on; the process exits non-zero at the end ("Uninstallation complete, some errors encountered"). The receipt is not rewritten after a failed uninstall, so a rerun reverts everything again ([plan.rs L309-L340](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/plan.rs#L309), [uninstall.rs](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/cli/subcommand/uninstall.rs)).
- It never kills a process, never lists open files and never ejects. A grep of `src/` for `lsof`, `fuser`, `kill`, `pkill` and `eject` finds only an unrelated `SIGKILL` retry comment in `create_user.rs`.
- `uninstall` re-executes itself through `sudo --set-home` when not root, passing through only `RUST_LOG`, `RUST_BACKTRACE`, `GITHUB_PATH`, `SHELL`, the proxy variables and `NIX_INSTALLER*` ([cli/mod.rs L167](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/cli/mod.rs#L167)). `--no-confirm` (or `NIX_INSTALLER_NO_CONFIRM`) skips the prompt; the receipt path is an optional positional argument defaulting to `/nix/receipt.json`.
- macOS plan order: `CreateNixVolume`, `ProvisionNix`, `CreateUsersAndGroups`, `SetTmutilExclusions`, `ConfigureNix`, `ConfigureRemoteBuilding`, `CreateNixHookService` (only when profile modification is on), `ConfigureInitService`, `RemoveDirectory` of the scratch dir ([planner/macos/mod.rs L277-L369](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/planner/macos/mod.rs#L277)). The receipt on this Mac lists the same actions in that order (observed with `python3 -I` reading `/nix/receipt.json`).
- The uninstaller refuses to start on macOS while `darwin-rebuild` or `darwin-option` is on `PATH` or `system/org.nixos.activate-system` is loaded ([macos/mod.rs L456, L475](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/planner/macos/mod.rs#L475)). Not a concern on a work Mac, which has no nix-darwin.

`CreateNixVolume` is the first action of the plan and so the last one reverted. Its own revert order is: ownership (no-op), `launchctl stop` of the volume job, `bootout` of `org.nixos.darwin-store`, delete its plist, drop the `/nix` line from `/etc/fstab`, `diskutil unmount force "Nix Store"`, volume deletion, keychain item deletion, drop the `nix` line from `/etc/synthetic.conf`, then `apfs.util -t` and `apfs.util -B` ([create_nix_volume.rs L277-L340](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_nix_volume.rs#L277)).

What it does at the volume step on `main`:

- `UnmountApfsVolume::revert` and `CreateApfsVolume::revert` each run `diskutil info -plist "Nix Store"` and, if a mount point is reported, `diskutil unmount force "Nix Store"` ([unmount_apfs_volume.rs L111](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/unmount_apfs_volume.rs#L111), [create_apfs_volume.rs L126](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_apfs_volume.rs#L126)).
- It then runs `diskutil apfs deleteVolume "Nix Store"`, retried 10 times at 500 ms intervals ([create_apfs_volume.rs L159](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_apfs_volume.rs#L159)).
- If the forced unmount itself fails, the action returns the error at once: no `deleteVolume` is attempted, and the keychain item is deliberately kept ("avoid deleting the encryption password if volume deletion failed", [create_nix_volume.rs L306-L321](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_nix_volume.rs#L306)).
- Everything reverted before that point stays reverted. A busy-volume failure therefore leaves a machine with the daemon, users, `/etc/nix`, the fstab line and the volume's LaunchDaemon gone, but the volume (77.5 GB on this Mac) still on disk with its encryption password in the System keychain and the receipt on it. The Nix manual's advice for that case is to "reboot and immediately delete the volume before starting any other process" ([uninstall.md, tag 2.35.2](https://github.com/NixOS/nix/blob/2.35.2/doc/manual/source/installation/uninstall.md)).
- `diskutil unmount force` is "less kind to any open files" and "gives up and returns failure after a maximum of 1 minute in most situations" (`man diskutil`, observed locally). `umount -f` is documented as: active special devices continue to work, "but all other files return errors if further accesses are attempted" (`man 8 umount`, observed locally).

Differences in tag 2.94.0 ([create_apfs_volume.rs L125-L165](https://git.lix.systems/lix-project/lix-installer/src/tag/2.94.0/src/action/macos/create_apfs_volume.rs#L125)): the mounted test is inverted (`if !currently_mounted { diskutil unmount force }`), so a mounted volume is never force-unmounted by Lix; `deleteVolume` runs once with no retry. **Unverified:** whether `diskutil apfs deleteVolume` unmounts a mounted, idle volume by itself (the man page says nothing; `diskutil apfs deleteVolume` text only says all data is lost). The fix landed between the two versions; DetSys issue 647 is cited in the source as the reason for the unmount step.

### 2. Does it succeed when the uninstaller binary sits on the volume?

**Answer from source: not by design, and on `main` the protection is broken.** Not established: what the kernel does to a process whose executable lives on a volume that is force-unmounted under it.

- The installer copies itself to `/nix/nix-installer` on every version read ([install/mod.rs L405](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/cli/subcommand/install/mod.rs#L405), [tag 2.94.0 install.rs L393](https://git.lix.systems/lix-project/lix-installer/src/tag/2.94.0/src/cli/subcommand/install.rs#L393)). Observed locally: `/nix/nix-installer` exists (7,441,712 bytes, owner uid 501, mode 755); `/nix/lix-installer` does not.
- The README, and so the plan in the ticket, name `/nix/lix-installer` ([README](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/README.md)). That path is wrong for installs made by 3.95.0. The same wrong name appears in the macOS hook job: the plist says `/bin/wait4path /nix/lix-installer && /nix/lix-installer repair` ([create_nix_hook_service.rs L175](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_nix_hook_service.rs#L175)). Observed locally: `/Library/LaunchDaemons/systems.lix.nix-installer.nix-hook.plist` has exactly that text, and `ps` shows `/bin/wait4path /nix/lix-installer` (pid 1049) waiting forever for a file that never appears. The "re-add Nix to the shell rc after macOS upgrades" hook is therefore dead on 3.95.0 installs.
- The uninstaller has a guard for exactly the question asked: if `current_exe()` equals the installer's own copy, it copies itself into `temp_dir()` and `execv`s the copy, because "the binary would delete itself" ([uninstall.rs L72-L111](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/cli/subcommand/uninstall.rs#L72)). On `main` the guard compares against `/nix/lix-installer` (L77), which never exists, so it never fires. On tag 2.94.0 the guard and the copy agree on `/nix/nix-installer` ([uninstall.rs L74](https://git.lix.systems/lix-project/lix-installer/src/tag/2.94.0/src/cli/subcommand/uninstall.rs#L74)), so there it does.
- The uninstaller also does `set_current_dir("/")` if its cwd is under `/nix` (L68).
- Consequence on macOS with `main`: running `/nix/nix-installer uninstall` executes from the volume it force-unmounts. The executable's pages are mapped from that volume. Whether the process survives is **Unverified**; the `umount -f` text above ("all other files return errors") makes a failure plausible but is not a statement about mapped executables.
- On Linux the question does not arise: deleting a running executable is allowed and no unmount happens (section 5).

**Decision for the remove script:** never run the uninstaller from `/nix`. Copy `/nix/nix-installer` (or `/nix/lix-installer` if that is what exists) to a root-owned directory outside `/nix`, check its SHA-256, and run the copy. This works on both versions: `check_compatible` compares the binary's version with the receipt's, so the copy must come from the install, not from a download ([plan.rs](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/plan.rs)). The install script should record the installer binary's SHA-256 in the provenance marker; today's marker design only records the receipt hash. Note `/nix/nix-installer` is owned by the unprivileged user on this Mac (observed with `ls -ln`; why is **Unverified**), so root would execute a file the user can replace unless its hash is checked.

### 3. Does `exec` leave a process holding the volume?

- **The exec'd process holds nothing on `/nix`.** Observed locally with a probe script run through `nu --no-config-file` (nu 0.115.1, from `/nix/store`): before `exec` the nu process has three `txt` entries on the volume (the `nu` binary, `libiconv.2.dylib`, `libcharset.1.dylib`) plus cwd and fds 0-3; after `exec /bin/sh -c ...` the same PID is `/bin/bash` and `lsof -p` shows zero entries on `/nix`. The script file is not kept open. Nushell's own doc confirms the Unix semantics: "the current process is replaced with the command" ([exec](https://www.nushell.sh/commands/docs/exec.html)).
- **`sudo`:** `/usr/bin/sudo` is on the system volume (observed: `-r-s--x--x root wheel`). It inherits the script's cwd and fds 0-2. So `cd /` before `exec`. Whether `sudo` stays resident as the parent of the command is **Unverified** (not needed: either way it is not on `/nix`). Use the absolute `/usr/bin/sudo`, because `exec sudo` resolves through the PATH of the Nix environment.
- **Only the script's own process is replaced.** The "Nushell parent is gone" premise is true only for the process running the script. Whatever started it stays: if the user launched the script from an interactive Nix `nu`, that shell keeps its `txt` mappings on the volume and is waiting for the child. Observed locally: this Mac's login shell is `-/nix/store/...-nushell-0.115.1/bin/nu` (pid 876); `ps -o ppid=,comm=` prints full executable paths on macOS, so ancestors can be tested by path.
- **Terminal emulator:** if Ghostty runs from the store (or its helper/framework files are mapped from it), it holds the volume the same way. A terminal that dies mid-uninstall also closes the pty, and the kernel sends SIGHUP to the foreground process group, which includes `sudo` and possibly the uninstaller. **Unverified:** what happens to a Nix-store app whose volume is force-unmounted, and whether SIGHUP on a closed terminal interrupts the uninstaller between `unmount force` and `deleteVolume`. Interrupting there leaves the half-uninstalled state of section 1.
- **launchd jobs from Lix itself:** the `systems.lix.nix-installer.nix-hook` job is created only when profile modification is on ([planner/macos/mod.rs L313](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/planner/macos/mod.rs#L313)); with `--no-modify-profile` it does not exist. Its revert only deletes the plist, with no `bootout` ([L156](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_nix_hook_service.rs#L156); same in tag 2.94.0 L165). Its execute step only writes the plist (no `bootstrap`, [L108-L140](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_nix_hook_service.rs#L108)), so by my reading launchd loads it at the next boot. Observed locally: the job is loaded and `state = running` (`launchctl print system/systems.lix.nix-installer.nix-hook`, pids 1046/1049, `runs = 2`) with stdout and stderr paths `/nix/.lix-installer-hook.{out,err}.log`, so after any reboot it lives on, and an uninstall leaves a loaded job pointing into a deleted volume until the next boot. **Unverified:** that launchd keeps those two log files open (needs `sudo lsof -p 1046`). The nix daemon job `org.nixos.nix-daemon` is stopped by the uninstaller (`launchctl bootout`, then up to 99 checks at 100 ms, [configure_init_service.rs L601](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/common/configure_init_service.rs#L601)).
- **Other launchd/systemd user agents from the kit** (for example Home Manager services) are not touched by Lix. `home-manager uninstall` is meant to remove them ([03 §3a](03-work-machine-config.md#3-ways-to-deliver-tools-and-config-through-nix)), but the script should confirm rather than assume.
- **System daemons:** the volume root on this Mac holds `.DocumentRevisions-V100`, `.TemporaryItems` and `.Trashes`, created by macOS services, so system daemons have touched it. Whether any holds an open file, and which, is **Unverified** (needs `sudo lsof /nix` as root; an unprivileged `lsof /nix` lists only the caller's processes, here the Zen browser's extension files from the store).

**What the script should check or require.** The uninstaller does nothing about busy volumes except `unmount force`, so the script must refuse before any destructive step when the volume cannot be released safely.

1. Process ancestry (macOS and Linux): walk `ppid` from the script's own PID to PID 1; refuse if any ancestor's executable path is under `/nix`. On macOS read it with `ps -o ppid=,comm= -p <pid>`; on Linux with `readlink /proc/<pid>/exe`. Message: "run this from Terminal.app (or any terminal and shell outside Nix) and start a new shell".
2. Login shell (both): refuse if the user's login shell is under `/nix`: after the removal the account could not log in. `dscl . -read /Users/<user> UserShell` on macOS, `getent passwd <user>` on Linux.
3. macOS busy check: `sudo lsof -nP -F pcn /nix` (one filesystem-wide listing; a `+D` directory walk over a 33,000-entry store would be far too slow), minus the script's own PID and the `lsof`/`sudo` children. Abort when anything else remains. The allow-list for system daemons is to be set from the test's observations, because it is unknown which of them show up on an idle volume.
4. Linux and WSL2: no unmount happens, so open files do not block. Warn only (section 5).
5. Run the uninstaller with `cd /` and outside `/nix` (section 2).
6. Authenticate before the first destructive step: `sudo -v` at the top, so the `exec sudo` at the end cannot fail on a password after the kit is gone.

### 4. Does the empty `/nix` stub disappear without a reboot?

**Answer: no, per Apple's own man page. Lix's code and description say otherwise, and no source shows it working.**

- Apple, `man synthetic.conf` (observed locally, macOS 26.5.2): "Synthetic entities may not be deleted at runtime. In order to delete a synthetic entity, it must be removed from `synthetic.conf`, and the host must be rebooted." The Nix manual agrees: the empty `/nix` directory "will disappear the next time you reboot" and a reboot is not needed to finish the uninstall ([uninstall.md](https://github.com/NixOS/nix/blob/2.35.2/doc/manual/source/installation/uninstall.md)).
- Lix removes the `nix` line from `/etc/synthetic.conf` and runs `apfs.util -t` and `apfs.util -B`, ignoring errors from both, and describes this as "Will remove the `/nix` path" ([create_synthetic_objects.rs L71](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_synthetic_objects.rs#L71)). The only upstream comment on those flags is for the install direction: the Nix script uses them to create synthetic objects "saving us a reboot" ([create-darwin-volume.sh L259-L270](https://github.com/NixOS/nix/blob/2.35.2/scripts/create-darwin-volume.sh#L259)). Nothing read says they delete one.
- The conf-file edit: the revert removes the last occurrence of the exact text `nix\n` and deletes the file if it ends up empty ([create_or_insert_into_file.rs L343](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/base/create_or_insert_into_file.rs#L343)).
- **Unverified:** `ls -ld /nix` immediately after the uninstall, then after a reboot. The documented outcome is an empty root-owned directory until the reboot.
- **Consequence for the install script's pre-flight (03 §2):** it must not treat an empty `/nix` as "Nix preinstalled". Test `/nix/store` (and `/nix/receipt.json`) instead. **Unverified:** that a reinstall onto the leftover stub works before the reboot; install should be run in the test to find out (checklist). The remove script should tell the user that an empty `/nix` stays until the next reboot and is harmless.

### 5. Linux (systemd) and WSL2 (systemd)

Both go through the same code: `Linux` planner with a systemd init action ([planner/linux.rs](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/planner/linux.rs)). The plan is `CreateDirectory /nix`, `ProvisionNix`, `CreateUsersAndGroups`, `ConfigureNix`, SELinux policy (if detected), `CreateDirectory /etc/tmpfiles.d`, `ConfigureInitService`, scratch-dir removal; reverted in reverse.

- **No volume, no unmount.** The `/nix` directory is created with `force_prune_on_revert = true` ([linux.rs L79](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/planner/linux.rs#L79)), and the revert deletes it with `remove_dir_all` unless it is a mount point, in which case only its children go ([create_directory.rs L236](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/base/create_directory.rs#L236)). Unlinking files that processes still use is allowed on Linux, so running binaries keep working from deleted inodes. This also covers the uninstaller running from `/nix/nix-installer`. The self-copy guard being broken on `main` therefore costs nothing on Linux. Still copy the binary out: it costs one `cp`, and one code path for all platforms is simpler to test.
- **Service teardown** ([configure_init_service.rs L601](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/common/configure_init_service.rs#L601)): for the socket `nix-daemon` and the service `nix-daemon.service`, `systemctl stop` if active and `systemctl disable` if enabled; `systemd-tmpfiles --remove --prefix=/nix/var/nix`; delete `/etc/tmpfiles.d/nix-daemon.conf`; `systemctl daemon-reload`; delete `nix-daemon.service`, `nix-daemon@.service` and `nix-daemon.socket` from `/etc/systemd/system`. **Unverified:** that a running `nix-daemon@*.service` instance (socket-activated) is stopped by this; the code stops only the two named units. A leftover instance would run from deleted files until it exits.
- **Pre-uninstall checks** run before any change: refuse on WSL1 (`WSL_DISTRO_NAME` set and `WSL_INTEROP` unset), and, when the receipt's init is systemd with the daemon started, refuse if `/run/systemd/system` is missing ([linux.rs L173-L182, L232, L270](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/planner/linux.rs#L173)). On WSL2 this means systemd must be running at removal time; if the user turned it off after the install, the uninstaller exits with a failure and an explanation, having changed nothing. The script should test `/run/systemd/system` first, so it fails before the kit is half removed.
- **WSL1 misdetection (open point in 03 §1): not reachable on this path.** The installer escalates through `sudo`, and its environment whitelist (section 1) does not include `WSL_DISTRO_NAME` or `WSL_INTEROP`, so both are unset when the check runs and the WSL1 test passes. The same applies to the script's `exec sudo` as long as it does not use `sudo -E`. **Unverified** on a real WSL2 distro: `sudo env | grep WSL` should print nothing, and an uninstall with `interop` disabled must not report WSL1.
- **User removal** needs `userdel` or `deluser` and the group tool ([delete_user.rs L29](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/base/delete_user.rs#L29)). Unverified on minimal images.
- **Terminal and shell:** the ancestry rule in section 3 is advisory on Linux. A terminal emulator or shell from `/nix/store` keeps running from deleted files, but a lazily loaded library (graphics drivers for a Nix Ghostty) may fail afterwards, and a dying terminal sends SIGHUP to the uninstaller mid-deletion. If `/nix/receipt.json` is already gone when that happens, no rerun is possible. **Unverified**; warn, and prefer a terminal outside Nix.
- **No stub**: `/nix` is an ordinary directory and disappears at once.

### 6. Leftovers the revert misses

| Item | Does the revert handle it? | Script action |
|---|---|---|
| Root's `~root/.nix-profile`, `.nix-defexpr`, `.nix-channels`, `.cache/nix`, `.local/state/nix`, `.local/share/nix`, `.config/nix` (`/var/root` on macOS, `/root` on Linux) | No. A grep of `src/` finds no code that deletes them. The installer runs `nix-store --load-db` and `nix-env`/`nix profile` as root with `HOME` set to root's home ([setup_default_profile.rs L76](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/base/setup_default_profile.rs#L76), [nixenv/mod.rs L321](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/profile/nixenv/mod.rs#L321)), so some may be created at install; **Unverified** which. The Nix manual's removal lists include root's `.nix-profile`, `.nix-defexpr`, `.nix-channels` and, on Linux, `.cache/nix` ([uninstall.md](https://github.com/NixOS/nix/blob/2.35.2/doc/manual/source/installation/uninstall.md)) | Delete the set after a successful uninstall, as root, using `~root` and never `$HOME`. Safe because the marker proves no Nix existed before the kit, so every such path came from the kit's Nix. Never run `nix` as root in the script |
| `/etc/zshenv` block (macOS) | Yes, in principle. It is added by `ConfigureRemoteBuilding` unconditionally, even with `--no-modify-profile` ([macos/mod.rs L307](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/planner/macos/mod.rs#L307)), at the top of the file, guarded to SSH sessions. Revert removes the last occurrence of the exact recorded text and deletes the file if nothing else remains ([configure_remote_building.rs L33](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/configure_remote_building.rs#L33), [create_or_insert_into_file.rs L343](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/base/create_or_insert_into_file.rs#L343)). If `/etc/zshenv` was a symlink at install time the step was skipped altogether. A block that was edited or reformatted stays silently | After the uninstall, `grep -n 'nix-daemon.sh' /etc/zshenv` and print a warning with the line numbers. Do not edit the file automatically (it may be managed). **Unverified:** whether a stock macOS has no `/etc/zshenv` (here it is a nix-darwin symlink) |
| Loaded `systems.lix.nix-installer.nix-hook` job (macOS, only without `--no-modify-profile`) | No: only the plist is deleted | `launchctl bootout system/systems.lix.nix-installer.nix-hook` before the uninstall, ignoring failure. A job that is already gone returns an error that is harmless |
| Empty `/nix` stub (macOS) | No (section 4) | Tell the user it stays until the next reboot; make the install pre-flight ignore an empty `/nix` |
| `/etc/fstab` | The `/nix` line and the Lix comment are removed and the file is rewritten ([create_fstab_entry.rs L164](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_fstab_entry.rs#L164)). By my reading an `/etc/fstab` the install created is left behind empty. **Unverified** | Observe `ls -l /etc/fstab` after the uninstall on a Mac that had none |
| System keychain item ("Nix Store", label "disk3 encryption password" here) | Yes, but only when the volume deletion succeeded; the `security delete-generic-password` call matches on label, kind and comment as well, and an error from it is collected ([encrypt_apfs_volume.rs L314](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/encrypt_apfs_volume.rs#L314)). Observed locally: the item exists in `/Library/Keychains/System.keychain` and the volume reports `FileVault: Yes` | A VM with FileVault off never exercises this path; test on an encrypted volume (checklist) |
| Time Machine exclusions | Yes (`tmutil removeexclusion`, before the volume is deleted) | none |
| Per-user dirs of the invoking user (`~/.nix-profile`, `~/.cache/nix`, `~/.local/state/nix`, `~/.local/share/nix`, `~/.config/nix`, `~/.nix-defexpr`, `~/.nix-channels`) | No | Already in the script's plan. Delete before the uninstall (nothing to wait for) |
| Other accounts' Nix dirs on the work machine | No | Out of scope; they dangle. Mention in the final message |
| Shell rc blocks in `/etc/zshrc`, `/etc/bashrc`, `/etc/profile.d/nix.sh`, ... | Yes, same exact-match rule, only if the install modified the profile ([configure_nix.rs L37](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/common/configure_nix.rs#L37)) | With `--no-modify-profile` there are none. A final `grep -l 'nix-daemon.sh' /etc/zshrc /etc/bashrc /etc/bash.bashrc /etc/profile.d/nix.sh /etc/zsh/zshrc` catches the cases where the block was reformatted |
| The temporary copy of the uninstaller | n/a | Remove it in the last stage (section 7) |
| Boot-time state: `/var/run/nix-daemon.socket` | Yes, removed in the daemon job's revert ([bootstrap_launchctl_service.rs L135](https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/bootstrap_launchctl_service.rs#L135)) | none |

### 7. Recommended final step of the remove script

Two changes to the plan in the ticket and in the README of this folder.

1. **The marker is deleted by the last stage, and only when the uninstaller exits 0.** The ticket's order deletes the kit directory with the marker last, and only then hands over. After `exec` nothing in Nushell runs again, so if `sudo` is refused, the volume is busy or the uninstaller fails, the marker is already gone and the next run of the script no longer knows it owns `/nix`. Keep the marker (delete everything else in the kit directory first), read it into memory at the top, and let the last stage delete it on success. A retry then runs the same sequence again. If `/nix/receipt.json` is missing but the marker exists and `/nix/store` is gone, treat Nix as already removed: do the leftover cleanup and delete the marker.
2. **The last step is `exec` into a small root `sh`, not straight into the uninstaller.** `exec` ends the Nushell process, so Nushell cannot clean up the temporary copy, root's leftovers or the marker afterwards, and running the uninstaller as a child of Nushell would keep a process from `/nix` alive across the forced unmount. A `/bin/sh` stage on the system volume does both jobs.

Nushell, last step (syntax-checked with `nu-check`; the commands were not run):

```nu
# Preflight, at the top of the script, before any destructive step
^/usr/bin/sudo -v
# read the marker into memory, compare its receipt hash with /nix/receipt.json
# refuse on: ancestor under /nix, login shell under /nix, macOS busy files (section 3)
# Linux/WSL2: refuse if /run/systemd/system is missing

# ...existing steps: HM backups, home-manager uninstall, GPU step,
#    per-user Nix dirs, kit directory except the marker...

# Last step
cd /
if $nu.os-info.name == "macos" {
    do --ignore-errors { ^/usr/bin/sudo /bin/launchctl bootout system/systems.lix.nix-installer.nix-hook }
}
let installer = ["/nix/nix-installer" "/nix/lix-installer"] | where {|p| $p | path exists } | first
let stage = (^/usr/bin/sudo /usr/bin/mktemp -d /var/tmp/kit-nix-uninstall.XXXXXX | str trim)
^/usr/bin/sudo /bin/cp $installer $"($stage)/uninstaller"
# compare the copy's sha256 with the hash the install script recorded; abort here if different
exec /usr/bin/sudo --set-home /bin/sh -c $stage2 kit-stage2 $"($stage)/uninstaller" $marker
```

`$stage2` is this POSIX `sh` text (syntax-checked with `sh -n`; `~root` expands to `/var/root` on macOS, checked locally):

```sh
uninstaller=$1
marker=$2
trap '' HUP
"$uninstaller" uninstall --no-confirm
rc=$?
if [ "$rc" -eq 0 ]; then
  rm -rf ~root/.nix-profile ~root/.nix-defexpr ~root/.nix-channels ~root/.cache/nix ~root/.local/state/nix ~root/.local/share/nix ~root/.config/nix
  rm -f "$marker"
  if [ -e /etc/zshenv ] && grep -n 'nix-daemon.sh' /etc/zshenv; then
    echo "Nix block left in /etc/zshenv: remove it by hand" >&2
  fi
fi
rm -rf "$(dirname "$uninstaller")"
exit "$rc"
```

Notes on the sequence:

- The uninstaller's path is probed for both names because the README names `/nix/lix-installer` and the code writes `/nix/nix-installer`.
- `--no-confirm` and `uninstall [RECEIPT]` are as in the source. Do not add `sudo -E`.
- `trap '' HUP` is optional hardening: an ignored signal stays ignored across `exec`, but `sudo` installs its own SIGHUP handling, so whether it helps is **Unverified**. Writing the uninstaller's output to a log file instead of the terminal would stop a closed pty from making a write fail; also **Unverified**, and both are left out of the checklist's pass criteria.
- If the uninstaller exits non-zero the stage prints nothing extra; the exit status reaches the user's shell. The script's earlier message (printed before `exec`) must carry the recovery text: on macOS a failed volume step leaves the "Nix Store" volume on disk; reboot, then `sudo diskutil apfs deleteVolume "Nix Store"`, delete the System keychain item "Nix Store", and run the script again.
- Linux and WSL2 take the same code path. The `launchctl` line is skipped there; the busy check is a warning; the `/run/systemd/system` check is a hard stop.
- Tell the user at the end (before `exec`) that on macOS an empty `/nix` directory remains until the next reboot.

### 8. Checklist for the throwaway-instance test

Run install then remove in a fresh VM or container, with a filesystem snapshot (names, modes, owners, hashes, mounts, launchd/systemd state) before the install, after the install and after the remove, and diff the first and the last.

macOS (a VM with FileVault off exercises only part of this; if a FileVault-on VM is not possible, mark the keychain rows "not tested"):

- [ ] `ls -ln /nix/nix-installer /nix/lix-installer` right after install: which name exists, and who owns it.
- [ ] `sudo lsof -nP -F pcn /nix` on an idle freshly installed VM: the list of system processes that hold the volume (feeds the allow-list for the busy check).
- [ ] `launchctl print system/systems.lix.nix-installer.nix-hook` after install and before a reboot (expected: not loaded), and after a reboot (loaded, running `wait4path`). `sudo lsof -p <pid>` of that job: does it hold the two `/nix/.lix-installer-hook.*.log` files?
- [ ] Run the final step from Terminal.app with `/bin/zsh`: exit status, whether the "Nix Store" volume is gone (`diskutil list`), `launchctl print system/org.nixos.nix-daemon` and the hook job both unloaded, no `kit-nix-uninstall.*` left in `/var/tmp`.
- [ ] Run it a second time from a Nix `nu` as parent (and, if installed, from a Nix-store terminal): does the busy check refuse, and if the check is bypassed, does the uninstaller finish or die between `unmount force` and `deleteVolume`? Record the parent shell's fate (crash or error on resume).
- [ ] Baseline, on one extra snapshot: run `/nix/nix-installer uninstall --no-confirm` in place with no copy. Outcome (finished, hung, killed) decides whether the copy is mandatory or only prudent.
- [ ] `ls -ld /nix` and `mount | grep nix` immediately after the uninstall, and again after a reboot (stub present, then gone). Then, on a second run, reinstall before rebooting: does the install succeed with the stub present and does the install pre-flight accept it?
- [ ] `cat /etc/synthetic.conf`, `cat /etc/fstab`, `ls -l /etc/fstab` (empty file left?), `grep -n nix-daemon.sh /etc/zshenv /etc/zshrc /etc/bashrc`, `ls -l /etc/zshenv` before and after; whether a stock `/etc/zshenv` exists before the install.
- [ ] FileVault-on case: `sudo security find-generic-password -s "Nix Store" /Library/Keychains/System.keychain` before and after.
- [ ] `sudo find /var/root -maxdepth 3 -name '*nix*'` after install and after remove: which root paths the installer created, and that the stage removes them.
- [ ] `sudo launchctl print system | grep -i nix` after the remove: nothing from the kit.
- [ ] Failure injection (separate run): hold a file open on the volume and make `diskutil unmount force` fail if possible, or kill the terminal mid-uninstall; check that the marker survives, the error text carries the recovery steps, and a second run completes.

Linux (systemd) and WSL2 (systemd):

- [ ] `ls /nix`, `systemctl list-unit-files 'nix-daemon*'`, `ls /etc/systemd/system | grep nix`, `ls /etc/tmpfiles.d`, `getent group nixbld`, `getent passwd | grep nixbld`, `ls -a /root | grep -i nix`, `ls -a ~ | grep -i nix` after the remove: all empty.
- [ ] Is a `nix-daemon@*.service` instance left running after the remove (`systemctl list-units 'nix-daemon@*'`, `ps`)?
- [ ] Run with a Nix-store `nu` as the parent shell: the uninstall finishes, and the parent shell's state afterwards.
- [ ] WSL2 only: `sudo env | grep WSL` (expect nothing); the removal with `interop` disabled in `wsl.conf` must not report WSL1; the removal with systemd turned off afterwards fails before changing anything, and the script's own `/run/systemd/system` check catches it first.
- [ ] Native Linux only: with a Nix-store terminal emulator, does it keep working after `/nix` is deleted, and does closing it during the uninstall interrupt the uninstaller?

Both:

- [ ] The marker survives a failed uninstall and is deleted after a successful one; a second run after success exits cleanly.
- [ ] The exit code of the whole script equals the uninstaller's.

### Sources

Lix installer, `main` at commit 40ef289 (paths are repo-relative)
- Repository and commit: https://git.lix.systems/lix-project/lix-installer/commit/40ef289e4c83cbe671f523224d874137203d7400
- `src/cli/subcommand/uninstall.rs`, `src/cli/subcommand/install/mod.rs`, `src/cli/mod.rs`, `src/plan.rs`: https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/cli/subcommand/uninstall.rs
- `src/planner/macos/mod.rs`, `src/planner/linux.rs`: https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/planner/macos/mod.rs
- `src/action/macos/` (`create_nix_volume.rs`, `create_apfs_volume.rs`, `unmount_apfs_volume.rs`, `create_synthetic_objects.rs`, `create_fstab_entry.rs`, `encrypt_apfs_volume.rs`, `create_nix_hook_service.rs`, `configure_remote_building.rs`, `bootstrap_launchctl_service.rs`): https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/macos/create_nix_volume.rs
- `src/action/common/` (`configure_init_service.rs`, `configure_nix.rs`, `create_nix_tree.rs`, `place_nix_configuration.rs`), `src/action/base/` (`create_directory.rs`, `create_or_insert_into_file.rs`, `delete_user.rs`, `setup_default_profile.rs`), `src/profile/nixenv/mod.rs`: https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/src/action/common/configure_init_service.rs
- `README.md` (uninstall section), `docs/quirks.md`, `lix-installer.sh`: https://git.lix.systems/lix-project/lix-installer/src/commit/40ef289e4c83cbe671f523224d874137203d7400/README.md
- Served bootstrap script, byte-identical to the commit's `lix-installer.sh` on 2026-10-13: https://install.lix.systems/lix

Lix installer, tag 2.94.0 (commit 81a5d13, `legacy` branch)
- Tag tree: https://git.lix.systems/lix-project/lix-installer/src/tag/2.94.0/
- `src/cli/subcommand/uninstall.rs`, `src/cli/subcommand/install.rs`, `src/action/macos/create_apfs_volume.rs`, `src/action/macos/unmount_apfs_volume.rs`, `src/action/macos/create_nix_hook_service.rs`: https://git.lix.systems/lix-project/lix-installer/src/tag/2.94.0/src/action/macos/create_apfs_volume.rs

Nix
- Uninstall manual at tag 2.35.2: https://github.com/NixOS/nix/blob/2.35.2/doc/manual/source/installation/uninstall.md
- `create-darwin-volume.sh` at tag 2.35.2 (comment on `apfs.util -t` / `-B`): https://github.com/NixOS/nix/blob/2.35.2/scripts/create-darwin-volume.sh

Apple and Nushell
- `man synthetic.conf`, `man diskutil` (verbs `unmount force`, `apfs deleteVolume`), `man 8 umount` (`-f`): observed locally on macOS 26.5.2 (`man <page> | col -b`)
- Nushell `exec`: https://www.nushell.sh/commands/docs/exec.html

Local observations (this Mac, read-only)
- `/nix/receipt.json` (`version` 3.95.0, action list), `ls -ln /nix`, `/etc/synthetic.conf`, `/etc/fstab`, `/etc/zshenv`, `/Library/LaunchDaemons/systems.lix.nix-installer.nix-hook.plist`, `launchctl print system/systems.lix.nix-installer.nix-hook`, `ps`, `lsof /nix`, `diskutil info "Nix Store"`, `security find-generic-password -s "Nix Store" /Library/Keychains/System.keychain`; probe scripts run with `nu --no-config-file` (nu 0.115.1) in the scratch directory
