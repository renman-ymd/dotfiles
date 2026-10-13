## Hunk on x86_64-linux

Research date: 2026-10-13. Versions seen while researching: Lix 2.95.2 on aarch64-darwin (local `nix --version`), hunk locked at `bc714de` (2026-09-22, package 0.22.0) and hunk `main` at `6aa5261` (2026-10-13, package 0.24.0-beta.0), bun2nix locked at `c843f47` (2026-02-12) and `master` at `0f2a1f0` (2026-07-21), nixpkgs-unstable locked at `b6c98e9` (2026-09-22), `nixos-unstable` at `7fd4004` (2026-10-11), `nixos-26.05` at `0d9e9b8` (2026-10-04), nix-systems/triplet locked at `6de7bc0` (2026-04-14), nix-systems/default at `d36eeed` (2026-10-05). Sources were read at the revisions named, plus `main` where noted. All Nix commands were run from `bash`/`zsh` in a scratch copy; nothing in the repo was edited, built or switched.

### 1. Answer in short

The current wiring is the problem, not the fix. Hunk's flake already has a `systems` input (default `github:nix-systems/triplet`, which lists `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`) and already makes bun2nix's `systems` follow it. Both the Air and the Framework are inside that list and `x86_64-darwin` is not. The repo's extra `inputs.bun2nix.inputs.systems.follows = "nix-systems-darwin"` overrides hunk's own follow and cuts bun2nix down to `aarch64-darwin`, which is what breaks `x86_64-linux`.

