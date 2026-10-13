## Scripts and Nushell modules

Research date: 2026-10-13. Versions and revisions seen:

- **This repo's lock:** Home Manager `0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0` (2026-09-23), nixpkgs `b6c98e9e6633ee64753b594ff4a5febf0367fc00` (2026-09-22), nix-darwin `4cff07de74b50e64bdd68cd4e722ab5b6b35ee48`. That nixpkgs has nushell 0.115.1 and jujutsu 0.45.1.
- **Newer:** Home Manager master `c58f54c733a7894d84fa2fdff26cc12088c4b78c`; nixpkgs `nixpkgs-unstable` `8edc0c72e3a38faf5434e40d1f19431125fe4b30` (2026-10-08), `nixos-unstable` `7fd4004d0511991fff3a0524856a9be09e28c5f0` (2026-10-11), master `db81a1d5ba9fc2b2ac5305557a7342a594e709e4` (2026-10-13).
- **The tools:** jj-ci tag `v1.0.0` = `3eadcde25857aa1722edd8f6a085365d84e8f0d9` (= `main`); ufda `main` = `ccc3a680a986745509545ca73669325c0b196d3b`, no tags. The local checkouts in `~/Scripts/` have the same file contents as those revisions (`diff -r -x .jj` against the fetched trees is empty). Both repos answer HTTP 200 to anonymous requests.
- **Local tooling:** Lix 2.95.2 (`nix --version`), on aarch64-darwin.

Everything was run with the nixpkgs Nushell (`nu --no-config-file …`, or `nu -l --config <file> --env-config <empty>` when a `config.nu` had to be loaded), never Renaud's own configured `nu`. `HOME` was pointed at a scratch directory, so nothing outside the scratch directory was written. `$S` below is `/private/tmp/claude-501/-Users-renman-ymd--config-nix-darwin/87e8b36d-45ee-404b-b1de-4ecd627155f6/scratchpad/t32`. `$NU115` and `$NU116` are the store paths of nixpkgs' `nushell` 0.115.1 (locked rev) and 0.116.1 (master rev). `$JJCI` and `$UF` are the fetched source trees of jj-ci and ufda.

### 1. Loading Nushell modules through Home Manager

**What `programs.nushell` offers** ([nushell.nix at the locked rev](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/nushell.nix); the file is byte-identical at master `c58f54c`, checked with `diff`):

