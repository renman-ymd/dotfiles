# Several machines from one Nix repository

Researched 2026-10-07 against primary sources: official docs, READMEs, source code and release notes. Updated 2026-10-08 with your decisions and a comparison with [Ciznia/dotfiles](https://github.com/Ciznia/dotfiles/tree/great-reset) (`great-reset` branch). Every claim in the sections below links to its source, and "Unverified" or "Unknown" marks what couldn't be established. This page gives the short answers and points to the details.

The machines in scope:

- **Air**: MacBook Air, aarch64-darwin, nix-darwin + Home Manager. Full personal config.
- **Framework**: Framework 16 (Ryzen AI 9 HX 370), x86_64-linux, NixOS + Hyprland. Full personal config, planned.
- **Streaming box**: x86_64, about 8 GB RAM, an Intel integrated GPU plus an old NVIDIA card, antiX today. Wired network only, because its Wi-Fi antenna is broken. Only plays Crunchyroll on a projector. Exact specs unknown for about three weeks.
- **Work machines**: not yours; WSL, non-NixOS Linux or macOS. One config installed through Nix by a script, removed without trace, no personal keys.

## Decided so far

- **Keys:** one key per machine, never copied, because each signature should show which machine signed and with which email. This covers both the SSH key for authentication and the signing key.
- **Signing:** commits stay signed with PGP, not with jj's SSH signing. Each machine has a signing subkey under one personal primary key, because it is one person signing from different places ([ADR 0001](../../adr/0001-one-signing-subkey-per-machine.md)).
- **Work machines:** one config for every work machine, installed through Nix by a script and removed by another, with no personal keys.

| Section | Covers |
|---|---|
| [01-structure-and-tools.md](01-structure-and-tools.md) | Branches vs one flake, sharing modules across platforms, flake frameworks, remote deploys, Framework hardware and Lix, Ansible vs chezmoi vs Home Manager |
| [02-secrets.md](02-secrets.md) | sops-nix vs agenix, bootstrapping keys, Vaultwarden's role and trust model, SSH and signing keys, Wi-Fi, API tokens |
| [03-work-machine-config.md](03-work-machine-config.md) | Installing and removing Nix, detecting an existing Nix, ways to ship tools and config, every trace left behind, script constraints |
| [04-streaming-box.md](04-streaming-box.md) | Crunchyroll and Widevine on Linux, NixOS as an appliance, Gentoo for the same job, other options |
| [05-helium.md](05-helium.md) | Helium as the streaming box's browser: packaging, Widevine, kiosk and Wayland, footprint |
| [06-usb-display.md](06-usb-display.md) | The streaming box's USB-to-HDMI adapter: chipset families, NixOS drivers, Cage and wlroots, the GPU to render on, audio, the lid, an X11 fallback |
| [07-apps.md](07-apps.md) | Single-window web apps, Teams and WhatsApp clients, Claude on Linux, Spotifast, Deezer, Steam, GeForce NOW and Vesktop on Linux |

## Short answers

### One branch per machine, or one flake?

One flake, one branch, one output per machine named after its hostname.

- Each tool already picks its machine by name. `darwin-rebuild` reads `scutil --get LocalHostName`, `nixos-rebuild` reads the hostname (the target's with `--target-host`), and standalone Home Manager tries `$USER@host` and then `$USER`. One flake therefore serves every machine with no flags ([01 §1](01-structure-and-tools.md#1-branch-per-machine-vs-one-flake-with-per-host-outputs)).
- Branches per machine buy nothing and cost a lot. Every `flake.lock` bump conflicts once per branch, and nothing evaluates the other machines' branches before you push. No first-party doc recommends them.
- Machine differences belong in per-host module lists, chosen in `flake.nix`, outside the module system. `lib.mkIf false { launchd… }` still fails when the option doesn't exist on that platform, and conditions on `pkgs` inside `imports` recurse forever. Both were tested against the repo's locked nixpkgs ([01 §2](01-structure-and-tools.md#2-sharing-modules-across-nixos-nix-darwin-and-home-manager)).
- Three hosts don't need a framework: a small host-builder function is enough. If you ever want one, flake-parts is the maintained, minimal choice. snowfall-lib and digga are unmaintained by their own READMEs ([01 §3](01-structure-and-tools.md#3-flake-structuring-helpers)).
- **Module shape**, taken from Ciznia/dotfiles (see the comparison below):
  - Every feature is a module behind one enable flag. Modules sit in toolboxes and are inert until a flag is on.
  - Each machine has a recipe that only flips flags. A shared baseline uses `mkDefault`, so any recipe can switch a feature off.
  - Home modules use Home Manager options only, so they also run standalone.
  - For the Mac, that gives three toolboxes: `home` (imported everywhere), `darwin` (the Air) and `nixos` (the Linux hosts). Importing everywhere only works inside one platform, per the `mkIf` result above.

### How to manage secrets

Split them by how they can be handled.

1. **Keys never move; each machine generates its own** (decided). Each machine gets its own SSH key for authentication and its own PGP key for signing. Only the public halves are committed or uploaded to GitHub. jj keeps its `gpg` backend: `signing.key` takes anything `gpg -u` accepts, so each machine points it at its own key ([02 §4](02-secrets.md#4-ssh-and-signing-keys-across-machines)).
   - **Why PGP:** a PGP key carries its email in its user ID, so a signature names both the machine and the address. An SSH signature would name the machine, but not the email.
   - **Work identity:** its key lives only on the work machine. A jj `--when.repositories` scope can switch identity per repository.
   - **Revocation:** GnuPG writes a revocation certificate to `openpgp-revocs.d` when it generates a key ([GnuPG manual](https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html), for `--generate-key`). Copying it into Vaultwarden lets you revoke a lost machine's key.
   - **Decided 2026-10-12:** per-machine signing subkeys under one primary key ([ADR 0001](../../adr/0001-one-signing-subkey-per-machine.md)). Whether jj accepts a subkey selector such as a trailing `!` is unverified.
   - **Not a stated rule:** no GitHub or OpenSSH page states "one key per device" as a rule. Here it's your traceability requirement, not a best practice.
2. **Runtime secrets (Wi-Fi passwords, API tokens) are encrypted in the repo** with sops-nix or agenix and decrypted per host with that host's own age key. Both have NixOS, nix-darwin and Home Manager modules ([02 §1](02-secrets.md#1-sops-nix-vs-agenix-agenix-rekey-and-ragenix-in-a-line-each)). The difference that matters in a public repo: sops leaves key names and structure in clear text, while agenix files are opaque. sops-nix also has templates. That choice is still open.
3. **Vaultwarden holds the one key that edits the encrypted files**, fetched when you edit (`SOPS_AGE_KEY_CMD` with `rbw` or `bw`) and never copied to hosts. It is not a runtime dependency, so rebuilds don't need your friend's server ([02 §2](02-secrets.md#2-bootstrapping-a-new-machine-and-the-role-of-vaultwarden)).
   - Your friend can't read your vault, but can delete your account or lose the server. The web vault served from that server is the weakest client, so prefer native clients ([02 §3](02-secrets.md#3-trust-model-of-a-friend-run-vaultwarden)).
   - Keep a password-protected encrypted JSON export somewhere you control. It includes SSH keys.
   - Your friend's server runs Vaultwarden 1.37.4, read on 2026-10-08 from `GET /api/version`. That's the latest release (2026-10-05), with seven security advisories fixed, so it's patched promptly. SSH-key items work on it with no server flags, since 1.37.4 removed them ([02 §2](02-secrets.md#2-bootstrapping-a-new-machine-and-the-role-of-vaultwarden)).

Smaller facts that shape the details:

- **wakatime:** it can read its key with `api_key_vault_cmd = cat <decrypted path>`, so its config file stays plain ([02 §6](02-secrets.md#6-api-tokens-for-user-programs)).
- **Wi-Fi on NixOS:** `networking.networkmanager.ensureProfiles.environmentFiles` and `networking.wireless.secretsFile` both read a decrypted file ([02 §5](02-secrets.md#5-wi-fi-passwords)). Only the Framework needs this; the streaming box is wired.
- **Wi-Fi on the Air:** nix-darwin has no Wi-Fi module, so the Mac stays manual.
- **sops-nix on the Air:** decrypt at the nix-darwin level and disable its default GPG import of the host RSA key, because of an open activation issue ([02 §1](02-secrets.md#1-sops-nix-vs-agenix-agenix-rekey-and-ragenix-in-a-line-each)).

### Ansible, chezmoi, or something else?

Neither, for the personal machines: Home Manager already manages the dotfiles, installs and versions the packages, and rolls back ([01 §6](01-structure-and-tools.md#6-ansible-vs-chezmoi-vs-home-manager-plus-stow-and-yadm)).

- **Ansible** duplicates what nix-darwin and NixOS manage, needs Python on both ends, and has no undo.
- **chezmoi** overlaps with Home Manager. `chezmoi purge` and `init --one-shot` leave every file it applied in place. Its `rbw` and `bw` functions work with Vaultwarden; its `bitwardenSecrets` doesn't, because Vaultwarden has no Secrets Manager.
- **For the streaming box**, Ansible would only enter the picture with Gentoo (see below).

### The work-machine config

One script installs Nix and a fixed set of tools with their config. A second script removes exactly what the first created ([03](03-work-machine-config.md)).

- **Installer: Lix's.** It writes a receipt and ships a real `uninstall` that reverts its system changes on macOS: rc blocks, launchd daemons, build users, the APFS volume and its keychain item. It sends no telemetry ([03 §1](03-work-machine-config.md#1-installing-and-uninstalling-nix)).
- **Limits of that installer:**
  - It refuses Intel Macs.
  - It aborts on a managed Mac whose MDM profile restricts media mounting.
  - On WSL without systemd it only offers a root-only Nix.
  - It never removes the per-user Nix directories, so the removal script must delete those itself.
- **Detection can't prove who installed an existing Nix.** The install script records a provenance marker, and removal runs the uninstaller only when that marker is present ([03 §2](03-work-machine-config.md#2-detecting-a-preinstalled-nix)).
- **Two ways to deliver the tools and config, still to decide** ([03 §3](03-work-machine-config.md#3-ways-to-deliver-tools-and-config-through-nix)):
  - **Home Manager standalone**, as a `homeConfigurations.work` output. It reuses the most of the personal config. But it owns rc files like `~/.zshrc`, its uninstall is interactive, and it doesn't restore the files it backed up.
  - **Wrapped programs in a dedicated Nix profile**, with every tool's state redirected into one directory. This leaves the fewest traces, but each tool's redirect has to be maintained. For example, by source reading delta ignores `GIT_CONFIG_GLOBAL`. The research leans this way.
- **Script constraints:** write it in POSIX `sh`, because macOS's `/bin/bash` is 3.2. Pin the flake to a full commit hash: `github:` refs then download as tarballs with no git and no rate-limited GitHub API call ([03 §5](03-work-machine-config.md#5-bash-script-constraints)).

### The streaming box: NixOS or Gentoo?

NixOS (decided 2026-10-12). Gentoo wouldn't make the box meaningfully lighter than NixOS, and learning a second distribution's model and syntax would buy nothing here ([04](04-streaming-box.md)).

- **Crunchyroll** lists Chrome, Firefox, Edge and Safari at version 117 or newer, and names no operating systems. Linux is neither listed nor excluded. The resolution you'll get on a Linux browser is undocumented and has to be measured on the projector ([04 §1](04-streaming-box.md#1-crunchyroll-on-linux)).
- **NixOS setup:** `services.cage` runs one browser full screen and doubles as the autologin. Deploy from the Framework with `nixos-rebuild --target-host`, and set `system.autoUpgrade` to `operation = "boot"` so no update restarts it mid-episode ([04 §3](04-streaming-box.md#3-nixos-as-an-appliance)).
- **Wired only:** nixos-anywhere's "no Wi-Fi-only target" requirement is met, so it can install the box remotely. It still needs kexec support and at least 1 GB of RAM, both unchecked. No Wi-Fi secret is needed at first boot.
- **Video goes out through a USB-A to HDMI adapter** ([06](06-usb-display.md)). The adapter's chipset decides the driver:
  - **Old USB 2.0 DisplayLink:** the in-kernel `udl` driver.
  - **USB 3.0 DisplayLink:** the `evdi` module plus an unfree daemon. Its nixpkgs package needs the vendor's zip downloaded by hand, again whenever nixpkgs updates it.
  - **Silicon Motion, Fresco or MCT:** nothing packaged in nixpkgs.
  - **Under the Cage kiosk:** wlroots has supported such displays since 0.19, and the nixpkgs Cage builds on 0.20.2. Nobody has reported it working under Cage, so test it on the box, with an X11 kiosk kept as plan B.
  - **Rendering:** the Intel iGPU renders, with `nouveau` blacklisted. The NVIDIA legacy driver branches can't drive a Wayland compositor.
- **Graphics: an Intel iGPU plus an old NVIDIA card.**
  - **Intel driver:** the nixpkgs option text recommends `intel-media-driver` for Broadwell (2014) and newer and `intel-vaapi-driver` for older chips, and its own example lists both ([04 §3](04-streaming-box.md#3-nixos-as-an-appliance)). Until the generation is known, both can go in `hardware.graphics.extraPackages`.
  - **NVIDIA driver:** the legacy branches `legacy_340`, `legacy_390` and `legacy_470` exist in the repo's locked nixpkgs (checked 2026-10-12).
  - **Why that matters for the kiosk:** GBM support, which Wayland compositors such as Cage rely on, arrived in NVIDIA's 495 driver. Only secondary sources state this: [Phoronix](https://www.phoronix.com/news/NVIDIA-495.29.05-Linux) and [GamingOnLinux](https://www.gamingonlinux.com/2021/10/nvidia-beta-4952905-rolls-out-with-gbm-for-expanded-wayland-support/). So an old card on a legacy branch is unlikely to run the kiosk with NVIDIA's own driver; that is an inference.
  - **Plan without the specs:** driving the projector from the Intel output sidesteps NVIDIA entirely. A VM build of the host can test the kiosk now, but can't prove that Widevine plays.
- **Browser:** try Firefox first. It's free, in the binary cache, and downloads Widevine itself, but nothing confirms it plays DRM on NixOS, so test it. Fall back to `google-chrome`, which bundles Widevine but is unfree and not cached ([04 §2](04-streaming-box.md#2-widevine-on-x86_64-linux)).
- **Helium**, which you asked about, is the weakest fit for the box's one job ([05](05-helium.md)):
  - **No Widevine support:** its maintainers state they don't support Widevine and won't look into Widevine sideloading problems.
  - **A possible workaround, untested:** sideloading nixpkgs' `widevine-cdm` through Chromium's hint file might work, but nobody has shown Crunchyroll playing on Linux this way.
  - **Not in nixpkgs:** it comes only from community flakes, or a package you'd write yourself.
  - **Footprint unknown:** no measurement against Firefox exists.
- **Gentoo:** its binary host carries no browser that bundles Widevine, and its only advantage here would be compiling for the exact CPU ([04 §4](04-streaming-box.md#4-gentoo-for-this-role)).
- **The only route Crunchyroll documents end to end** is an official TV stick, which would retire the box ([04 §5](04-streaming-box.md#5-other-options)).

## Disagreement between sections

[01 §6](01-structure-and-tools.md#6-ansible-vs-chezmoi-vs-home-manager-plus-stow-and-yadm) reads the sops-nix README as saying its Home Manager module needs systemd. [02 §1](02-secrets.md#1-sops-nix-vs-agenix-agenix-rekey-and-ragenix-in-a-line-each) read the module source, which runs a launchd agent on macOS, with two open issues against that agent. The source reading is the more specific of the two. Both lead to the same advice: on the Air, decrypt at the nix-darwin level, not in Home Manager.

## Compared with Ciznia/dotfiles (`great-reset`)

Read on 2026-10-08 from [the branch](https://github.com/Ciznia/dotfiles/tree/great-reset). It covers three Linux machines: native NixOS, NixOS-WSL, and Ubuntu with standalone Home Manager.

**Adopted:**

- **Toolboxes and recipes.** `modules/home/` and `modules/nixos/` hold feature modules gated by `ciznia.<feature>.enable`, imported everywhere and inert until enabled. `home/<host>.nix` and `hosts/<host>/` are recipes that flip flags, and [home/base.nix](https://github.com/Ciznia/dotfiles/blob/great-reset/home/base.nix) sets the baseline with `mkDefault` ([docs/NIX.md](https://github.com/Ciznia/dotfiles/blob/great-reset/docs/NIX.md)). Changed here: one toolbox per platform, because they have no Mac.
- **Standalone-first home modules.** Home Manager options only, never system options, so the same modules work standalone. This is the rule the work-machine config needs.
- **Small inline builders.** `mkHost` and `mkHome` in [flake.nix](https://github.com/Ciznia/dotfiles/blob/great-reset/flake.nix), with no framework.
- **Runnable tests.** `nix run .#glados-vm` boots a host in QEMU through `virtualisation.vmVariant`. [scripts/test-nixos-wsl.ps1](https://github.com/Ciznia/dotfiles/blob/great-reset/scripts/test-nixos-wsl.ps1) bootstraps a throwaway NixOS-WSL and deletes it on failure. The streaming box gets the first, the work-machine scripts the second.

**Not adopted:**

- **Ansible Vault for keys.** The same SSH and GPG private keys go on every machine, sealed in a committed Ansible Vault and unlocked by a plaintext `.vault_pass` beside the repo ([ANSIBLE.md](https://github.com/Ciznia/dotfiles/blob/great-reset/docs/ANSIBLE.md)). A user timer then presets both passphrases into gpg-agent every 20 hours ([agent.nix](https://github.com/Ciznia/dotfiles/blob/great-reset/modules/home/agent.nix)).
  - **The passphrases protect nothing on a running machine:** anything running as you can read `.vault_pass` and decrypt every key.
  - **Your constraints:** it conflicts with one key per machine and with no personal keys on work machines.
  - **Macs:** its loader is a `systemd.user` timer, which macOS doesn't have.
- **Identity inside a feature module.** [git.nix](https://github.com/Ciznia/dotfiles/blob/great-reset/modules/home/git.nix) hardcodes the email and signing key. It also enables `programs.bash`, and Home Manager's bash module writes `~/.bashrc`, `~/.bash_profile` and `~/.profile` ([bash.nix](https://github.com/nix-community/home-manager/blob/master/modules/programs/bash.nix)), so turning on git takes over the shell's rc files. A work recipe must avoid that.

**Side finding:** Home Manager's gpg-agent module now has a launchd agent on macOS ([gpg-agent.nix](https://github.com/nix-community/home-manager/blob/master/modules/services/gpg-agent.nix)). The comment "HM services.gpg-agent is systemd only" in `modules/home.nix` is out of date.

## Open questions

- **Streaming box hardware, available in about three weeks:**
  - Intel iGPU generation (decides the video-decode driver)
  - NVIDIA card model (only matters if the projector has to use its output)
  - exact CPU and RAM
  - which HDMI audio output the projector uses
- **Everything else** is being settled in the grilling of the architecture report's candidates.