The wiring that works is no override at all:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; # or nixos-unstable, both tested

  hunk = {
    url = "github:modem-dev/hunk";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

and remove the `nix-systems-darwin` input and its `nix-systems-darwin` argument in `outputs`. Evaluated results for both systems, both nixpkgs inputs, both hunk revisions are in section 3. The x86_64-linux build itself is not verified locally (section 6).

### 2. What the upstream sources say

**Hunk's `flake.nix`** (identical at `bc714de` and at `main` `6aa5261`):

- `systems.url = "github:nix-systems/triplet"` with a comment that consumers "can widen or narrow this with `inputs.hunk.inputs.systems.follows`" ([flake.nix @ bc714de](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/flake.nix)).
- `bun2nix.inputs.systems.follows = "systems"`, so bun2nix is evaluated for exactly hunk's system list ([same file](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/flake.nix)).
- `packages` is `lib.genAttrs (import systems)` over that list, and each system takes `bun2nix.packages.${system}.default` ([same file](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/flake.nix)). So every system hunk lists must also exist in bun2nix's list, and a system missing from `systems` has no `hunk.packages.<system>`.
- The change that introduced the knob is [#621, 2884b56 (2026-07-28)](https://github.com/modem-dev/hunk/commit/2884b5697). Its changeset says hunk "no longer declares" `x86_64-darwin` and "now pins bun2nix's `systems` input to the same list so building the `aarch64-darwin` package never forces an Intel macOS Nixpkgs" ([changeset](https://github.com/modem-dev/hunk/blob/2884b5697/.changeset/nix-flake-drop-x86-darwin.md)). It is the last commit that touched `flake.nix` (checked with `gh api "repos/modem-dev/hunk/commits?path=flake.nix"`), so the locked revision and `main` both contain it.
- `homeManagerModules.default` imports `nix/home-manager.nix` and sets `programs.hunk.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default`. The Framework therefore needs `x86_64-linux` in hunk's `systems` for the module to evaluate, not only for the package ([flake.nix](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/flake.nix)).

**Hunk's Home Manager module** ([nix/home-manager.nix](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/nix/home-manager.nix)) needs, beyond `pkgs`: `pkgs.formats.toml`, `xdg.configFile`, `home.file` and `home.packages`; `programs.git.settings.core.pager` (only set when `enableGitIntegration`); `programs.jujutsu.settings` (only when `enableJujutsuIntegration`); `${cfg.package}/skills/hunk-review` (only when `enableClaudeIntegration`). Hunk's `nix/package.nix` has a bun archive hash for each of `aarch64-darwin`, `x86_64-darwin`, `aarch64-linux` and `x86_64-linux`, and `meta.platforms` lists all four ([package.nix](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/nix/package.nix)). `programs.git.settings` exists in Home Manager `release-25.11` and `release-26.05` (found with `gh api` on `modules/programs/git.nix`; the grep found no match on `release-25.05`, so an older Home Manager on the Framework would not take the git option).

**bun2nix**: the root flake has `systems.url` (`github:nix-systems/default` at `c843f47`, `github:nix-systems/triplet` at `master` `0f2a1f0`), and `nix/dev/systems.nix` sets flake-parts `systems = import inputs.systems`. `nix/dev/formatter.nix` imports `treefmt-nix.flakeModule` into `perSystem`, so treefmt is instantiated for every system in the list ([flake.nix @ c843f47](https://github.com/nix-community/bun2nix/blob/c843f477b15f51151f8c6bcc886954699440a6e1/flake.nix), [flake.nix @ 0f2a1f0](https://github.com/nix-community/bun2nix/blob/0f2a1f0b6f42cebe3b149bf62d38754c5e0e9729/flake.nix), [nix/dev/systems.nix](https://github.com/nix-community/bun2nix/blob/c843f477b15f51151f8c6bcc886954699440a6e1/nix/dev/systems.nix), [nix/dev/formatter.nix](https://github.com/nix-community/bun2nix/blob/c843f477b15f51151f8c6bcc886954699440a6e1/nix/dev/formatter.nix)).

**nix-systems**: `triplet` is "the new triplet for NixOS 26.06 and above" and lists `aarch64-darwin`, `aarch64-linux`, `x86_64-linux` ([README](https://github.com/nix-systems/triplet/blob/6de7bc09397911ce03636afbcf6118745ab2cda0/README.md), [default.nix](https://github.com/nix-systems/triplet/blob/6de7bc09397911ce03636afbcf6118745ab2cda0/default.nix)). `nix-systems/default` dropped `x86_64-darwin` on 2026-03-25 ([c29398b](https://github.com/nix-systems/default/commit/c29398b59d2048c4ab79345812849c9bd15e9150)); before that it listed four systems ([da67096](https://github.com/nix-systems/default/blob/da67096a3b9bf56a91d16901293e51ba5b49a27e/default.nix)). Consequence: the `systems` default of any input resolved after that date no longer contains `x86_64-darwin`, but an old locked revision still can (section 4).

**What the repo's lock holds**: the repo's `flake.lock` pins `bun2nix.inputs.systems = ["nix-systems-darwin"]`, hunk's `systems` node is `nix-systems/triplet`, and root input `nix-systems-darwin` is `nix-systems/aarch64-darwin` at `75e6c69` (2023-04-08). Read from the lock with `python3` (section 3.1).

### 3. Tests

Scratch directory: `/private/tmp/claude-501/-Users-renman-ymd--config-nix-darwin/87e8b36d-45ee-404b-b1de-4ecd627155f6/scratchpad/t01/` (abbreviated `$T` below). The test flakes `A*` have only `nixpkgs` and `hunk` inputs and re-export `hunk.packages`; the lock was seeded from the repo's `flake.lock` so the hunk and bun2nix revisions are the locked ones unless `nix flake update hunk` is shown.

#### 3.1 Baseline: the repo as it is

```
$ nix eval --raw $T/repo-base#darwinConfigurations."Renauds-MacBook-Air".system.drvPath
/nix/store/aw8349hl24k92mg8fwc8680v6hmdb04a-darwin-system-26.11.4cff07d.drv
```

`repo-base` is a copy of the repo without `.jj` and `Workspace`.

#### 3.2 The current wiring fails on x86_64-linux (negative control N1)

`$T/N1/flake.nix` has `nix-systems-darwin.url = "github:nix-systems/aarch64-darwin"` and `hunk.inputs.bun2nix.inputs.systems.follows = "nix-systems-darwin"`, as in the repo.

```
$ nix eval --raw $T/N1#packages.aarch64-darwin.hunk.drvPath
/nix/store/2dfd6vl3b8bss2qvhyqyqgrcq52fa3sg-hunkdiff-0.22.0.drv
$ nix eval --raw $T/N1#packages.x86_64-linux.hunk.drvPath
error: attribute 'x86_64-linux' missing
       at .../source/flake.nix:43:38:
           43|           bun2nix = bun2nix.packages.${system}.default;
```

The error is hunk's `bun2nix.packages.${system}`, because bun2nix was cut to one system while hunk's own list still has three. Inference, not tested against the earlier research: the earlier "override test" most likely failed this way, or compared the wrong knob (`bun2nix.systems` instead of `hunk.systems`).

#### 3.3 The knob on its own: a systems list with `x86_64-darwin` fails on the Air

To check that the original reason for the comment is real, `$T/N2` sets `hunk.inputs.systems.follows` to `nix-systems/default` pinned at `da67096` (four systems, including `x86_64-darwin`):

```
$ nix eval --raw $T/N2#packages.aarch64-darwin.hunk.drvPath
error: Nixpkgs 26.11 has dropped support for x86_64-darwin.
       ...
       note: trace involved the following derivations:
       derivation 'hunkdiff-0.22.0'
       derivation 'bun-cache'
```

So the cause named in `flake.nix`'s comment reproduces. It is triggered by a systems list containing `x86_64-darwin`, not by `x86_64-linux`.

#### 3.4 Chosen wiring: no override (flake `A`, hunk `bc714de`, nixpkgs-unstable)

```
$ cat $T/A/flake.nix   # inputs: nixpkgs (nixpkgs-unstable), hunk (nixpkgs follows)
$ nix eval --raw $T/A#packages.aarch64-darwin.hunk.drvPath
/nix/store/2dfd6vl3b8bss2qvhyqyqgrcq52fa3sg-hunkdiff-0.22.0.drv
$ nix eval --raw $T/A#packages.x86_64-linux.hunk.drvPath
/nix/store/rzfz43z0a7qq2vxdxg50aar3mlzarrnn-hunkdiff-0.22.0.drv
$ nix eval --json $T/A#packages --apply 'p: builtins.attrNames p'
["aarch64-darwin","aarch64-linux","x86_64-linux"]
```

The `aarch64-darwin` derivation is identical to the one in 3.2, so removing the override does not change the Air's hunk.

Matrix (same commands, `show.sh` in `$T` prints the lock revisions and both drv paths):

| Flake | nixpkgs | hunk | `aarch64-darwin` drv | `x86_64-linux` drv |
|---|---|---|---|---|
| `A` | nixpkgs-unstable `b6c98e9` | `bc714de` (0.22.0) | `2dfd6vl3...-hunkdiff-0.22.0.drv` | `rzfz43z0...-hunkdiff-0.22.0.drv` |
| `A2` | nixos-unstable `7fd4004` | `bc714de` | `qq3asy38...-hunkdiff-0.22.0.drv` | `9dd56cbn...-hunkdiff-0.22.0.drv` |
| `A3` (`nix flake update hunk`) | nixpkgs-unstable `b6c98e9` | `6aa5261` (0.24.0-beta.0) | `870ypkh9...-hunkdiff-0.24.0-beta.0.drv` | `mr6f6z05...-hunkdiff-0.24.0-beta.0.drv` |
| `A4` (`nix flake update hunk`) | nixos-unstable `7fd4004` | `6aa5261` | `0wsf84z4...-hunkdiff-0.24.0-beta.0.drv` | `jv0vyxihs...-hunkdiff-0.24.0-beta.0.drv` |
| `A5` (extra: stable) | nixos-26.05 `0d9e9b8` | `bc714de` | `47yavpak...-hunkdiff-0.22.0.drv` | `mwbnwn0p...-hunkdiff-0.22.0.drv` |

In every row bun2nix stayed at `c843f47` (hunk's own lock) and its `systems` input followed `hunk/systems`.

```
$ nix flake show --all-systems $T/A4
└───packages
    ├───aarch64-darwin   ├───default / hunk: package 'hunkdiff-0.24.0-beta.0'
    ├───aarch64-linux    ...
    └───x86_64-linux     ...
```

#### 3.5 The real Air configuration

`repo-new-nobump` is the repo copy with the `nix-systems-darwin` input, the `inputs.bun2nix.inputs.systems.follows` line and the `nix-systems-darwin` `outputs` argument removed. The old lock refuses to load (the `hunk/bun2nix/systems` follow points at the removed input):

```
$ nix flake lock          # in repo-new-nobump
error: input 'hunk/bun2nix/systems' follows a non-existent input 'nix-systems-darwin'
```

Two ways to fix the lock were tested:

```
$ nix flake update hunk/bun2nix/systems     # repo-new-nobump
warning: 'hunk/bun2nix/systems' does not match any input of this flake
• Updated input 'hunk/bun2nix/systems':  follows 'nix-systems-darwin' → follows 'hunk/systems'
• Removed input 'nix-systems-darwin'
$ nix eval --raw $T/repo-new-nobump#darwinConfigurations."Renauds-MacBook-Air".system.drvPath
/nix/store/aw8349hl24k92mg8fwc8680v6hmdb04a-darwin-system-26.11.4cff07d.drv     # identical to 3.1

$ nix flake update hunk                     # repo-new: also bumps hunk to 6aa5261
• Updated input 'hunk' bc714de → 6aa5261
• Updated input 'hunk/bun2nix/systems': follows 'nix-systems-darwin' → follows 'hunk/systems'
• Removed input 'nix-systems-darwin'
$ nix eval --raw $T/repo-new#darwinConfigurations."Renauds-MacBook-Air".system.drvPath
/nix/store/ds649drimr74rmp398mqai6iiy6f22lx-darwin-system-26.11.4cff07d.drv
```

The first form leaves hunk where it is and gives the same system derivation as today, so the wiring change has no effect on the Air closure. Its warning is odd (the path is not a top-level input) but the lock is rewritten correctly. The second form is the plain way, but it ties a hunk bump to the same lock change.

With `nixpkgs.url` set to `github:NixOS/nixpkgs/nixos-unstable` (nixpkgs `7fd4004`) and `nix flake lock`:

```
$ nix eval --raw $T/repo-nixos#darwinConfigurations."Renauds-MacBook-Air".system.drvPath      # hunk bc714de
/nix/store/yc6mqv3s3dzagxvyndvx27xvqfji1a59-darwin-system-26.11.4cff07d.drv
$ nix eval --raw $T/repo-new-nixos#darwinConfigurations."Renauds-MacBook-Air".system.drvPath  # hunk 6aa5261
/nix/store/gxc6axdi1w1sk6ak6jpqrl8p1rm4c5jk-darwin-system-26.11.4cff07d.drv
```

`nixpkgs-for-lix` stayed on `nixpkgs-unstable` in these runs; it is a separate input and is not touched by the hunk wiring.

#### 3.6 The Framework side: NixOS plus Home Manager with hunk's module

`$T/C` has `nixosConfigurations.framework` (x86_64-linux, `home-manager.nixosModules.home-manager`, `home-manager.sharedModules = [ hunk.homeManagerModules.default ]`, the same pattern as the Air) and a standalone `homeConfigurations.fw-standalone`. The user module sets `programs.hunk.enable`, `enableGitIntegration`, `enableJujutsuIntegration`, `enableClaudeIntegration`, `settings.theme`, `programs.git.enable` and `programs.jujutsu.enable`. nixpkgs is nixos-unstable `7fd4004`, Home Manager `0b2f112`, hunk `bc714de`.

```
$ nix eval --raw $T/C#nixosConfigurations.framework.config.system.build.toplevel.drvPath
/nix/store/7r4clqyqkq2w8c61cllqps8bsjhcad8n-nixos-system-nixos-26.11.20261011.7fd4004.drv
$ nix eval --raw $T/C#homeConfigurations.fw-standalone.activationPackage.drvPath
/nix/store/snhya3rxa4lll0jxnj2nih7mwqvlqys0-home-manager-generation.drv
$ nix eval --raw $T/C#nixosConfigurations.framework.config.home-manager.users.renman-ymd.programs.hunk.package.drvPath
/nix/store/9dd56cbnxxq613ng0dp2wwnzgh8wp736-hunkdiff-0.22.0.drv      # same as A2 x86_64-linux
```

#### 3.7 Alternative tested: an in-repo systems flake

`$T/B` replaces the default with a two-system list in the repo, wired through hunk's knob:

```nix
# B/flake.nix (relevant part)
my-systems.url = "path:./systems";
hunk.inputs.systems.follows = "my-systems";
# B/systems/flake.nix  → { outputs = _: { }; }
# B/systems/default.nix → [ "aarch64-darwin" "x86_64-linux" ]
```

```
$ nix flake lock   # Lix 2.95.2 accepts the relative path: input
• Added input 'my-systems': 'path:./systems?lastModified=1&narHash=sha256-Q0zz...' (1970-01-01)
$ nix eval --raw $T/B#packages.aarch64-darwin.hunk.drvPath
/nix/store/0wsf84z45b55xhrb40vfn3i3m69hlqrj-hunkdiff-0.24.0-beta.0.drv     # same as A4
$ nix eval --raw $T/B#packages.x86_64-linux.hunk.drvPath
/nix/store/jv0vyxihskkcgychv80w0bsxvi64lmj4-hunkdiff-0.24.0-beta.0.drv     # same as A4
$ nix eval --json $T/B#packages --apply 'p: builtins.attrNames p'
["aarch64-darwin","x86_64-linux"]
```

It works and the derivations are identical to the default wiring, so the extra system `aarch64-linux` makes no difference to the output paths. It costs a directory, a lock entry whose `narHash` must be refreshed (`nix flake update my-systems`) after every edit of the list, and the repo is evaluated as a `path:` flake (it is non-colocated Jujutsu) so a relative path input is fine here. Not needed unless the default list stops fitting.

### 4. Does it survive the nixpkgs switch?

- nixos-unstable: yes. `A2`, `A4`, `repo-nixos`, `repo-new-nixos` and `C` above all use `nixos-unstable` at `7fd4004`. Hunk's own `nixpkgs` input already points to `github:NixOS/nixpkgs/nixos-unstable` ([flake.nix](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/flake.nix)), so following it only unifies the input.
- The wiring does not depend on which unstable branch is used, only on the systems list not containing `x86_64-darwin`. With that system in the list, evaluation of the Air throws the "Nixpkgs 26.11 has dropped support" error (section 3.3, run on nixpkgs-unstable `b6c98e9`). I did not rerun the negative control on `nixos-unstable`; its drv name (`nixos-system-nixos-26.11...`) shows it is also 26.11, so I expect the same throw (inference).
- nixos-26.05 also evaluates hunk for both systems (`A5`). Unverified: that it is what hunk's CI or maintainers intend; hunk's `flake.nix` only declares `nixos-unstable`.

### 5. Risks of the no-override wiring

- It relies on hunk keeping `systems` at a list without `x86_64-darwin` and with both needed systems. The comment in hunk's `flake.nix` documents the knob, so a later change would be a visible upstream decision, and the lock pins `nix-systems/triplet` at `6de7bc0` until `nix flake update hunk` is run. If it ever breaks, section 3.7 is the fallback.
- `aarch64-linux` is in the list and is evaluated only if someone asks for it (`nix flake check --all-systems`, `nix flake show --all-systems`, both fine in `A4`); it is not needed by the Air or the Framework.
- Input `nix-systems-darwin` can be deleted from the repo's `flake.nix`: its only use is the hunk follow and the `outputs` argument. Verified by evaluating the Air without it (3.5).

### 6. What is not verified

- **The x86_64-linux build itself.** No builder was available. `nix build --dry-run $T/A2#packages.x86_64-linux.hunk` says "these 604 derivations will be built" (the hunk package, `bun-cache`, `bun-compiler`, and one derivation per npm tarball; the list also holds many `bun-pkg-*` tarball derivations for other platforms) and "these 209 paths will be fetched (515.88 MiB download, 1737.61 MiB unpacked)", including `zig-0.15.2` and `bun-1.4.2`. That is a build plan, not a build.
- Primary evidence for the build, on hunk's own lock: hunk's `Nix` workflow runs `nix flake check --print-build-logs`, `nix flake check --all-systems --no-build`, `nix build .#default` and a `hunk --version` smoke test on `ubuntu-latest`, which GitHub lists as x64 ([nix.yml](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/.github/workflows/nix.yml), [runner-images README](https://github.com/actions/runner-images/blob/main/README.md)). The run for the locked commit `bc714de` succeeded ([run 35673947567](https://github.com/modem-dev/hunk/actions/runs/35673947567)), and so did the run for `main` `6aa5261` ([run 38346623148](https://github.com/modem-dev/hunk/actions/runs/38346623148)). Both used hunk's own `flake.lock` (its own nixpkgs and bun2nix pins), not this repo's lock, and not nixos-unstable `7fd4004`, so this is evidence for hunk, not for this exact combination.
- Runtime behaviour on the Framework, and whether `hunk` starts there (the CI smoke test ran `hunk --version` and `hunk skill path` on Ubuntu, not NixOS).
- Whether the substituter state at build time matches the dry run (it reflects today, from this machine's configured substituters).
- The Framework's Home Manager revision: the module needs `programs.git.settings`, present on `release-25.11` and `release-26.05` and absent from my check of `release-25.05` (section 2). Only the git option is affected, and only when `enableGitIntegration` is set.
- Which flake the Framework will actually use hunk from (a shared `home.nix` import, a NixOS module, or a separate output); only the NixOS-module and standalone-Home-Manager shapes were evaluated (3.6).

### Sources

- [modem-dev/hunk `flake.nix` @ bc714de](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/flake.nix) (same content on `main` @ 6aa5261)
- [modem-dev/hunk `nix/home-manager.nix` @ bc714de](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/nix/home-manager.nix)
- [modem-dev/hunk `nix/package.nix` @ bc714de](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/nix/package.nix)
- [modem-dev/hunk `.github/workflows/nix.yml` @ bc714de](https://github.com/modem-dev/hunk/blob/bc714dedabe8a8351c05101bdbfd07ad88958ec9/.github/workflows/nix.yml)
- [modem-dev/hunk #621 `fix(nix): keep flake evaluable on nixpkgs without x86_64-darwin`](https://github.com/modem-dev/hunk/commit/2884b5697) and its [changeset](https://github.com/modem-dev/hunk/blob/2884b5697/.changeset/nix-flake-drop-x86-darwin.md)
- [hunk CI run for bc714de](https://github.com/modem-dev/hunk/actions/runs/35673947567), [hunk CI run for 6aa5261](https://github.com/modem-dev/hunk/actions/runs/38346623148)
- [nix-community/bun2nix `flake.nix` @ c843f47](https://github.com/nix-community/bun2nix/blob/c843f477b15f51151f8c6bcc886954699440a6e1/flake.nix), [`flake.nix` @ 0f2a1f0](https://github.com/nix-community/bun2nix/blob/0f2a1f0b6f42cebe3b149bf62d38754c5e0e9729/flake.nix), [`nix/dev/systems.nix`](https://github.com/nix-community/bun2nix/blob/c843f477b15f51151f8c6bcc886954699440a6e1/nix/dev/systems.nix), [`nix/dev/formatter.nix`](https://github.com/nix-community/bun2nix/blob/c843f477b15f51151f8c6bcc886954699440a6e1/nix/dev/formatter.nix)
- [nix-systems/triplet @ 6de7bc0](https://github.com/nix-systems/triplet/blob/6de7bc09397911ce03636afbcf6118745ab2cda0/README.md); [nix-systems/default `x86_64-darwin` removal](https://github.com/nix-systems/default/commit/c29398b59d2048c4ab79345812849c9bd15e9150) and [the earlier four-system list](https://github.com/nix-systems/default/blob/da67096a3b9bf56a91d16901293e51ba5b49a27e/default.nix)
- [actions/runner-images README](https://github.com/actions/runner-images/blob/main/README.md) (`ubuntu-latest` is Ubuntu 24.04, x64)
- [home-manager `modules/programs/git.nix` on release-25.11](https://github.com/nix-community/home-manager/blob/release-25.11/modules/programs/git.nix) and [release-26.05](https://github.com/nix-community/home-manager/blob/release-26.05/modules/programs/git.nix)
- Local: `flake.nix` and `flake.lock` of this repo (locked revisions read with `python3` from the lock), Lix 2.95.2, `nix eval`, `nix flake lock`, `nix flake update`, `nix flake show --all-systems`, `nix build --dry-run`; scratch flakes in `$T`