- **No option for module directories, and none for `use` lines.** The options are `configDir`, `configFile`, `envFile`, `loginFile`, `extraConfig`, `extraEnv`, `extraLogin`, `plugins`, `settings`, `shellAliases`, `environmentVariables` ([L45-L214](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/nushell.nix#L45-L214)).
- **`config.nu` is the concatenation, in this order,** of `load-env` for `environmentVariables`, `$env.config.<path> = …` lines for `settings`, `configFile.text`, `extraConfig`, then the `alias` lines ([L242-L278](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/nushell.nix#L242-L278)). `env.nu` is `envFile.text` then `extraEnv` ([L282-L287](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/nushell.nix#L282-L287)). `extraConfig` and `extraEnv` are `types.lines`, so several modules can contribute and `lib.mkBefore`/`lib.mkAfter`/`lib.mkOrder` control the order.
- **`configFile.source`/`envFile.source` are read with `builtins.readFile`** ([L20](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/nushell.nix#L20)). A static `.nu` file in the repo therefore cannot contain `${pkgs.foo}` store paths; those have to come from a Nix string.
- **On this Mac `configDir` is `~/Library/Application Support/nushell`,** not `~/.config/nushell`. The default is `Library/Application Support/nushell` on Darwin when `xdg.enable` is off ([L50-L56](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/nushell.nix#L50-L56)); `modules/home.nix` never sets `xdg.enable`, and the live files agree:

```text
$ ls -la ~/Library/Application\ Support/nushell      # trimmed
config.nu -> /nix/store/biyxv3la…-home-manager-files/Library/Application Support/nushell/config.nu
env.nu    -> …
$ /etc/profiles/per-user/renman-ymd/bin/nu --no-config-file -c '[$nu.default-config-dir $nu.data-dir $nu.user-autoload-dirs $NU_LIB_DIRS] | to nuon'
["…/Library/Application Support/nushell", "…/Library/Application Support/nushell",
 ["…/Library/Application Support/nushell/autoload"],
 ["…/Library/Application Support/nushell/scripts", "…/Library/Application Support/nushell/completions"]]
```

On macOS the data dir equals the config dir, so Nushell's default `NU_LIB_DIRS` is `<config>/scripts` and `<config>/completions` ([book: NU_LIB_DIRS constant](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/configuration.md?plain=1#L507-L523)). On Linux the data dir is a different directory, so only `<config>/scripts` is portable.

**The Home Manager option example is broken.** The example on `configFile` ([L71-L82](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/nushell.nix#L71-L82)) generates `const NU_LIB_DIRS = $NU_LIB_DIRS ++ "<path>"`, a string appended to a list. Tested with the equivalent line:

```text
$ printf 'const NU_LIB_DIRS = $NU_LIB_DIRS ++ "/tmp/x/scripts"\n' > $S/cfg-hmexample.nu
$ $NU115/bin/nu -l --config $S/cfg-hmexample.nu --env-config $S/empty-env.nu -c '$NU_LIB_DIRS | length'
Error: nu::parser::operator_incompatible_types
  x Types 'list<string>' and 'string' are not compatible for the '++' operator.
```

Appending a list works: `const NU_LIB_DIRS = $NU_LIB_DIRS ++ ["<dir>"]`. With `lib.hm.nushell.toNushell { } [ dir ]` the Nix side produces that list literal (`toNushell {} ["/a" "/b"]` printed a Nushell list).

**Three ways to add a module, all tested.** Each was built as a real Home Manager generation (`home-manager.lib.homeManagerConfiguration` at the locked rev, `nix build .#homeConfigurations.<x>.activationPackage` in `$S/flk`), then run with `HOME` pointing at that generation's `home-files`:

| Pattern | Nix side | Nushell side | Result |
|---|---|---|---|
| A. Store path in `extraConfig` | `extraConfig = "use ${pkg}/share/nushell/modules/jj-ci"` | the generated `use /nix/store/…/jj-ci` | works, if the directory at the end of the path is named `jj-ci` (see below) |
| B. Link into `scripts/` | `home.file."${config.programs.nushell.configDir}/scripts/jj-ci".source = <path>` | `use jj-ci` (static text) | works with no `NU_LIB_DIRS` change: `scripts/` is already on the default search path |
| C. Extra lib dir | `extraConfig = "const NU_LIB_DIRS = $NU_LIB_DIRS ++ [\"${dir}\"]\nuse jj-ci"` | same | works; `$env.NU_LIB_DIRS` in `extraEnv` also works |

```text
# B, nu 0.115.1 (and 0.116.1 gave the same 9 commands)
$ ls -la "$S/fakehome/Library/Application Support/nushell/scripts/"
jj-ci -> /nix/store/jjdi62z015a25zp7gihw12zw0madgp9x-source
ufda  -> /nix/store/0c3fdx5djdrb7i5yn32yl5r7fw9kkisc-source
$ cat "$S/fakehome/Library/Application Support/nushell/config.nu"
source /nix/store/lc27jifi…-jj-ci-completions.nu
use jj-ci
use ufda
$ HOME=$S/fakehome $NU115/bin/nu -l -c 'scope commands | where name =~ "^(jj-ci|ufda)" | select name type'
jj-ci, jj-ci checks, jj-ci ci, jj-ci completions, jj-ci doctor, jj-ci init, jj-ci install, jj-ci push, ufda   (all custom)
```

For C, `$env.NU_LIB_DIRS` set in the same `config.nu` is too late, because `use` resolves while the file is parsed and the assignment runs only after. This also rules out Home Manager's `environmentVariables.NU_LIB_DIRS`, which writes `load-env { … }` into `config.nu`:

```text
$ printf '$env.NU_LIB_DIRS = ($env.NU_LIB_DIRS | append "%s")\nuse jj-ci\n' $LF > $S/cfg-sameenv.nu     # LF = a linkFarm with jj-ci/ and ufda/
$ … --config $S/cfg-sameenv.nu … -c '…'
Error: nu::parser::module_not_found   (same for the load-env form)
```

The same assignment placed in `env.nu` (`extraEnv`) works, because `env.nu` is evaluated before `config.nu` is parsed ([book: launch stages 20-22](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/configuration.md?plain=1#L615-L617)).

**Keeping the folder named `jj-ci`.** The module name is the directory's name as written in the `use` path, not the name of what it links to ([book: a `mod.nu` makes its directory the module name](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/modules/creating_modules.md?plain=1#L22)). A flake input is a store path whose last component is `<hash>-source`, so using it directly is wrong:

```text
$ $NU115/bin/nu --no-config-file -c "use $JJCI; scope commands | where name =~ 'ci' | get name | first 5"
│ 0 │ jjdi62z015a25zp7gihw12zw0madgp9x-source ci │          # same on 0.116.1

$ mkdir $S/lib1; ln -s $JJCI $S/lib1/jj-ci
$ $NU115/bin/nu --no-config-file -c "use $S/lib1/jj-ci; scope commands | where name =~ 'jj-ci' | get name"
jj-ci, jj-ci checks, jj-ci ci, jj-ci completions, jj-ci doctor, jj-ci init, jj-ci install, jj-ci push   # same on 0.116.1

$ $NU115/bin/nu --no-config-file -c "use $JJCI as jj-ci; …"
Error: nu::parser::export_not_found      # `as` renames an export, as jj-ci's docs/install.md says
```

So these all give the name `jj-ci`:

- a symlink named `jj-ci` to the source tree (Home Manager's `home.file.<dir>/jj-ci.source = <input>` makes exactly this, and so does `pkgs.linkFarm "m" [{ name = "jj-ci"; path = input; }]`, tested as pattern C);
- a real directory named `jj-ci` inside a derivation's output (the package in §2).

**What parse-time `use` means for a module that comes from Nix.**

- **The path must exist when `config.nu` is parsed.** A failing `use` makes the whole `config.nu` fail to parse and be skipped; the REPL still starts, with an error printed. Tested on a pty:

  ```text
  $ cat $S/cfg-missing.nu
  $env.config.show_banner = false
  use /nix/store/does-not-exist-jj-ci/share/nushell/modules/jj-ci
  alias ll = ls --long
  $ script -q /dev/null $NU115/bin/nu --config $S/cfg-missing.nu --env-config $S/empty-env.nu -e 'print "REPL REACHED"; print $"aliases: (scope aliases | length)"; exit'
  Error: nu::parser::module_not_found ... module /nix/store/does-not-exist-jj-ci/... not found
  REPL REACHED
  aliases: 0
  ```

  The `alias` and the setting after the failing line were not applied. For store paths this cannot happen while the generation is live: the store path is in the generation's closure (`nix-store -qR $S/flk/hm-act | grep -c 'jj-ci-1.0.0\|ufda-0'` printed 2), so it is not garbage-collected.
- **Files in `<config>/autoload/` fail one at a time.** Home Manager has no option for them, but `home.file."${configDir}/autoload/<name>.nu"` works, and the files are sourced after `config.nu` in alphabetical order ([book, load order](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/configuration.md?plain=1#L72-L76), [launch stages 24-25](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/configuration.md?plain=1#L619-L620)). Tested with four files (`10-jj-ci-completions.nu`, `20-jj-ci.nu`, `30-broken.nu` containing `use does-not-exist`, `40-ufda.nu`):

  ```text
  $ script -q /dev/null env HOME=$S/fakehome2 $NU115/bin/nu -e '…; exit'
  Error: nu::parser::module_not_found … 30-broken.nu:1:5 … module does-not-exist not found
  --- REPL reached
  jj ci:external, jj-ci:custom, jj-ci checks:custom, … jj-ci push:custom, ufda:custom
  aliases: ll
  ```

  The broken file was skipped; the others, and `config.nu`'s `ll` alias, loaded.
- **Cost:** every shell start parses the module's ~20 files. Measured on this Mac with `hyperfine -N --warmup 3 --runs 20` (`nu -l --config <file> --env-config <empty> -c exit`): 23.0 ms ± 0.3 with an empty config against 42.6 ms ± 5.5 with `use` of jj-ci and ufda on 0.115.1. About 20 ms for both. Nushell 0.116.0 says it roughly halves config load time for configs that `use` many modules ([0.116.0 release notes](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/blog/2026-09-26-nushell_v0_116_0.md?plain=1#L784-L796)); not measured here.
- **Syntax errors in a module become startup errors,** as jj-ci's own docs warn ([install.md](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/docs/install.md)). The package in §2 runs `nu --no-config-file -c "use <module>"` in `installCheckPhase`, so a Nushell bump that breaks a module fails the build, not the shell. Checked that the command exits 1 on a broken module and 0 on jj-ci, with 0.115.1; the module also parses with 0.116.1.
- **A running shell keeps the module version it first imported** ([book, creating modules, L6](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/modules/creating_modules.md?plain=1#L6)); after `darwin-rebuild switch`, open shells need restarting. Taken from the docs, not tested.

**`$nu.vendor-autoload-dirs` is not usable on this Mac without a nix-darwin change.** It does list `/etc/profiles/per-user/renman-ymd/share/nushell/vendor/autoload` and `~/.nix-profile/share/nushell/vendor/autoload`, so a package could ship its own autoload file. But the per-user profile is built with nix-darwin's `environment.pathsToLink` ([users module](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/users/default.nix)), and the evaluated value for this flake is:

```text
$ nix eval --raw .#darwinConfigurations.Renauds-MacBook-Air.config.environment.pathsToLink --apply 'x: builtins.concatStringsSep " " x'
/etc/profile.d /share/zsh /info /share/info /share/man /share/terminfo /bin /share/locale
```

No `/share/nushell`, and `/etc/profiles/per-user/renman-ymd/share/` has no `nushell` directory. Linking it would need a nix-darwin option, which ADR 0002 keeps out of home modules.

**Implications for this repo:**

- **Pattern B keeps `.nu` files free of Nix.** A shell feature's static `.nu` file can say `use jj-ci` and `source jj-ci-completions.nu` (tested: `source` also searches `NU_LIB_DIRS`), while the home module adds only `home.file."${configDir}/scripts/…"` links. This matters for ticket 05, where `.nu` files read with `readFile` cannot hold store paths.
- **Pattern A needs a Nix string**, so it fits a feature's `extraConfig` but not a static file.
- **Everything uses Home Manager options only** (`programs.nushell.*`, `home.file`, `home.packages`), so ADR 0002 holds and the same modules run standalone.

### 2. Packaging jj-ci and ufda, `PATH`, self-location and shebangs

**Source: non-flake inputs.** Both repos are public, and each has a `mod.nu` that is both a module and a script, with `bin/<name>` a relative symlink to `../mod.nu`.

```nix
inputs.jj-ci = { url = "github:renman-ymd/jj-ci/v1.0.0"; flake = false; };
inputs.ufda  = { url = "github:renman-ymd/ufda";          flake = false; };   # no tags; flake.lock pins the rev
```

- **Prefetch worked and kept the symlink:**

  ```text
  $ nix flake prefetch github:renman-ymd/jj-ci/3eadcde25857aa1722edd8f6a085365d84e8f0d9 --json
  {"hash":"sha256-VW4Ap8RX/lQ6ZBAZcrHoAuzih1KUOG5W4NGd4MzLQHo=","storePath":"/nix/store/jjdi62z015a25zp7gihw12zw0madgp9x-source"}
  $ ls -la $JJCI/bin
  lrwxr-xr-x  jj-ci -> ../mod.nu
  ```

  GitHub's anonymous API limit (403) blocked tag and branch names during testing, so the scratch flake pins full revisions, which download as tarballs with no API call (as in [03 §5](03-work-machine-config.md)). `nix flake lock` with `…/v1.0.0` needs one API call; run it when not rate-limited.
- **Developing against the local checkout** needs no edit to the flake: `nix build .#jj-ci --override-input jj-ci path:/Users/renman-ymd/Scripts/jj-ci --no-write-lock-file` built from `~/Scripts/jj-ci` (the build ran; I did not run the result). `path:` is needed because the checkouts are non-colocated, with no `.git`.

**The package.** A real directory named after the tool, plus `bin/`. This version patches the shebang, so no wrapper is needed (`pkg-noWrapper.nix` in `$S`):

```nix
pkgs.stdenvNoCC.mkDerivation {
  pname = "jj-ci"; version = "1.0.0"; src = inputs.jj-ci;
  dontBuild = true;
  buildInputs = [ pkgs.nushell ];            # patchShebangs resolves `nu` from here
  installPhase = ''
    mkdir -p $out/share/nushell/modules/jj-ci $out/bin
    cp -a . $out/share/nushell/modules/jj-ci
    ln -s ../share/nushell/modules/jj-ci/mod.nu $out/bin/jj-ci
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.nushell ];
  installCheckPhase = ''
    export HOME=$TMPDIR
    nu --no-config-file -c "use $out/share/nushell/modules/jj-ci"
  '';
}
```

```text
$ nix build --impure --file pkg-noWrapper.nix -o nowrap
jj-ci> …/share/nushell/modules/jj-ci/mod.nu: interpreter directive changed from "#!/usr/bin/env nu" to "/nix/store/f45b1irl…-nushell-0.115.1/bin/nu"
jj-ci> …/action/run-checks.sh: interpreter directive changed from "#!/usr/bin/env bash" to "…-bash-5.3p15/bin/bash"   (×4)
$ ls -la nowrap/bin
jj-ci -> ../share/nushell/modules/jj-ci/mod.nu
```

- The stdenv patches every file in the output, which is why `mod.nu` changes though it is not in `bin/`. The four `action/*.sh` files (for jj-ci's GitHub Action) pull bash into the closure. `rm -r $out/share/nushell/modules/jj-ci/{action,.github}` in `installPhase` avoids that; not tried.
- A second variant in `$S/flk/flake.nix` (`mkNuTool`) keeps the shebang and instead writes `$out/bin/<name>` with `makeWrapper ${lib.getExe pkgs.nushell} … --add-flags "--no-config-file $out/share/nushell/modules/<name>/mod.nu"` (and `--prefix PATH` for ufda's `direnv`). It built and ran too. Both work; the symlink one is simpler and keeps jj-ci's own `bin/jj-ci` path valid for `jj-ci install` and `doctor`.
- `home.packages = [ pkgs.jj-ci pkgs.ufda ]` puts `bin/` on `PATH` through the profile; Home Manager is the only mechanism needed (`/etc/profiles/per-user/renman-ymd/bin` is already on the `PATH` set in `extraEnv`). To get `pkgs.jj-ci` in a home module, add the derivations to an overlay: `flake.nix` already sets `nixpkgs.overlays = [ nur.overlays.default ]` in the system module, which `useGlobalPkgs` shares with Home Manager. Another route is `inputs` in `home-manager.sharedModules`, like `hunk.homeManagerModules.default` today.

**Self-location works from the store.** Evidence per construct:

- **`const ROOT = (path self | path expand | path dirname)`** ([jj-ci mod.nu L5-L6](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/mod.nu#L5-L6)) and ufda's `path self | path expand | path dirname` ([mod.nu L5](https://github.com/renman-ymd/ufda/blob/ccc3a680a986745509545ca73669325c0b196d3b/mod.nu#L5)). `path self` is parse-time and returns the path as invoked ([`path self` docs](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/commands/docs/path_self.md)); `path expand` resolves the `bin/jj-ci` symlink to the real `mod.nu`, so the `use $"($ROOT)/commands"` lines find the sibling folders. Tested through four routes: the raw source tree's `bin/jj-ci`, the packaged symlink above, the wrapper, and the module loaded by `use` from a Home Manager `scripts/` link. Each ran at least one command (`checks`, `ci`, `doctor` or `install`); the `$ROOT` that `doctor` and `install` print was the real store path in every case.
- **`commands/*.nu` use `const LIB = path self "../lib"`** (e.g. [install.nu L4](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/commands/install.nu#L4)); same result.
- **`$nu.current-exe "--no-config-file" $SELF`** ([mod.nu L12-L13](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/mod.nu#L12-L13)) is how `jj run` re-enters jj-ci. A full gate run, with a one-check `.jj-ci.toml`, in a scratch non-colocated repo (`jj git init --no-colocate`, `JJ_USER`/`JJ_EMAIL` set):

  ```text
  $ PATH=$NU116/bin:$PATH $JJCI/bin/jj-ci ci --verbose
  push: 1 revision in reachable(@, mutable())
  running-in-working_copy
    lszkskqv  hello  ✓  0.0s
  ok — 1 passed
  ```

  Same with 0.115.1 as script and as module (`use $S/lib1/jj-ci; jj-ci ci`), from the packaged symlink with a `PATH` lacking `nu`, and from the wrapper. `$nu.current-exe` returns the path `nu` was invoked by, not a resolved one: through a symlink `fakeprofile/bin/nu` it printed the symlink. So under Home Manager it would be `/etc/profiles/per-user/renman-ymd/bin/nu` (inferred from that behaviour; the real profile was not exercised through `jj ci`).
- **Nothing persistent holds a store path.** The repo-config block that `jj-ci ci` writes (`# >>> jj-ci managed …` in `~/.config/jj/repos/<id>/config.toml`) holds only filesets and `fix.tools` ([render.nu](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/lib/render.nu)); the self command exists only for the duration of one `jj run`. That repo-config file is outside what Home Manager manages.
- **ufda** writes only to `$nu.cache-dir` ([outputs.nu L50](https://github.com/renman-ymd/ufda/blob/ccc3a680a986745509545ca73669325c0b196d3b/flake/outputs.nu#L50)), never next to itself. `ufda .` from the store wrapper, in a scratch dir with a `flake.nix`, printed ``Created .envrc with `use flake .`.`` and wrote the file; `direnv` has to be on `PATH` (the wrapper variant adds it; the profile has it anyway). Its `--with-devenv` still fails cleanly without a `devenv.nix` (`ufda::io::not_found`) and needs devenv itself, which ticket 06 removes.

**Shebangs under Nix.**

- **`#!/usr/bin/env nu` works only when `nu` is on `PATH`.** `env -i PATH=/usr/bin:/bin ./hello.nu` gives `env: nu: No such file or directory`. That is fine in Renaud's interactive shells, but not under launchd, cron, `jj util exec` from a stripped environment, or the work machines.
- **stdenv's `patchShebangs` fixes this** (shown above for jj-ci; for the `gh/` scripts below).
- **A script run by path does not read the user's `config.nu`.** The book's flag table says `nu <script_file>` behaves like `-c`, with no config-file stages ([L633-L634](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/configuration.md?plain=1#L633-L634)); a throwaway `config.nu` containing `print "CONFIG.NU LOADED"` was not run by `XDG_CONFIG_HOME=$S/xdg ./hello.nu`. So a patched absolute shebang needs no `--no-config-file`, which jj-ci passes to its own children anyway.

**The `gh/` scripts** are four standalone Nushell scripts with `#!/usr/bin/env nu` and no self-location (`grep 'path self\|current-exe\|^use ' gh/{pr,read}/*.nu` finds nothing). They fit a plain derivation; the scratch build (`gh-drv.nix`, sources copied to `$S/gh-copy`) patched all four shebangs to the store `nu` (`head -1 gh-out/bin/*` shows `#!/nix/store/f45b1irl…-nushell-0.115.1/bin/nu` for each) and `jj-pr-stack --help` ran:

```nix
installPhase = ''
  install -Dm755 pr/create.nu        $out/bin/jj-pr-create
  install -Dm755 pr/stack.nu         $out/bin/jj-pr-stack
  install -Dm755 read/pr-comments.nu $out/bin/gh-pr-comments
  install -Dm755 read/issue-tree.nu  $out/bin/gh-issue-tree
'';
```

These need `gh`, `jj`, and for `pr-comments` `hunk` on `PATH` at run time (`~/Scripts/gh/README.md`, requirements table). `pr/create.nu` uses `str lowercase`; the same README says `str downcase` is deprecated since Nushell 0.114.0, so the 0.115.1 lock is fine (I did not run `pr/create.nu`, which is interactive and pushes). The jj alias would then read `pr-create = [ "util" "exec" "--" "${gh-scripts}/bin/jj-pr-create" ]`. Deciding whether `gh/` becomes a repo, an input or part of this repo is ticket 33's.

### 3. jj-ci's aliases, completions, and how they look in Home Manager

**What `jj-ci install` prints.** Run without `--write` (it only prints; `--write` is a separate flag, [install.nu L15-L22](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/commands/install.nu#L15-L22)). With `--help` checked first: flags are `--format <string> (default: 'both')`, `--on-path`, `--write`.

```text
$ $NU115/bin/nu --no-config-file /Users/renman-ymd/Scripts/jj-ci/bin/jj-ci install
# ~/.config/jj/config.toml
[aliases]
ci = ["util", "exec", "--", "/Users/renman-ymd/Scripts/jj-ci/bin/jj-ci", "ci"]
push = ["util", "exec", "--", "/Users/renman-ymd/Scripts/jj-ci/bin/jj-ci", "push"]

# home-manager
programs.jujutsu.settings.aliases = {
  ci = [ "util" "exec" "--" "/Users/renman-ymd/Scripts/jj-ci/bin/jj-ci" "ci" ];
  push = [ "util" "exec" "--" "/Users/renman-ymd/Scripts/jj-ci/bin/jj-ci" "push" ];
};

# Nushell completions for those two aliases. jj generates its own the same way,
# and it cannot know about aliases, so this is a second file beside it.
home.activation.jjCiNushellCompletions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  mkdir -p "$HOME/.config/nushell/completions"
  /Users/renman-ymd/Scripts/jj-ci/bin/jj-ci completions nushell > "$HOME/.config/nushell/completions/jj-ci.nu"
'';

# …and, beside the line that sources jj.nu:
#   source ~/.config/nushell/completions/jj-ci.nu
```

`--on-path` replaces the absolute path with the bare `jj-ci`. `--write` refuses when `jj config path --user` is a symlink, which it is under Home Manager ([install.nu L56-L61](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/commands/install.nu#L56-L61)).

**As `programs.jujutsu.settings` values.** `programs.jujutsu.settings` is `pkgs.formats.toml`'s type and the file is `home.file."${xdg.configHome}/jj/config.toml"` ([jujutsu.nix L54-L56, L95-L97](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/jujutsu.nix#L54-L56)). The printed block is valid as is, with the store path substituted (`lib.getExe pkgs.jj-ci`, or the interpolated path); the generated TOML from the test generation was:

```text
[aliases]
ci = ["util", "exec", "--", "/nix/store/zl6qxjq…-jj-ci-1.0.0/bin/jj-ci", "ci"]
push = ["util", "exec", "--", "/nix/store/zl6qxjq…-jj-ci-1.0.0/bin/jj-ci", "push"]
```

**Three catches in the printed block:**

1. **`push` is already defined in `modules/home.nix`** (`push = [ "util" "exec" "--" "nu" "-c" "jj tug; jj git push"]`). Two definitions of one list do not conflict, they concatenate. Tested with the repo's locked nixpkgs:

   ```text
   $ nix eval --impure --json --file $S/mergetest.nix     # two modules each set s.aliases.push
   {"aliases":{"ci":["b"],"other":["a"],"push":["util","exec","--","jj-ci","push","util","exec","--","nu"]}}
   ```

   So the existing `push` must be replaced, not added to, and a feature must be the single owner of each alias key. `jj-ci push` tugs by itself ([commands.md, Tugging](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/docs/commands.md)), which is ticket 33's question about the `tug` alias.
2. **The activation snippet writes at activation time, with a bare or absolute command.** With `--on-path` it calls `jj-ci`, which is not on the activation script's `PATH` (Unverified: I did not run an activation script. The repo's existing `jjNushellCompletions` snippet uses the absolute `${pkgs.jujutsu}/bin/jj`, not a bare `jj`). The output does not depend on the environment, so a build-time derivation does the same job and needs no activation step (tested, builds in the sandbox, 3196 bytes):

   ```nix
   jj-ci-completions = pkgs.runCommand "jj-ci-completions.nu" { nativeBuildInputs = [ pkgs.nushell ]; } ''
     export HOME=$TMPDIR
     ${lib.getExe pkgs.jj-ci} completions nushell > $out
   '';
   ```

   It is then linked with `home.file."${configDir}/scripts/jj-ci-completions.nu".source = jj-ci-completions;` and loaded by `source jj-ci-completions.nu`, or sourced by store path from `extraConfig`. The same would work for the existing `jj util completion nushell` activation snippet; not tried.
3. **Order matters when both the module and the completions are loaded.** The generated file defines `extern`s for `jj ci`, `jj push` and also for `jj-ci`, `jj-ci checks`, `jj-ci init`, `jj-ci install`, `jj-ci doctor`, `jj-ci completions` ([completions.nu](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/commands/completions.nu#L23-L99)). If it is sourced after `use jj-ci`, the externs shadow the module's real commands:

   ```text
   # config.nu:  use <jj-ci>   then   source <completions>
   jj-ci: external, jj-ci checks: external, jj-ci ci: custom, jj-ci completions: external, jj-ci doctor: external,
   jj-ci init: external, jj-ci install: external, jj-ci push: custom
   # config.nu:  source <completions>   then   use <jj-ci>
   jj ci: external, jj push: external, jj-ci: custom, jj-ci checks: custom, … jj-ci push: custom
   ```

   Source the completions first. (Or drop the `jj-ci …` externs from the generated file, a change to jj-ci. With the module loaded they are redundant, as install.md says.) In an autoload layout, name the files `10-…completions.nu` before `20-…use.nu`; the four-file test above loaded that way.

**How the `extern` completions are generated.** `jj-ci completions nushell` ([mod.nu L78](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/mod.nu#L78), [completions.nu L11-L21](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/commands/completions.nu#L11-L21)) returns a fixed template string with `@CI@` and `@PUSH@` replaced by the alias names (`--ci-alias`, `--push-alias`, default `ci` and `push`); it does not call jj, so it is deterministic and works in a build sandbox. The template is a `module jj_ci_completions { … }` followed by `export use jj_ci_completions *`. Only `nushell` is accepted. Both `jj ci --stage ` and the `jj ci` flags complete on 0.115.1 and 0.116.1:

```text
$ $NU116/bin/nu --no-config-file -c "source $C; 'jj ci --stage ' | commandline complete | to nuon"      # also 0.115.1
[ci, push]
```

(`commandline complete` runs the completion engine on a string; no Tab was pressed in a real terminal.)

### 4. Nushell versions

| Where | Nushell | jujutsu | Source |
|---|---|---|---|
| This repo's lock, nixpkgs `b6c98e9` (2026-09-22) | **0.115.1** | 0.45.1 | `nix eval --raw github:NixOS/nixpkgs/b6c98e9e…#nushell.version` |
| `nixpkgs-unstable` `8edc0c7` (2026-10-08) | **0.115.1** | 0.46.0 | same, at that rev |
| `nixos-unstable` `7fd4004` (2026-10-11) | **0.116.1** | not checked | same |
| nixpkgs master `db81a1d` (2026-10-13) | **0.116.1** | 0.46.0 | same |
| Upstream tags | 0.116.0 (2026-09-26), 0.116.1 (2026-10-04) | | [nushell tags](https://github.com/nushell/nushell/tags), [release notes](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/blog/2026-09-26-nushell_v0_116_0.md) |

The two channels disagree today: `nixos-unstable` has already moved to 0.116.1 while `nixpkgs-unstable`, the branch `flake.nix` tracks, was still on 0.115.1 at the revision read. The next `flake: update inputs` bump may or may not bring 0.116.x; that depends on when `nixpkgs-unstable` advances, which I cannot predict.

**What was tested against 0.116.1** (nixpkgs master build; jj 0.46.0 from the same rev for the gate run):

- Both modules parse (`use` exits 0). `jj-ci checks`, `jj-ci ci --verbose` and `jj-ci doctor` ran, and the `jj ci --stage ` completion gives the same result as on 0.115.1. `jj-ci push --dry-run` got as far as jj's own "No git remotes to push to" in a repo with no remote. This is a smoke test of one check in a scratch repo, not jj-ci's own suite. jj-ci states tested-with jj 0.45.1 and nushell 0.115.1 ([README](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/README.md)); jj 0.46.0 was not covered by that statement and ran fine in the smoke test.
- **ufda's completers are deprecated on 0.116.** `nu-complete ufda target` and `… attribute` take `[context: string, position: int]` ([completion/mod.nu L8, L24](https://github.com/renman-ymd/ufda/blob/ccc3a680a986745509545ca73669325c0b196d3b/completion/mod.nu#L8)). On 0.116.1 each completion prints `Positional completer input deprecated` ("this bridge will be removed in a future release"), though the result is still returned (`["flake.nix"]`). 0.115.1 prints no warning. The release notes list this under "Unified custom completions", a breaking change for completers ([0.116.0 notes](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/blog/2026-09-26-nushell_v0_116_0.md?plain=1#L85-L110)). jj-ci's own stage completer takes no parameters and gave no warning.
- **Side finding, outside this ticket:** the Home Manager carapace integration used in `modules/home.nix` generates the old `{|spans| … }` external completer (carapace-bin 1.7.3 in the locked nixpkgs). On 0.116.1 it also prints the deprecation warning and still returns completions (`'git chec' | commandline complete` gave `check-attr`, `check-ignore`, `check-mailmap`). Not a break today; worth watching when the lock moves to 0.116.x.

### Sources

- Home Manager at the locked rev `0b2f112`: [modules/programs/nushell.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/nushell.nix), [modules/programs/jujutsu.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/jujutsu.nix), [modules/programs/carapace.nix](https://github.com/nix-community/home-manager/blob/0b2f1129177f70c5f0f5d88bb53c49ca47d0bfc0/modules/programs/carapace.nix). Master `c58f54c`: [nushell.nix](https://github.com/nix-community/home-manager/blob/c58f54c733a7894d84fa2fdff26cc12088c4b78c/modules/programs/nushell.nix) (identical), [carapace.nix](https://github.com/nix-community/home-manager/blob/c58f54c733a7894d84fa2fdff26cc12088c4b78c/modules/programs/carapace.nix) (same lines).
- nix-darwin at the locked rev: [modules/users/default.nix](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/users/default.nix) (per-user profile uses `environment.pathsToLink`).
- Nushell book (`nushell.github.io` main `89d0ae07`, documents 0.116.0): [configuration.md](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/configuration.md), [modules/using_modules.md](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/modules/using_modules.md), [modules/creating_modules.md](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/book/modules/creating_modules.md), [commands/docs/path_self.md](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/commands/docs/path_self.md), release notes [0.116.0](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/blog/2026-09-26-nushell_v0_116_0.md) and [0.116.1](https://github.com/nushell/nushell.github.io/blob/89d0ae07a2d68b8ba624df7cca4379ea7dcd23ae/blog/2026-10-04-nushell_v0_116_1.md); [nushell tags](https://github.com/nushell/nushell/tags).
- jj-ci at `v1.0.0` (`3eadcde`): [mod.nu](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/mod.nu), [commands/install.nu](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/commands/install.nu), [commands/completions.nu](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/commands/completions.nu), [commands/doctor.nu](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/commands/doctor.nu), [lib/render.nu](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/lib/render.nu), [lib/runner.nu](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/lib/runner.nu), [README](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/README.md), [docs/install.md](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/docs/install.md), [docs/commands.md](https://github.com/renman-ymd/jj-ci/blob/3eadcde25857aa1722edd8f6a085365d84e8f0d9/docs/commands.md).
- ufda at `ccc3a68`: [mod.nu](https://github.com/renman-ymd/ufda/blob/ccc3a680a986745509545ca73669325c0b196d3b/mod.nu), [completion/mod.nu](https://github.com/renman-ymd/ufda/blob/ccc3a680a986745509545ca73669325c0b196d3b/completion/mod.nu), [flake/outputs.nu](https://github.com/renman-ymd/ufda/blob/ccc3a680a986745509545ca73669325c0b196d3b/flake/outputs.nu), [README](https://github.com/renman-ymd/ufda/blob/ccc3a680a986745509545ca73669325c0b196d3b/README.md).
- Local, not linkable: `~/Scripts/gh/` (README and four scripts; not a repository), `~/Scripts/JJHOOKS-DRIFT.md`, this repo's `flake.nix`, `flake.lock` and `modules/home.nix`.
- Local observations (commands in the sections above): `nix eval --raw github:NixOS/nixpkgs/<rev>#nushell.version` and `#jujutsu.version` for the five revs; `git ls-remote` for the branch and tag revs; `nix flake prefetch`; `nix build` of the scratch flake in `$S/flk` (`.#jj-ci`, `.#ufda`, `.#modules`, `.#jj-ci-completions`, `.#homeConfigurations.{test,files,autoload}.activationPackage`); `nix eval` of `environment.pathsToLink` from `.#darwinConfigurations.Renauds-MacBook-Air`; `hyperfine`; `script -q /dev/null nu -e …` for pty runs.
