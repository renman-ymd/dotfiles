## Structuring one repository for several machines

Scope and conventions: researched 2026-10-07. "master" links are the state of that day. Repo facts come from `flake.lock` (nixpkgs and nixpkgs-for-lix both at rev `b6c98e9`, 2026-09-22; nix-darwin `4cff07d`, 2026-08-16; home-manager `0b2f112`, 2026-09-23). Several claims were checked by running Lix 2.95.2 (the Mac's Nix) against that nixpkgs rev; the expressions are in "Local experiments" under Sources. Repository activity dates come from GitHub's Atom feeds (`/commits/<branch>.atom`, `/releases.atom`) because the unauthenticated GitHub API rate limit was exhausted mid-session. Paragraphs starting with **Implications for this repo:** are my analysis, not facts.

### 1. Branch per machine vs one flake with per-host outputs

**How each tool picks a configuration when `--flake <dir>` has no `#attr`:**

| Tool | Default attribute | Hostname source | Default flake dir |
|---|---|---|---|
| `nixos-rebuild` (Python rewrite, "-ng") | `nixosConfigurations."<host>"`, falling back to `"default"` if the hostname is empty | `platform.node()` locally. With `--target-host` it runs `uname -n` on the **target**. | dir of the `/etc/nixos/flake.nix` symlink |
| `darwin-rebuild` | `darwinConfigurations.<host>` | `scutil --get LocalHostName`, no fallback | dir of the `/etc/nix-darwin/flake.nix` symlink |
| `home-manager switch --flake` (standalone) | `homeConfigurations."<name>"` | see below | `~/.config/home-manager` (also the deprecated `~/.config/nixpkgs`) |

- nixos-rebuild: the man page says the name defaults to "the current host name" ([man page source](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd)). The code builds `nixosConfigurations."{attr or hostname or default}"` ([models.py L104-148](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/models.py)). Python's `platform.node()` returns the network name, possibly not fully qualified ([Python docs](https://docs.python.org/3/library/platform.html)).
- `nixos-rebuild-ng` is the only implementation now. It became the default in 25.11 ([rl-2511](https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/release-notes/rl-2511.section.md)), and the Bash version was removed in 26.05 ([rl-2605](https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/release-notes/rl-2605.section.md)). At the repo's locked nixpkgs rev, `pkgs.nixos-rebuild` is `nixos-rebuild-ng-26.11`.
- darwin-rebuild: the script does `flakeAttr=$(scutil --get LocalHostName)` and prefixes `darwinConfigurations.` ([darwin-rebuild.sh L156-172](https://github.com/nix-darwin/nix-darwin/blob/master/pkgs/nix-tools/darwin-rebuild.sh)). Activation must run as root. The nix-darwin README also tells you to name the flake entry after `scutil --get LocalHostName` ([README](https://github.com/nix-darwin/nix-darwin/blob/master/README.md)).
- Home Manager standalone: the name starts as `$USER`. Then for each of `$USER@$(hostname -f)`, `$USER@$(hostname)` and `$USER@$(hostname -s)`, in that order, it checks whether `homeConfigurations` has that attribute and, if so, uses it ([home-manager CLI L185-222](https://github.com/nix-community/home-manager/blob/master/home-manager/home-manager)). The loop has no `break`, so a later match overrides an earlier one, even though the code comment says the long name should win. I found this `user@host` then `user` lookup only in the CLI source, not in the manual pages or release notes I checked (Unknown: whether it is documented anywhere first-party). When Home Manager is a NixOS or nix-darwin module, the system tool does all selection.
- The three macOS names (from `man scutil` as shipped with Darwin 25.5.0 on this Mac; I found no first-party web copy): `HostName` is the name behind `hostname(1)` and `gethostname(3)`, `LocalHostName` is the Bonjour name, and `ComputerName` is the display name. Apple documents that the local hostname defaults to the computer name with spaces turned into hyphens and `.local` appended ([Apple Support](https://support.apple.com/guide/mac-help/change-computers-local-hostname-mac-mchlp2322/mac)). nix-darwin maps `networking.hostName` to `scutil --set HostName`, and `networking.localHostName` defaults to `hostName` and sets `LocalHostName`. `networking.computerName` is separate and left unset by default ([networking module](https://github.com/nix-darwin/nix-darwin/blob/master/modules/networking/default.nix)).
- Observed on this Mac today: `HostName` and `LocalHostName` are both `Renauds-MacBook-Air`; `ComputerName` is `Renaud’s MacBook Air`. The flake entry name therefore matches.
- First-party guidance on multi-host flakes is thin. The Nix manual's `nix flake check` page lists `nixosConfigurations.<name>.config.system.build.toplevel` as a recognised output and names no `darwinConfigurations` or `homeConfigurations` ([flake-check.md](https://github.com/NixOS/nix/blob/master/src/nix/flake-check.md)). Those two are conventions owned by nix-darwin and Home Manager. The nixos-hardware README example uses `nixosConfigurations.<your-hostname>` ([README](https://github.com/NixOS/nixos-hardware/blob/master/README.md)). Home Manager ships `nixos`, `nix-darwin` and `standalone` flake templates ([flake.nix](https://github.com/nix-community/home-manager/blob/master/flake.nix)).
- Unknown: I found no first-party document (Nix manual, nix.dev, NixOS manual, nix-darwin, Home Manager) that recommends or discusses per-machine branches. I did not consult the NixOS wiki in depth.

**Facts about jj that bear on the branch workflow:**
- Bookmarks automatically follow revisions rewritten by `jj rebase` ([bookmarks.md](https://github.com/jj-vcs/jj/blob/main/docs/bookmarks.md)).
- A rebase that hits conflicts still succeeds and records the conflict in the commit, so resolution can wait ([conflicts.md](https://github.com/jj-vcs/jj/blob/main/docs/conflicts.md)).
- `jj rebase -s` accepts several sources (each becomes a direct child of the destination), `-o/--onto` is the destination flag, and `-A/-B` insert a revision into the middle of a stack while rebasing the descendants ([CLI reference snapshot](https://github.com/jj-vcs/jj/blob/main/cli/tests/cli-reference%40.md.snap)). The `--onto` rename is recorded in the [CHANGELOG](https://github.com/jj-vcs/jj/blob/main/CHANGELOG.md); the repo runs 0.45.1, which is in that file.

**Analysis: what branch-per-machine costs with jj** (labelled analysis, nothing here is sourced beyond the jj facts above):
- One shared change means landing it on the trunk and then moving every machine branch. In jj that is a single command, for example `jj rebase -s 'roots(trunk()..(mac | fw16 | stream))' -o trunk()`, because bookmarks follow. The per-change cost is then N pushes and N verifications, not N rebases. In Git it would be N rebases.
- The recurring conflict source is `flake.lock`. Each machine branch tends to carry its own lock (each machine wants to build and test its own bump), so every trunk lock bump conflicts N times. The repo rule "each `flake: update inputs` stands alone" makes this worse, not better. jj postpones the conflict but does not remove it.
- Drift: nothing evaluates the other machines' branches. With one flake, one `nix flake check` (or an eval of `.#darwinConfigurations.*` and `.#nixosConfigurations.*`) covers every host before you push. With branches, a break on the Framework shows up only when you next rebuild the Framework.
- Branches buy no selection benefit: the three tools above already pick the host by name from one flake.
- The remaining reason for a branch is the "work in progress not ready for `main`" case already in CLAUDE.md, which is a different use of branches.

**Implications for this repo:** One flake with one `outputs` and one `flake.lock` serves every machine with no flags beyond `--flake <dir>`, provided the attribute names equal the hostnames: `darwinConfigurations."Renauds-MacBook-Air"` (already true) and a `nixosConfigurations.<framework-hostname>` whose `networking.hostName` matches. Because the repo lives at `~/.config/nix-darwin`, not `/etc/nix-darwin`, `darwin-rebuild switch --flake ~/.config/nix-darwin` still needs the path (or a symlink at `/etc/nix-darwin/flake.nix`). When deploying from the Mac with `--target-host`, remember the default attribute is the target's `uname -n`, not the Mac's name. For standalone Home Manager on work machines the username and hostname are unknown in advance, so the install script should pass an explicit `#attr` (for example `#work`) rather than rely on the `user@host` lookup. Per-machine differences belong in per-host module lists, not in branches (see 2).

### 2. Sharing modules across NixOS, nix-darwin and Home Manager

**Home Manager deployment modes**
- NixOS module: `home-manager.nixosModules.home-manager`. By default each user is activated by a system service `home-manager-<user>.service` at boot and on rebuild. `home-manager.startAsUserService = true` switches to a user service ([HM manual: NixOS module](https://github.com/nix-community/home-manager/blob/master/docs/manual/installation/nixos.md)).
- nix-darwin module: `home-manager.darwinModules.home-manager`. Activation runs inside nix-darwin's `postActivation` as the user (`launchctl asuser` plus `sudo -u`) using the generation's `activationPackage` ([nix-darwin/default.nix](https://github.com/nix-community/home-manager/blob/master/nix-darwin/default.nix), [manual](https://github.com/nix-community/home-manager/blob/master/docs/manual/installation/nix-darwin.md)).
- Standalone: `homeConfigurations.<name> = home-manager.lib.homeManagerConfiguration { pkgs; modules; extraSpecialArgs; }`, applied with `home-manager switch --flake` ([standalone.md](https://github.com/nix-community/home-manager/blob/master/docs/manual/nix-flakes/standalone.md)).
- Module-mode options (identical set on both platforms, from [nixos/common.nix](https://github.com/nix-community/home-manager/blob/master/nixos/common.nix)): `useGlobalPkgs` (use the system `pkgs`, which disables HM's own `nixpkgs.*` options), `useUserPackages`, `backupFileExtension`, `extraSpecialArgs`, and `sharedModules` (extra modules added to every user). The manual says to use `extraSpecialArgs` for values that come from outside the module graph, such as flake inputs ([nix-darwin flakes page](https://github.com/nix-community/home-manager/blob/master/docs/manual/nix-flakes/nix-darwin.md)).
- Module-only arguments: in module mode HM passes `osConfig` and `osClass` (plus `darwinConfig` on nix-darwin) to user modules ([nixos/common.nix L28-34](https://github.com/nix-community/home-manager/blob/master/nixos/common.nix)). Standalone, `eval-config.nix` and `modules/default.nix` pass only `modulesPath` plus whatever `extraSpecialArgs` you give ([modules/default.nix](https://github.com/nix-community/home-manager/blob/master/modules/default.nix)). So a shared module that takes `osConfig` or `osClass` does not evaluate standalone unless you supply them.
- Username and home directory: in module mode HM takes `home.username` and `home.homeDirectory` from the system's `users.users.<name>`. Standalone they are mandatory (no default for `stateVersion` >= 20.09) ([home-environment.nix](https://github.com/nix-community/home-manager/blob/master/modules/home-environment.nix)).
- The manual's NixOS and nix-darwin flake examples have the same shape. Only the module attribute differs, so one `./home.nix` can be assigned to `home-manager.users.<name>` in both a `nixosConfigurations` and a `darwinConfigurations` entry ([nixos.md](https://github.com/nix-community/home-manager/blob/master/docs/manual/nix-flakes/nixos.md)).

**Platform-specific options inside Home Manager vs the system modules**
- Home Manager does not filter its module list by platform. `modules/modules.nix` imports `./launchd/default.nix`, `./systemd.nix`, `./targets/darwin` and `./targets/generic-linux.nix` on every platform ([modules.nix](https://github.com/nix-community/home-manager/blob/master/modules/modules.nix)).
- `launchd.enable` defaults to `isDarwin` and carries an assertion that fails only if agents are defined off Darwin ([launchd/default.nix](https://github.com/nix-community/home-manager/blob/master/modules/launchd/default.nix)). `systemd.user.enable` defaults to `isLinux`, and `lib.hm.assertions.assertPlatform` produces a platform error when a Linux-only module is enabled elsewhere ([systemd.nix](https://github.com/nix-community/home-manager/blob/master/modules/systemd.nix), [assertions.nix](https://github.com/nix-community/home-manager/blob/master/modules/lib/assertions.nix)). Inside HM, a wrong-platform definition under `mkIf false` therefore cannot fail with "option does not exist".
- nix-darwin and NixOS do not do this: `launchd.user.agents`, `homebrew.*` and `system.defaults.*` exist only in nix-darwin; `systemd.services.*` and friends only in NixOS.

**Module-system behaviour (source plus local experiments)**
- `mkIf` is pushed down to the individual attribute definitions so conditions can read `config` without recursion ([lib/modules.nix, `pushDownProperties` doc, L1340-1360](https://github.com/NixOS/nixpkgs/blob/master/lib/modules.nix); [NixOS manual: delaying conditionals](https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/development/option-def.section.md)).
- The set of unmatched definitions (definitions with no declared option) is computed from attribute names, and `checkUnmatched` throws "The option `...' does not exist" for the first one ([lib/modules.nix L306-380, L971-1000](https://github.com/NixOS/nixpkgs/blob/master/lib/modules.nix)). No condition is evaluated on that path.
- Experiment results (Lix 2.95.2, nixpkgs `b6c98e9`):

| Expression (no `launchd` option declared) | Result |
|---|---|
| `config = lib.mkIf false { launchd.agents.foo = 1; }` | error: option does not exist |
| `config = lib.mkIf true { launchd.agents.foo = 1; }` | error: option does not exist |
| `config = lib.optionalAttrs false { launchd.agents.foo = 1; }` | evaluates |
| option declared, `lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {...}` with `pkgs` from `_module.args` | evaluates |
| `imports = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [...]` with `pkgs` from `_module.args` | infinite recursion |
| `config = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {...}` with `pkgs` from `_module.args` | infinite recursion |
| same two, with `pkgs` passed via `specialArgs` | evaluate |

- So the usual workarounds are: choose the module list per host in `flake.nix` (outside the module system); use `imports`/`optionalAttrs` only with values from `specialArgs`; or declare a stub option on the other platform so the definition has a home (the last is my inference from the code above, not tested).
- `_module.args` docs say `imports` must be computed statically before anything else, so callers provide `specialArgs` for values needed during import resolution ([lib/modules.nix L165-200](https://github.com/NixOS/nixpkgs/blob/master/lib/modules.nix)). The module system's own error context for `config` in `imports` advises importing unconditionally and using `mkEnableOption` plus `mkIf` (L268, same file).
- Platform predicates: `stdenv.isDarwin`, `stdenv.isLinux` and friends are deprecated aliases (marked "Added 2026-05-09") that warn "use stdenv.hostPlatform.<name>" ([stdenv/generic/default.nix L205-229](https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/default.nix)). Use `pkgs.stdenv.hostPlatform.isDarwin`.
- Packages whose `meta.platforms` excludes the host: `legacyPackages.x86_64-linux.aerospace.name` evaluates, but `.drvPath` throws (checked). A darwin-only package in `home.packages` therefore fails when the closure is built on Linux; guard it with `lib.optionals`. See the [nixpkgs `meta.platforms` docs](https://github.com/NixOS/nixpkgs/blob/master/doc/stdenv/meta.chapter.md).

**Implications for this repo:** The simplest division needs no conditionals: `flake.nix` composes module lists per host (`common` + `darwin.nix` for the Mac, `common` + a `nixos/` set for the Framework), so `launchd.user.agents.emacs`, `homebrew`, `system.activationScripts` and the nix-daemon re-signing in `modules/darwin.nix` never reach NixOS. Home Manager is the part to share. `modules/home.nix` is one file today, and the darwin-only bits are: `aerospace` in `home.packages`, `xdg.configFile."aerospace/aerospace.toml"`, `home.sessionPath` with `/opt/homebrew`, and the `home.activation.resignAdhocApps` and `emacsDaemonBinary` scripts that call `/usr/bin/codesign`. Because HM declares `home.activation`, `home.packages` and `xdg.configFile` on every platform, wrapping those in `lib.mkIf pkgs.stdenv.hostPlatform.isDarwin` (or `lib.optionals` for lists) is enough. A split such as `modules/home/{common,darwin,linux}.nix` imported per host through `home-manager.users.<name>.imports` or `sharedModules` avoids even that. Use `pkgs.stdenv.hostPlatform`, not `osClass`/`osConfig`, in anything meant to also run standalone on a work machine. The existing `specialArgs = { lixpkg = ...; }` is the right mechanism for values needed in `imports`.

### 3. Flake structuring helpers

Dates are last commit on the default branch and latest GitHub release, from Atom feeds ([flake-parts](https://github.com/hercules-ci/flake-parts/commits/main.atom), others in Sources). Today is 2026-10-07.

| Project | What it does | Last commit | Latest release | Status |
|---|---|---|---|---|
| [flake-parts](https://github.com/hercules-ci/flake-parts) | Module system for flake outputs: `perSystem`, `systems`, and a `flake` option for non-per-system outputs | 2026-10-01 | none published | active |
| [nix-darwin flake module](https://github.com/nix-darwin/nix-darwin/blob/master/flake-module.nix) and [HM flake module](https://github.com/nix-community/home-manager/blob/master/flake-module.nix) | declare `flake.darwinConfigurations`, and `flake.homeConfigurations`/`homeModules`, for flake-parts | follows each project | follows each project | active |
| [ez-configs](https://github.com/ehllie/ez-configs) | flake-parts module that builds nixos, darwin and HM configs from a directory layout | 2025-06-17 | none | inactive about 16 months, not archived |
| [nixos-unified](https://github.com/srid/nixos-unified) (renamed from nixos-flake) | flake-parts module: unifies NixOS, nix-darwin and HM; optional autowiring; an `.#activate` app including remote activation | 2026-09-10 | v0.2.0, 2024-10-03 (history file lists many "Unreleased" items) | active, untagged |
| [snowfall-lib](https://github.com/snowfallorg/lib) | opinionated directory-to-outputs framework | 2026-07-17 (README edit) | 2024-06-11 | README says it has been effectively unmaintained and asks for maintainers: **flag as unmaintained** |
| [flake-utils-plus](https://github.com/gytis-ivaskevicius/flake-utils-plus) | `mkFlake` helper generating NixOS host configurations (`hosts.<name>`), channels, exporters | 2026-05-23 | v1.6.0, 2026-05-23 (previous v1.5.1, 2024-07-02) | low activity; README documents NixOS hosts only (no darwin mention) |
| [digga](https://github.com/divnix/digga) | flake utility library (DevOS lineage) | 2024-05-17 | 2022-04-02 | README deprecation notice: **unmaintained, not recommended** ([issue #503](https://github.com/divnix/digga/issues/503) names std, flake-parts, flake-utils-plus and deploy-rs as alternatives) |
| [numtide/blueprint](https://github.com/numtide/blueprint) | folder-structure-to-outputs convention with hosts/users | 2026-09-02 | none | active; project README carries an "experimental" badge (secondary reading of the badge) |
| [dendritic pattern](https://github.com/mightyiam/dendritic) | a usage pattern, not a library: every non-entry-point file is a module of a top-level (usually flake-parts) config; each file implements one feature across nixos, home-manager and darwin classes | 2026-09-04 | none | documentation repo, active |
| [import-tree](https://github.com/denful/import-tree) (moved from vic/) | recursively imports a directory of modules; enables the pattern | 2026-09-03 | 2026-05-14 | active |
| [den](https://github.com/denful/den), [flake-file](https://github.com/denful/flake-file) | aspect-oriented library built on the pattern; generates `flake.nix` from modules | 2026-10-05 / 2026-10-06 | 2026-09-24 / 2026-04-14 | active; den's README says it no longer relates to the "Dendritic" name |

- flake-parts: the minimal-mirror goal and feature list are in its [README](https://github.com/hercules-ci/flake-parts/blob/main/README.md). It declares `flake.nixosConfigurations` ([source](https://github.com/hercules-ci/flake-parts/blob/main/modules/nixosConfigurations.nix)) and `flake.nixosModules`, but not `darwinConfigurations` or `homeConfigurations`. The `flake` option is freeform, so any other output can be set directly, with no merging between definitions ([modules/flake.nix](https://github.com/hercules-ci/flake-parts/blob/main/modules/flake.nix)). Docs: [flake.parts](https://flake.parts/getting-started).
- ez-configs: its README describes six directories (nixos, darwin and home, each with modules and configurations) and says HM configs also pull in `darwin` or `linux` modules depending on the system ([README](https://github.com/ehllie/ez-configs/blob/main/README.md)).
- nixos-unified autowiring maps `configurations/{nixos,darwin,home}/foo.nix` to `nixosConfigurations.foo`, `darwinConfigurations.foo` and `legacyPackages.${system}.homeConfigurations.foo`. Its `activate` app is described as a replacement for `nixos-rebuild switch`, `darwin-rebuild switch` and `home-manager switch` and can activate remotely over SSH ([autowiring](https://github.com/srid/nixos-unified/blob/master/doc/guide/autowiring.md), [activate](https://github.com/srid/nixos-unified/blob/master/doc/guide/activate.md), [release history](https://github.com/srid/nixos-unified/blob/master/doc/history.md)).
- The dendritic README lists the same factors this repo will hit: multiple configurations, module sharing, several configuration classes, HM nested in NixOS/nix-darwin, and cross-cutting concerns ([README](https://github.com/mightyiam/dendritic/blob/master/README.md)).

**Implications for this repo:** Three hosts (Mac, Framework, streaming box) do not need a framework; a small `mkHost`-style function in plain `outputs` is enough, and it avoids committing to anything unmaintained. If structure becomes necessary, flake-parts is the only maintained, minimal foundation, and both nix-darwin and Home Manager already ship flake-parts modules for their outputs. The repo already pulls flake-parts transitively (the `flake.nix` comment about bun2nix says so), so it is not a new dependency in the lock. Skip snowfall-lib and digga outright. ez-configs is small and stale; flake-utils-plus is NixOS-only. nixos-unified is alive but untagged since 2024 and its main extra is the `activate` app. The dendritic pattern fits one concern that already exists here: the Emacs daemon is split across `modules/darwin.nix` (launchd agent) and `modules/home.nix` (re-signing activation script), which is one feature spanning two module classes. That alone does not justify the refactor. It becomes attractive once the Framework (NixOS plus HM) adds more such features.

### 4. Building and deploying to other machines

**nixos-rebuild remote flags** (man page on master = 26.11; the same options exist in [release-25.11](https://github.com/NixOS/nixpkgs/blob/release-25.11/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd) and [release-26.05](https://github.com/NixOS/nixpkgs/blob/release-26.05/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd) unless noted; [master man page](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd)):
- `--target-host [user@]host` activates on the remote machine over ssh. `switch`, `boot` and `test` need root there. `--build-host [user@]host` builds remotely (and copies the result back if there is no target host). SSH options go through `NIX_SSHOPTS`.
- `--sudo`, `--ask-sudo-password`/`-S` exist in 25.11 and 26.05. The generalised `--elevate {none,sudo,run0}` appears only on master (26.11), where `--sudo` and `--use-remote-sudo` are listed as an alias and a deprecated spelling. In 26.05 the `--use-remote-sudo` line is absent from the man page.
- `--use-substitutes` adds that flag to the `nix copy` calls; it matters when the target reaches the cache faster than the build host does.
- The man page warns that `nixos-rebuild` honours `nixpkgs.crossSystem` but ignores the target's real architecture, so a mismatch makes activation fail.
- With `--flake` plus `--build-host`, nixos-rebuild-ng evaluates locally (`nix eval --raw <attr>.drvPath`), copies the `.drv` to the build host, and builds there with `nix build <drv>^*` ([nix.py `build_remote_flake`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/nix.py)). Evaluating an x86_64-linux configuration on the aarch64-darwin Mac therefore works without a Linux builder, as long as evaluation itself does not need to build anything (import from derivation).
- `nixos-rebuild-ng` lists `aarch64-darwin` in `meta.platforms` at the locked rev (checked), so it can be run from the Mac.

**Building x86_64-linux from aarch64-darwin**
- nix-darwin's `nix.linux-builder` options: `enable`, `package` (default `pkgs.darwin.linux-builder`), `config` (extra NixOS config for the builder VM), `systems` (default: only the builder VM's own platform), `maxJobs`, `supportedFeatures`, `ephemeral`, `protocol` (default `ssh-ng`) ([module source](https://github.com/nix-darwin/nix-darwin/blob/master/modules/nix/linux-builder.nix)). It requires `nix.enable`.
- The nixpkgs manual describes `darwin.linux-builder` as a QEMU-based NixOS VM and `darwin.linux-builder-vz` as the same guest on Apple's Virtualization.framework. The vz variant exposes Rosetta, so `x86_64-linux` builds are translated rather than emulated and are "substantially faster". It needs an Apple-silicon host on macOS 13 or newer with Rosetta installed. The manual's nix-darwin example is `nix.linux-builder = { enable = true; package = pkgs.darwin.linux-builder-vz; systems = [ "aarch64-linux" "x86_64-linux" ]; }` ([darwin-builder section](https://github.com/NixOS/nixpkgs/blob/master/doc/packages/darwin-builder.section.md)). `darwin.linux-builder-vz` evaluates at the repo's locked nixpkgs rev (checked).
- Unverified: whether the default QEMU `linux-builder` can build `x86_64-linux` through binfmt/QEMU emulation inside the guest. The manual sections I read do not document that; only the Rosetta route is documented.
- The alternative named in the task, building on the Framework with `--build-host`, is supported as above. The Framework's closure can then be copied to the streaming box directly between hosts.

**deploy-rs and colmena**
- [deploy-rs](https://github.com/serokell/deploy-rs): Rust, flake-based, multi-profile deploys with a "magic rollback" that reverts if the machine cannot be reached again after activation. It has `activate.nixos`, `activate.darwin` and `activate.home-manager` helpers ([README](https://github.com/serokell/deploy-rs/blob/master/README.md)). Last commit 2026-09-28 ([feed](https://github.com/serokell/deploy-rs/commits/master.atom)).
- [colmena](https://github.com/nix-community/colmena) (moved from zhaofengli/): stateless NixOS-only deployment with parallel apply and node tags ([README](https://github.com/nix-community/colmena/blob/main/README.md)). v0.5.0 released 2026-09-22, last commit 2026-09-29 ([releases](https://github.com/nix-community/colmena/releases.atom), [commits](https://github.com/nix-community/colmena/commits/main.atom)).
- Both are maintained as of today. Neither is needed for two or three hosts.

**Implications for this repo:** For the Framework and the streaming box, plain `nixos-rebuild switch --flake .#<host> --target-host <user>@<host> --sudo` (or building on the Framework with `--build-host`) covers deployment with no extra tool. The Mac cannot build x86_64-linux closures by itself without a builder, and the vz builder is the documented fast path; given ~8 GB RAM on the streaming box, building on the Framework and copying is the lower-friction option, so the Mac's linux-builder is optional. If the box ends up headless or hard to reach, deploy-rs's magic rollback is the one feature `nixos-rebuild` does not have, since a plain rollback needs the machine reachable or physical access to the boot menu. This is analysis, not a verified need. `--elevate` is not in 26.05, so scripts should use `--sudo`.

### 5. Framework 16 and Lix on NixOS

**nixos-hardware**
- Module attribute: `nixos-hardware.nixosModules.framework-16-amd-ai-300-series` (path `framework/16-inch/amd-ai-300-series`). A variant with the NVIDIA dGPU is `framework-16-amd-ai-300-series-nvidia` ([flake.nix L174-186](https://github.com/NixOS/nixos-hardware/blob/master/flake.nix)). The module covers the Ryzen AI 300 series generally; Framework sells the 16" mainboard with the Ryzen AI 9 HX 370 under that series ([Framework product page](https://frame.work/products/laptop16-mainboard-amd-ai300?v=FRAKKE0009)). No file mentions the HX 370 by name.
- What it sets ([module](https://github.com/NixOS/nixos-hardware/blob/master/framework/16-inch/amd-ai-300-series/default.nix), [common](https://github.com/NixOS/nixos-hardware/blob/master/framework/16-inch/common/default.nix), [common/amd.nix](https://github.com/NixOS/nixos-hardware/blob/master/framework/16-inch/common/amd.nix)):
  - `boot.kernelPackages = linuxPackages_latest` (as a default) when the nixpkgs kernel is older than 6.15.
  - `services.fwupd.enable`, kernel params `amdgpu.sg_display=0` and `amdgpu.abmlevel=0`, and `hardware.amdgpu.dcDebugMask.disableReplay`.
  - From `common`: laptop and SSD profiles, the Framework kernel module and framework-tool, `services.fprintd` (default on), udev rules for the Ethernet expansion card and for keyboard-module `hidraw` access, `hardware.sensor.iio`, and QMK keyboard support.
  - From `common/amd.nix`: the AMD CPU, pstate and GPU profiles, `dcDebugMask.disablePsr`, and `services.power-profiles-daemon` (default on).
- The README calls flake support "experimental" and shows the pattern `nixosConfigurations.<hostname> = nixosSystem { modules = [ nixos-hardware.nixosModules.<model> ]; }` ([README](https://github.com/NixOS/nixos-hardware/blob/master/README.md)). Repo activity: last commit 2026-10-07 ([feed](https://github.com/NixOS/nixos-hardware/commits/master.atom)).

**Lix**
- The Lix page for NixOS and nix-darwin ("Switching To Lix", dated 2024-04-27 but updated since: it shows 2.95.3) recommends Lix from nixpkgs. The simplest form is `nix.package = pkgs.lixPackageSets.stable.lix;`. The "advanced" form adds `nixpkgs.overlays` rewiring `nixpkgs-review`, `nix-eval-jobs`, `nix-fast-build` and `colmena` to `lixPackageSets.stable`, because tools that hardcode Nix would otherwise use CppNix. It says nixpkgs builds are cached by cache.nixos.org, and that the Lix NixOS module is only recommended for the bleeding-edge `main` branch ([Lix docs](https://lix.systems/add-to-config/)).
- The nix-darwin README says to set `nix.package = pkgs.lix` for Lix ([README](https://github.com/nix-darwin/nix-darwin/blob/master/README.md)). In nixpkgs, `lix = lixPackageSets.stable.lix` ([all-packages.nix L10320-10327](https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/all-packages.nix)) and `stable` currently aliases `lix_2_95` ([lix/default.nix L181-199](https://github.com/NixOS/nixpkgs/blob/master/pkgs/tools/package-management/lix/default.nix)). At the repo's locked rev, `pkgs.lix` and `lixPackageSets.stable.lix` are both 2.95.2 (checked).
- The repo passes `lixpkg = nixpkgs-for-lix.legacyPackages."aarch64-darwin".lix` via `specialArgs` and sets `nix.package = lixpkg`. `nixpkgs-for-lix` is a second input pointing at the same `nixpkgs-unstable` ref, locked to the same rev as `nixpkgs`.
- Substituter check at the locked rev: the aarch64-darwin `lix-2.95.2` store path has a narinfo on cache.nixos.org (HTTP 200) and none on cache.lix.systems (404); the x86_64-linux one is on cache.nixos.org too. The repo's `darwin.nix` still lists `cache.lix.systems` as an extra substituter.

**Implications for this repo:** The `nixpkgs-for-lix` approach yields the same package as the documented `nix.package = pkgs.lix` (same ref, same rev today), so it works and matches the docs' "from nixpkgs" recommendation, just routed through a second input and `specialArgs`. The only functional difference I can see is that Lix can be bumped independently with `nix flake update nixpkgs-for-lix`; the reason the repo chose this is Unknown (no commit title I saw mentions Lix). It does not use the "advanced" overlay, which only matters if colmena, nix-eval-jobs or nixpkgs-review get installed. On NixOS, with a single nixpkgs input, the same `nix.package = pkgs.lix` works unchanged, so a shared `modules/nix.nix` for both hosts is possible and `lixpkg` could be dropped. The Lix substituter looked unnecessary at the locked rev; re-check before removing it, since the repo comment says it was added for a build-failure case that may recur.

## Ansible, chezmoi and Home Manager

### 6. Ansible vs chezmoi vs Home Manager (plus Stow and yadm)

| | Home Manager | chezmoi | Ansible |
|---|---|---|---|
| Manages | packages (`home.packages`), generated config via `programs.*`/`services.*`, files as links into the Nix store (`mkOutOfStoreSymlink` for editable files), user services, activation scripts | files, directories, symlinks, templates, externals; scripts (`run_once_`, `run_onchange_`); packages only via scripts | anything modules exist for: packages, services, files, templates, users, system settings; needs Python on both ends |
| Per-machine differences | module system: options, `mkIf`, `mkDefault`, one `homeConfigurations`/`home-manager.users` entry per machine, `extraSpecialArgs` | Go `text/template` with `.chezmoi.os/arch/hostname/username/osRelease`, per-machine `[data]` in `chezmoi.toml`, `.chezmoidata`, `.chezmoiignore` | inventory, `group_vars`/`host_vars`, facts, Jinja2 templates |
| Secrets | none built in; sops-nix and agenix ship modules | age, gpg, git-crypt, transcrypt; Bitwarden `bw`, `rbw`, Bitwarden Secrets via `bws`; many other password managers | Ansible Vault (AES256 files or strings); lookups for `bw` and `bws` |
| Undo | `home-manager uninstall` | `chezmoi purge`, `chezmoi destroy`, `chezmoi init --one-shot` | no built-in undo found |
| Rollback | generations: `home-manager switch --rollback` | none documented (git source repo only) | none; manual `block`/`rescue` pattern |

**Home Manager**
- Files: `home.file` and `xdg.configFile` link store paths into `$HOME`; `config.lib.file.mkOutOfStoreSymlink` makes an editable link ([files.nix](https://github.com/nix-community/home-manager/blob/master/modules/files.nix)). On a collision with an existing unmanaged file, activation backs it up when a backup extension or command is set, otherwise fails (same file, L352-360). The repo sets `backupFileExtension`.
- Rollback: `home-manager switch --rollback` and `home-manager generations` ([Rollbacks](https://github.com/nix-community/home-manager/blob/master/docs/manual/usage/rollbacks.md)). In module mode the system tools roll back: `darwin-rebuild` has `--rollback`, `--list-generations` and `--switch-generation` ([darwin-rebuild.sh L20-21, L103-112](https://github.com/nix-darwin/nix-darwin/blob/master/pkgs/nix-tools/darwin-rebuild.sh)); `nixos-rebuild` has `--rollback`. HM is activated from the system generation's `postActivation`, so it follows.
- Removal: `home-manager uninstall` asks for confirmation, then switches to an empty configuration (`uninstall = true`). That forces `home.packages` and `home.file` empty and the activation step removes the `home-manager-path` profile entry, HM's data and state directories, and **all Home Manager generations**. It leaves your `home.nix` alone ([home-manager CLI `doUninstall`](https://github.com/nix-community/home-manager/blob/master/home-manager/home-manager), [misc/uninstall.nix](https://github.com/nix-community/home-manager/blob/master/modules/misc/uninstall.nix)). In the source I read, no step restores `*.backup-*` files created earlier; the removal script would have to do that.
- Secrets: none built in. sops-nix has a Home Manager module, but its README says that module needs systemd/user (a service rather than an activation script) and that `home.homeDirectory` must be set manually for standalone use ([sops-nix README](https://github.com/Mic92/sops-nix/blob/master/README.md)). agenix also provides NixOS and Home Manager modules ([README](https://github.com/ryantm/agenix/blob/main/README.md)). Unverified: whether sops-nix's Home Manager module works on macOS.

**chezmoi** (docs at [chezmoi.io](https://www.chezmoi.io), source of docs in [twpayne/chezmoi](https://github.com/twpayne/chezmoi/tree/master/assets/chezmoi.io/docs))
- Per-machine: the docs' own example is a personal versus work email in `.gitconfig`, using per-machine `[data]` plus a template ([machine-to-machine differences](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/user-guide/manage-machine-to-machine-differences.md)). Built-in variables include `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.hostname`, `.chezmoi.username` and `.chezmoi.osRelease` ([variables](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/reference/templates/variables.md)).
- Packages: the docs say package installation is imperative and can be simulated with a `.chezmoidata` file plus a `run_onchange_` script ([install packages declaratively](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/user-guide/advanced/install-packages-declaratively.md)). Scripts should be idempotent ([scripts](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/user-guide/use-scripts-to-perform-actions.md)).
- Encryption: age, git-crypt, gpg and transcrypt; encrypted files carry the `encrypted_` attribute and `chezmoi add --encrypt` adds them ([encryption](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/user-guide/encryption/index.md)). age supports multiple identities and recipients ([age](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/user-guide/encryption/age.md)).
- Bitwarden: template functions `bitwarden`, `bitwardenFields`, `bitwardenAttachment` (via `bw`), `rbw` and `rbwFields` (run `rbw get --raw`), and `bitwardenSecrets` (via `bws`). `bitwarden.unlock = "auto"` makes chezmoi call `bw unlock` ([Bitwarden guide](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/user-guide/password-managers/bitwarden.md), [rbw function](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/reference/templates/bitwarden-functions/rbw.md)).
- Vaultwarden compatibility: the Vaultwarden README lists the Password Manager API (vault, attachments, organizations, and so on) and does not list Secrets Manager ([README](https://github.com/dani-garcia/vaultwarden/blob/main/README.md)). A maintainer answered in a March 2025 discussion that Secrets Manager is not supported because it is a Bitwarden-licensed feature, and repeated that in a 2026 reply on an older thread ([#5702](https://github.com/dani-garcia/vaultwarden/discussions/5702), [#3368](https://github.com/dani-garcia/vaultwarden/discussions/3368)). So `bitwardenSecrets`/`bws` is out against a Vaultwarden server. The Bitwarden CLI documents `bw config server <url>` for self-hosted servers ([Bitwarden CLI](https://bitwarden.com/help/cli/)), and `rbw` has a `base_url` setting ([rbw README](https://github.com/doy/rbw/blob/main/README.md)). I did not test either against Vaultwarden.
- Removal: `chezmoi purge` removes chezmoi's configuration, state and source directory and leaves the target files untouched; `-P/--binary` also removes the binary ([purge](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/reference/commands/purge.md)). `chezmoi destroy <target>` permanently deletes the target from the source, the state and the home directory; the docs warn about it ([destroy](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/reference/commands/destroy.md)). `chezmoi init --one-shot` is documented as `--apply --depth=1 --force --purge --purge-binary`, "install your dotfiles, then remove all traces of chezmoi" ([init](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/reference/commands/init.md)). Neither `purge` nor `--one-shot` removes the dotfiles chezmoi wrote or reverses side effects of `run_` scripts.
- Rollback: I found no undo or rollback feature in the FAQ and daily-operations pages (search was not exhaustive); the source directory is a git repo.

**Ansible**
- Requirements: the control node is nearly any UNIX-like machine with Python (macOS, Linux, WSL; not native Windows); managed nodes need Python (and SSH) except for modules that say otherwise ([installation guide](https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/installation_guide/intro_installation.rst)).
- Per-machine: inventory plus `group_vars`/`host_vars` directories next to the inventory or playbook ([inventory guide](https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/inventory_guide/intro_inventory.rst)).
- Secrets: Ansible Vault encrypts variables and files and protects data at rest only; it supports whole-file encryption and `ansible-vault encrypt_string` per value ([vault guide](https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/vault_guide/vault.rst), [encrypting content](https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/vault_guide/vault_encrypting_content.rst)). The `community.general.bitwarden` lookup needs `bw` logged in, unlocked and `BW_SESSION` set ([plugin](https://github.com/ansible-collections/community.general/blob/main/plugins/lookup/bitwarden.py)); `bitwarden_secrets_manager` needs `bws` ([plugin](https://github.com/ansible-collections/community.general/blob/main/plugins/lookup/bitwarden_secrets_manager.py)).
- Undo and rollback: the documentation shows rollback only as a hand-written `block`/`rescue` pattern ("Attempt and graceful roll back demo" in [blocks](https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/playbook_guide/playbooks_blocks.rst)). I found no documented built-in undo or generation mechanism; the search was not exhaustive.

**GNU Stow and yadm, one line each**
- GNU Stow is a symlink farm manager; `-D/--delete` unstows a package ([manual](https://www.gnu.org/software/stow/manual/stow.html)).
- yadm wraps Git: system-specific alternate files and templates, encryption via GnuPG, OpenSSL, transcrypt or git-crypt, a bootstrap hook, and operation hooks ([README](https://github.com/yadm-dev/yadm/blob/master/README.md)). chezmoi's own comparison table marks yadm without password-manager integration, but that is chezmoi's view of a competitor ([table](https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/comparison-table.md)).

**What overlaps when combined with nix-darwin or NixOS**
- Home Manager vs the system layer: both configure programs and packages (`environment.systemPackages` vs `home.packages`, `programs.zsh.enable` exists in both), and both can run launchd agents. nix-darwin has `launchd.user.agents` and HM has `launchd.agents` (the repo uses the nix-darwin one for the Emacs daemon). HM runs inside nix-darwin/NixOS activation in module mode, so there is one rebuild and one rollback.
- Ansible vs nix-darwin/NixOS: it duplicates everything system-level (packages, services, settings; nix-darwin's `homebrew` module and Ansible's package modules would fight over the same state). Running both is a boundary decision, not a layering.
- chezmoi vs Home Manager: they overlap only where both target the same path. HM refuses or backs up an existing unmanaged file, so overlap shows up as backup files or failed activation. chezmoi's real files are writable, while HM's store links are read-only unless `mkOutOfStoreSymlink` is used.
- Side finding for the removal script: the nix-darwin README says the official Nix installer has no automated uninstaller and recommends the Lix installer, which supports flake and channel setups ([README](https://github.com/nix-darwin/nix-darwin/blob/master/README.md)). nix-darwin also ships `darwin-uninstaller`, which only applies to machines that have nix-darwin.

**Implications for this repo:** For machines 1 and 2 (personal Mac and Framework) Home Manager already covers what chezmoi would do and also installs the packages, versions them, and rolls them back, so adding chezmoi or Ansible there creates overlap without new capability. For machine 4 (work machines, one Bash script, no trace), the useful comparison is install weight and removal. Home Manager standalone needs Nix present, a username/home passed explicitly, and its own removal script: `home-manager uninstall` removes managed files, packages and generations but not backups, `~/.local/state`-style leftovers outside HM's paths, or the Nix installation itself. chezmoi is a single binary whose `--one-shot` removes itself but leaves the applied files, so it still needs a list of managed paths to delete. Ansible's Python and SSH requirements are the heaviest for a one-script install, and it has no undo. None of the three solves secrets alone for a public repo without a decryption key on the machine: chezmoi's age or Bitwarden functions and Ansible Vault all need a key or an unlocked vault, which the "no personal keys on work machines" rule forbids. The Vaultwarden constraint matters only for chezmoi's `bws` route (out) versus `bw`/`rbw` (plausible but untested), and a work-machine config would need none of it if secrets stay personal-only.

### Sources

Repo and local checks
- Local experiments, run 2026-10-07 with Lix 2.95.2 (`nix eval --impure`) against `github:NixOS/nixpkgs` at rev `b6c98e9e6633ee64753b594ff4a5febf0367fc00` (the repo's locked rev):
  - `lib.evalModules` with and without a declared `launchd` option, combining `mkIf false/true`, `optionalAttrs`, `imports`, `pkgs` from `_module.args` versus `specialArgs` (table in section 2).
  - `legacyPackages.x86_64-linux.aerospace.{name,drvPath}`.
  - `darwin.linux-builder-vz`, `nixos-rebuild-ng.meta.platforms`, `lix.version`, `lixPackageSets.stable.lix.version`.
  - Binary-cache check: `curl` of `https://cache.nixos.org/<hash>.narinfo` and `https://cache.lix.systems/<hash>.narinfo` for `lix-2.95.2`.
  - `scutil --get HostName|LocalHostName|ComputerName` and `man scutil` on this Mac.
- `/Users/renman-ymd/.config/nix-darwin/flake.nix`, `flake.lock`, `modules/darwin.nix`, `modules/home.nix` (read only).

Nix, nixpkgs, NixOS
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd
- https://github.com/NixOS/nixpkgs/blob/release-25.11/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd
- https://github.com/NixOS/nixpkgs/blob/release-26.05/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/models.py
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/nix.py
- https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/release-notes/rl-2511.section.md
- https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/release-notes/rl-2605.section.md
- https://github.com/NixOS/nixpkgs/blob/master/lib/modules.nix
- https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/development/option-def.section.md
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/default.nix
- https://github.com/NixOS/nixpkgs/blob/master/doc/stdenv/meta.chapter.md
- https://github.com/NixOS/nixpkgs/blob/master/doc/packages/darwin-builder.section.md
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/all-packages.nix
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/tools/package-management/lix/default.nix
- https://github.com/NixOS/nix/blob/master/src/nix/flake-check.md
- https://docs.python.org/3/library/platform.html

nix-darwin
- https://github.com/nix-darwin/nix-darwin/blob/master/README.md
- https://github.com/nix-darwin/nix-darwin/blob/master/pkgs/nix-tools/darwin-rebuild.sh
- https://github.com/nix-darwin/nix-darwin/blob/master/modules/networking/default.nix
- https://github.com/nix-darwin/nix-darwin/blob/master/modules/nix/linux-builder.nix
- https://github.com/nix-darwin/nix-darwin/blob/master/flake-module.nix
- https://support.apple.com/guide/mac-help/change-computers-local-hostname-mac-mchlp2322/mac
- `man scutil` on Darwin 25.5.0 (local; no first-party web copy found)

Home Manager
- https://github.com/nix-community/home-manager/blob/master/home-manager/home-manager
- https://github.com/nix-community/home-manager/blob/master/nixos/common.nix
- https://github.com/nix-community/home-manager/blob/master/nix-darwin/default.nix
- https://github.com/nix-community/home-manager/blob/master/modules/default.nix
- https://github.com/nix-community/home-manager/blob/master/modules/modules.nix
- https://github.com/nix-community/home-manager/blob/master/modules/home-environment.nix
- https://github.com/nix-community/home-manager/blob/master/modules/launchd/default.nix
- https://github.com/nix-community/home-manager/blob/master/modules/systemd.nix
- https://github.com/nix-community/home-manager/blob/master/modules/lib/assertions.nix
- https://github.com/nix-community/home-manager/blob/master/modules/files.nix
- https://github.com/nix-community/home-manager/blob/master/modules/misc/uninstall.nix
- https://github.com/nix-community/home-manager/blob/master/flake.nix
- https://github.com/nix-community/home-manager/blob/master/flake-module.nix
- https://github.com/nix-community/home-manager/blob/master/docs/manual/installation/nixos.md
- https://github.com/nix-community/home-manager/blob/master/docs/manual/installation/nix-darwin.md
- https://github.com/nix-community/home-manager/blob/master/docs/manual/nix-flakes/nixos.md
- https://github.com/nix-community/home-manager/blob/master/docs/manual/nix-flakes/nix-darwin.md
- https://github.com/nix-community/home-manager/blob/master/docs/manual/nix-flakes/standalone.md
- https://github.com/nix-community/home-manager/blob/master/docs/manual/usage/rollbacks.md

jj
- https://github.com/jj-vcs/jj/blob/main/docs/bookmarks.md
- https://github.com/jj-vcs/jj/blob/main/docs/conflicts.md
- https://github.com/jj-vcs/jj/blob/main/cli/tests/cli-reference%40.md.snap
- https://github.com/jj-vcs/jj/blob/main/CHANGELOG.md

Flake helpers (feeds give the dates quoted)
- https://flake.parts/getting-started
- https://github.com/hercules-ci/flake-parts (README, modules/flake.nix, modules/nixosConfigurations.nix, commits/main.atom)
- https://github.com/ehllie/ez-configs (README, commits/main.atom)
- https://github.com/srid/nixos-unified (README, doc/guide/autowiring.md, doc/guide/activate.md, doc/history.md, commits/master.atom, tags.atom)
- https://github.com/snowfallorg/lib (README, commits/main.atom, releases.atom)
- https://github.com/gytis-ivaskevicius/flake-utils-plus (README, commits/master.atom, releases.atom)
- https://github.com/divnix/digga (README, commits/main.atom, releases.atom) and https://github.com/divnix/digga/issues/503
- https://github.com/numtide/blueprint (README, commits/main.atom)
- https://github.com/mightyiam/dendritic (README, commits/master.atom)
- https://github.com/denful/import-tree (README, commits/main.atom, releases.atom)
- https://github.com/denful/den and https://github.com/denful/flake-file (README, feeds)

Deploy and hardware
- https://github.com/serokell/deploy-rs (README, commits/master.atom)
- https://github.com/nix-community/colmena (README, commits/main.atom, releases.atom)
- https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
- https://github.com/NixOS/nixos-hardware/blob/master/README.md
- https://github.com/NixOS/nixos-hardware/blob/master/framework/16-inch/amd-ai-300-series/default.nix
- https://github.com/NixOS/nixos-hardware/blob/master/framework/16-inch/common/default.nix
- https://github.com/NixOS/nixos-hardware/blob/master/framework/16-inch/common/amd.nix
- https://frame.work/products/laptop16-mainboard-amd-ai300?v=FRAKKE0009
- https://lix.systems/add-to-config/

Ansible, chezmoi and others
- https://github.com/twpayne/chezmoi/tree/master/assets/chezmoi.io/docs (pages linked inline: purge, destroy, init, variables, encryption, age, Bitwarden, rbw, machine differences, install packages, scripts, comparison table)
- https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/installation_guide/intro_installation.rst
- https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/inventory_guide/intro_inventory.rst
- https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/vault_guide/vault.rst
- https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/vault_guide/vault_encrypting_content.rst
- https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/playbook_guide/playbooks_blocks.rst
- https://github.com/ansible-collections/community.general/blob/main/plugins/lookup/bitwarden.py
- https://github.com/ansible-collections/community.general/blob/main/plugins/lookup/bitwarden_secrets_manager.py
- https://github.com/dani-garcia/vaultwarden/blob/main/README.md
- https://github.com/dani-garcia/vaultwarden/discussions/5702
- https://github.com/dani-garcia/vaultwarden/discussions/3368
- https://bitwarden.com/help/cli/
- https://github.com/doy/rbw/blob/main/README.md
- https://github.com/Mic92/sops-nix/blob/master/README.md
- https://github.com/ryantm/agenix/blob/main/README.md
- https://www.gnu.org/software/stow/manual/stow.html
- https://github.com/yadm-dev/yadm/blob/master/README.md
