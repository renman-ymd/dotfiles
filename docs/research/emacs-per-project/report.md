# Emacs with per-project add-ons: design report

Prepared 2026-10-31, revised 2026-11-01 after reading your nix-darwin repository and answering the questions in section 2.5. Terminal frames only, jj (non-colocated), Nushell, Nix.

**Labels used below.**
- **tested**: I ran it in a Linux sandbox (Emacs 31.1 `emacs-nox`, direnv 2.38.2, jj 0.46.0, Nushell 0.116.1, nixpkgs-unstable at rev `885ba4d`, 2026-10-30).
- **read**: I read the primary source or documentation, but did not run it.
- **I don't know**: I could not establish it. No guess is offered.

**Terminology.** This report says "base" for the Emacs configuration every machine gets. Your repository glossary (`CONTEXT.md`) calls it the **editor core**, because "base" is an avoided synonym for **shared host**; the ADR and the tickets use "editor core". It also adds **add-on** and **project server** to the glossary.

Nothing here was run on macOS, on Lix, or with your real configuration. As you asked, I assumed `nixpkgs-unstable` and checked versions there (rev `885ba4d`, 2026-10-30; your `flake.lock` pins `b6c98e9e` from 2026-09-22, which I could not evaluate, so these versions need re-checking against it): `emacs31-nox` 31.1, `emacs-macport` 30.2.50, `harper` 3.0.0, `wakatime-cli` 2.26.15, `nil` 2026-07-23, `clang-tools` 21.1.8, `nushell` 0.116.1, `jujutsu` 0.46.0 (attribute evaluation on `aarch64-darwin`; nothing was built for macOS).

---

## 1. Recommendation

Replace the single long-lived daemon with **one Emacs server per project**, started on demand inside the project's own direnv environment, with the untracked add-on environment composed on top.

- `em <file>` (Nushell) finds the project root (the nearest `.envrc`), computes a short server name from it, and either attaches to the running server or starts one with `direnv exec <root> … direnv exec <root>/.emacs-addon … emacs --daemon=<socket>`.
- The server inherits the environment of the process that started it, so every language server, compile command and shell it spawns sees the project's tools and the add-on's. No per-buffer environment code is needed.
- The add-on brings its Emacs packages and tree-sitter grammars through `EMACSLOADPATH` and `EMACSNATIVELOADPATH`, and its configuration through one file named in `EMACS_ADDON_INIT`. The base `init.el` loads that file if it exists. The base knows nothing else about projects.
- The jj commit window does not use a server: `emacs -nw -Q -l <one file>`, built-ins only.
- Trust is `direnv allow` on the add-on's `.envrc`, plus a content pin for the files direnv does **not** hash (`flake.nix`, `flake.lock`, `addon.el`). I found that gap by testing (section 3.5).

Every machine gets the same light base and the same workflow, the work machine included (your decision of 2026-11-01). C support is a switch for personal machines only; on the work machine, C comes from an add-on if it is ever needed.

What this costs you, stated up front: no buffers shared across projects, one extra Emacs process per open project, and the first `em` in a project waits for direnv (a cold Nix evaluation can be slow). What it removes: the loader, the Elisp trust code, buffer-local environments, `inheritenv`, per-workspace dir-locals tricks, the grammar-conflict problem, and (probably) the launchd agent and the re-signed binary.

---

## 2. What changed after your challenge

You asked whether I chose the single daemon because it fits the new workflow or because it is what you have now, and said that if it was the second, every decision resting on it must be challenged too.

**Answer: partly the second.** The reasons on the table for keeping a daemon were startup time and first-load time. Those figures (5–10 s warm start, 3–7 s first open) belong to the old configuration, which is being replaced. I carried the daemon over, together with its launchd agent, its re-signed binary and `em-restart`, without testing the premise against the new design. On environment mechanics alone, the per-project server is simpler and more robust, and I could reproduce that (sections 3 and 7).

### 2.1 Decisions that depended on the single daemon

| Decision | Before (single daemon) | After (server per project) | Evidence |
|---|---|---|---|
| Environment delivery | `envrc.el` buffer-local `process-environment`, plus `inheritenv` for temp buffers | `direnv exec` at launch; the whole process has the environment | tested |
| Second (Emacs-only) environment layer | Not supported by `envrc.el`: one env directory per buffer, no merge | Two `direnv exec` calls composed; add-on is a separate directory | tested (envrc.el limit: read in source) |
| Add-on Elisp | A loader, a dir-locals class attached to project roots | `EMACSLOADPATH` + `EMACS_ADDON_INIT`; no loader | tested |
| Trust | Content-hash allow implemented in Elisp, feeding `safe-local-variable-directories` | `direnv allow` + content pin in a direnv library file | tested |
| Dropping an add-on | Restart the whole daemon (`em-restart`) | Stop that project's server (`em-stop`) | tested (kill) |
| Where language packages live | A broad, lazy base (so a running daemon can load them later) | Base stays small; packages ride with the add-on | tested (add-on package activated with autoloads) |
| Tree-sitter grammars | One build per language per process; two projects with different builds conflict | Per process, so no conflict | read (cache in `treesit.c`) |
| jj workspace add-on lookup | `.dir-locals-2.el` in the primary workspace is invisible from sibling workspaces | Launcher follows the `.jj/repo` pointer to the primary workspace | tested |
| Daemon supervision | launchd agent, `wait4path` wrapper, re-signed copy of the binary | Started from your terminal by the launcher | **I don't know** (TCC, section 7) |
| Emacs build | `emacs-macport` 30.2.50 (kept from the GUI days; the GUI is broken for you and out of scope) | `emacs31-nox` 31.1, terminal-only | attribute exists on Darwin; **I don't know** if it runs for you |
| Commit window | A second tiny config directory ("emacs-light") | `-Q` plus one file; you already agreed to drop emacs-light | tested in batch; not interactively |
| Work machine editor | The light config for work, the full config elsewhere (map, tickets 11 and 17) | The same light base everywhere; C is a switch | your decision, 2026-11-01 |
| Supervision per platform | A launchd agent on the Air and a systemd user service on Linux (Home Manager is the only toolbox that declares both) | Nothing to supervise | read (ADR 0002, research 01 §2) |

### 2.2 What does not depend on the daemon, and stays

Terminal frames only. Nix and Nushell modes in the base on every machine; C (simpc-mode, clangd) behind a switch that is on for personal machines and off for the work machine; everything else as add-on content. Eglot on demand. Harper on demand, English only. The add-on is untracked through the global ignore. The `.wakatime-project` file for WakaTime. The Claude Code skill. The Ciznia-style gated module structure. Reading the nixpkgs pin from the project. The commit convention from your dotfiles `CLAUDE.md`.

### 2.3 What the single daemon still does better

- Buffers from different projects in one session, and opening a file from anywhere instantly.
- One process (RAM). Sandbox figures for a *minimal* Emacs 31: about 36 MB idle, 49 MB after loading Eglot, Project, Treesit, Flymake and friends. Your comfort bundle was not measured.
- A warm session without waiting for direnv.

Language-server warm-up (your biggest pain, 30 s to minutes) is probably **not** an advantage of the daemon: Eglot makes one connection per project root, so a daemon keeps a server warm only while it lives, which a project server does too. That is my inference from Eglot's design, not something I tested.

### 2.4 When the old model would win again

If the prototype numbers (section 9) show that the real base is slow to start on your Mac, or that you move between many projects in one sitting, a shared daemon with `envrc.el` is the fallback. It is not a rewrite: the base, the add-on flake and the pin work unchanged; only the launcher and the per-buffer environment code differ.

### 2.5 What your repository and your answers changed (2026-11-01)

Your answers:

| Your answer | Effect |
|---|---|
| The work machine uses the new workflow, with a server per project. C needing an add-on there is fine; the base is light by default | No separate light config for work (tickets 11 and 17 said otherwise). C becomes a switch, off on the work machine. Section 3.10 |
| In devenv projects you always put a `use flake` that exposes only `devenv` before the devenv lines; this could be automated later | The removal of `devenv` from the `dev` feature (ticket 06) does not affect this design. The skill treats that flake as part of the project. Automation is ticket 42. My earlier "I don't know" about `cachix/devenv-nixpkgs` as a flake input is settled: your Bootstrap flake already uses it as one |
| `glibtool`: you don't remember why it is there | Ticket 41 |

What I read in the repository (the first column says where):

| Source | Finding | Effect |
|---|---|---|
| ADR 0002, map | Features are `renman-ymd.<feature>.enable`; home modules use Home Manager options only | The feature is `editor`. The module sketch now follows it (section 6.6) |
| Ticket 05, ticket 32 | The Air's Nushell config dir is `~/Library/Application Support/nushell`; a static `.nu` file cannot carry store paths | The launcher goes through the shell feature's snippet mechanism, not `xdg.configFile` |
| Ticket 06, ticket 11 | `nil` is in `dev` core; `clang-tools` is in `dev.toolchains`, off on the work machine | Removed from the editor module. C on the work machine needs an add-on |
| `modules/home.nix` | Aliases `em`, `emg`, `eml`, `em-kill`, `em-restart`; `$EDITOR` and `$VISUAL` depend on the daemon and on the light config; zsh uses `emacs -nw -Q`; `jj` and `gh` also use the light config | Ticket 37 replaces them. Which command `$EDITOR` and `$VISUAL` become is open (ticket 35) |
| Ticket 16 | Lists the Emacs launchd agent and the re-signed Emacs | Shrinks if the macOS file-access (TCC) test passes (tickets 34, 39). nix-daemon, the app loop and pinentry-mac stay |
| Ticket 17 | Ports `PLAN.md` and `REVIEW.md`; the rewrite itself is out of scope | `PLAN.md` (GUI-first, heavy/light split, `lsp-mode`) is superseded by ADR 0004; the rewrite is ticket 36 |
| Tickets 30, 31 | Home Manager's `programs.claude-code` can own skills; ticket 31 is still open | The skill ships through the `claude` feature (ticket 38) |
| `modules/home.nix` ignore list | `.direnv` and `.dir-locals.el` are already ignored globally | `.emacs-addon/` and `.wakatime-project` join that list |
| `flake.lock`, `modules/home.nix` | nixpkgs is locked on 2026-09-22; nix-direnv is enabled; Lix comes from `pkgs.lix` on every machine, including work | Versions need re-checking; my tests used direnv's built-in `use flake`, not nix-direnv's; the Lix questions apply to every host |
| Map, ADR 0003 | WakaTime's key comes from agenix; the work machine has no personal secret | WakaTime must stay inert without a key (section 3.10) |

---

## 3. Design

### 3.1 Moving parts

| Part | Where it lives | Notes |
|---|---|---|
| Base Emacs + packages | Nix: the `editor` feature (`renman-ymd.editor.enable`), Home Manager options only | `emacs31-nox.pkgs.withPackages`; the stock wrapper keeps a pre-set `EMACSLOADPATH` (tested) |
| Base `init.el` | `~/.config/emacs/init.el` | Generic. Loads `EMACS_ADDON_INIT` if set (tested) |
| Project environment | The project's own `.envrc` (devenv or flake) | Untouched |
| Add-on | `<root>/.emacs-addon/{flake.nix,addon.el,.envrc}` | Untracked, ignored globally, disposable |
| Launcher | `launcher.nu`, sourced from Nushell config | Section 6.1 |
| Pin check | `~/.config/direnv/lib/emacs-addon.sh` | Section 6.2 |
| Commit window | `commit.el`, run with `-Q` | Section 6.5 |
| Skill | Claude Code `emacs-addon` | Appendix A |

### 3.2 Flow

```text
em <file>
 └─ find the nearest .envrc above the file          → project root R
     ├─ jj secondary workspace? add-on comes from the primary workspace
     │    (.jj/repo is a file holding a path relative to .jj/)
     ├─ server name = em-<first 10 hex of sha256(R)>
     │  socket      = ~/.local/state/emacs-servers/<name>    (directory mode 700)
     ├─ already running?  → emacsclient -s <socket> -nw <file>
     └─ otherwise:
         direnv exec R
           env -u DIRENV_DIFF -u DIRENV_DIR -u DIRENV_FILE -u DIRENV_WATCHES
             direnv exec R/.emacs-addon
               env SHELL=$SHELL  emacs --daemon=<socket>
```

Three details I learned the hard way, all **tested**:

1. The socket path must be absolute and the directory mode 700. Emacs refuses a 755 directory ("not a safe directory because it is accessible by others"). Dev shells rewrite `TMPDIR`, so a socket found through `TMPDIR` is not found by the client.
2. A nested `direnv exec` reverts the outer environment unless the `DIRENV_*` variables are removed in between (the `env -u` call).
3. Plain `use flake` rewrites `SHELL`; the launcher passes yours back explicitly. (nix-direnv restores some variables such as `TMPDIR` but not `SHELL`; that part is **read**.)

### 3.3 Add-on lifecycle

You ask Claude for an add-on; the skill (Appendix A) reads the project's toolchain and lock, writes three files, pins them, checks that the flake evaluates, and stops. You read the folder and run `direnv allow` yourself. I made that the default because the review is the gate: if the agent that wrote the code also allows it, the gate is gone. (This differs from my earlier draft, where the skill ran `direnv allow`; see section 8.)

The add-on flake has two nixpkgs inputs on purpose. The Emacs side (packages, grammars) must come from the same nixpkgs as your base Emacs, so bytecode, native code and grammar ABI match the binary. The tools side (language servers, adapters) comes from the project's pin, so they match the project's libc and toolchain. The first resolves through a registry entry that home-manager pins to your dotfiles' nixpkgs; the second is rewritten by the skill from `devenv.lock` or `flake.lock`. The registry mechanism for `nixpkgs` worked in the sandbox (upstream Nix); on Lix it is **I don't know**.

**devenv projects.** Your Bootstrap `.envrc` starts with `use flake ./nix`, a flake that exposes only `devenv`, then runs `devenv direnvrc` and `use devenv`. `ufda --with-devenv` writes the lines in that order for the same reason (its README: `use flake` comes first so the flake's `devenv` is on `PATH` when the hook runs). So nothing global has to provide `devenv`, and `direnv exec <root>` already brings the project's environment. The tools input of the add-on then uses the pin from `devenv.lock` or `nix/flake.lock`: `github:cachix/devenv-nixpkgs/<rev>`. That URL form is read, not evaluated; `rolling` as an input is read from your `nix/flake.nix`.

### 3.4 jj, ignores, workspaces

- Non-colocated jj has no `.git`, so a flake with a `path:` URL copies everything below it into the store. That is why your flakes live in `nix/` subfolders. The add-on flake is rooted at `.emacs-addon/` itself, so only that small folder is copied (tested).
- jj auto-tracks new files unless an ignore rule matches. Ignore sources (read, jj 0.46.0 `base_ignores`): `.gitignore` files, `core.excludesFile` if set else `$XDG_CONFIG_HOME/git/ignore`, and `<git dir>/info/exclude`. home-manager's `programs.git.ignores` is meant to write the second one; that it does so on your setup is **I don't know** until you run `jj file list` on a fresh add-on (section 9).
- The skill checks the result: `jj file list .emacs-addon` must print nothing (tested: empty output means untracked).
- A secondary workspace has `.jj/repo` as a **file** whose content is a path relative to `.jj/`. The launcher follows it to the primary workspace and uses that add-on (tested with a real workspace). Workspace names differ from directory names (your `pr-review` lives in `../review`), so the launcher never derives anything from the name.
- Each workspace directory gets its own server (its own `.envrc` root, its own hash). That matches `project.el`, which also treats each workspace as a project.

### 3.5 Trust

`direnv allow` records a hash of the `.envrc` **only**. I tested this: editing a file the `.envrc` watches changed what ran without any new allow, while editing the `.envrc` itself was blocked. `use flake` watches `flake.nix` the same way, so an edit to the add-on's `flake.nix` or `addon.el` would run without review. `addon.el` runs as Elisp inside your editor, and a flake can run arbitrary build steps.

The fix is a one-line pin in the add-on's `.envrc` (`emacs_addon_pin <hash>`), checked by a small function in your direnv library. If the files changed, direnv aborts with an error and the launcher starts nothing (tested end to end, including a tampered `addon.el`). Changing the pin means editing `.envrc`, which direnv blocks until you run `direnv allow` again. That reproduces the allow-by-hash behaviour you chose, now covering the files that matter.

Limits of the pin: it gates **starting** a server. A server already running keeps what it loaded. `source_env` must not be used for the add-on (the sourced file is not checked for allow; tested). A `direnv exec` against a blocked `.envrc` fails closed (tested).

### 3.6 Terminal-only UI: what replaces what

| Old | Now | Status |
|---|---|---|
| lsp-ui sideline | Eglot 1.24 (bundled in Emacs 31) `eglot-code-action-indications` with `margin` / `mode-line`; Flymake; ElDoc in the echo area | option exists (read); how it looks in your terminal: **I don't know** |
| lsp-ui sideline (the actual package) | `sideline` + `sideline-eglot` + `sideline-flymake` (MELPA, in nixpkgs) | TTY rendering: **I don't know** (the README does not say; it has `display-graphic-p` branches) |
| lsp-ui peek | `consult-xref` with preview | read (documented drop-in) |
| lsp-ui doc (child-frame hover) | Emacs 31 adds child frames on TTY frames (`tty-child-frames`), which could revive popups | NEWS read; no package verified on top of it: **I don't know** |
| dap-mode | `dape`, adapters from the add-on's environment, `dape-configs` in `addon.el`; GDB 14+ has a built-in DAP | breakpoint margin fallback exists (read); full TTY UI: **I don't know** |
| treemacs | treemacs, lazy; it has a documented terminal mode with simpler rendering | read |

### 3.7 Commit window

jj starts the editor with a temp file named `editor-XXXX.jjdescription` in the system temp directory (tested; read in jj source). So project-local files are not found by walking up from the buffer, and the buffer's `default-directory` is `/tmp`. The commit code therefore uses `command-line-default-directory` (the process's startup directory, which is where jj ran) to ask `jj log` for the areas in use.

What the file does (section 6.5): a tiny major mode, a ruler, a header-line hint that checks your `CLAUDE.md` rules (title is `area: summary`, no capitals except proper names, at most one body line), area completion from `jj log`, and `M-x my/commit-harper` to start Harper on demand. Harper's `SentenceCapitalization` lint is switched off because it contradicts lowercase `area:` titles. `jj log` for area completion was tested with jj 0.46.0. The interactive behaviour in a real terminal, and Harper's reaction to this configuration, are **I don't know**.

The ruler width is a placeholder (72): your `CLAUDE.md` does not give one.

### 3.8 WakaTime

Cause (read in `wakatime-cli` source): detection order is `.wakatime-project` file or project map, then `--project`, then VCS detectors for Git, Mercurial, Subversion and TFVC. There is no Jujutsu detector, and your repos are not colocated, so nothing is found. A one-line `.wakatime-project` at the root fixes it with data only and no Emacs code; add it to the global ignore (done in the module sketch). Each workspace needs its own file. The CLI flag names for a project override are **I don't know** (the usage text only says to run `--help`), so I did not rely on them. This is the clean fix you asked for, so WakaTime stays.

### 3.9 Emacs build

`emacs31-nox` is Emacs 31.1 with Eglot 1.24.31 bundled. On the 30.2.50 macport build, Eglot 1.24 needs newer `project`, `jsonrpc`, `eldoc`, `xref` and `flymake` from ELPA over the bundled ones, and I did not verify that this builds cleanly there. Emacs 31 also adds TTY child frames, `site-start.el` before early init, and `user-lisp`. Because the GUI is out of scope and the macport build exists mostly for it, I made 31-nox the default. Whether it builds and runs well on your Mac is **I don't know**; section 9 gives the two commands that settle it. Your repository currently uses `pkgs.emacs-macport` with `programs.emacs`; that goes away with the daemon.

### 3.10 Work machine

The work machine gets the same base and the same launcher (ticket 11 enables the `editor` feature there, with the C switch off). `dev` core, which has direnv and nix-direnv, is enabled there, so the launcher's dependencies are present. What this adds to the install and remove scripts (ticket 40):

- Servers keep running after the install. The remove script stops them (`em-stop` for each socket in the state directory) before `home-manager uninstall`.
- `~/.local/state/emacs-servers` is created by the launcher, not by Home Manager, so the remove script deletes it.
- Add-ons live in employer repositories as untracked folders. Once the global ignore goes with `home-manager uninstall`, they show up as untracked in `jj status` or `git status`. The remove script lists them; it does not delete them unasked.
- direnv's allow records stay in `$XDG_DATA_HOME/direnv/allow` (research 03 §6 lists it).
- The work machine has no WakaTime key (ADR 0003). **I don't know** how `wakatime-mode` behaves without one; the base must not start it when `~/.wakatime.cfg` or the key file is missing.
- No personal key or secret is involved anywhere in this design.

---

## 4. Existing approaches compared

| Approach | What it does | Fit for this goal |
|---|---|---|
| `envrc.el` (purcell) | Buffer-local `process-environment` and `exec-path` from direnv; many projects in one daemon | The closest match to the single-daemon design. Limits (read in source, reproduced): one env directory per buffer and no merge; temp buffers and non-advised APIs lose the environment (`inheritenv` needed); cached until `envrc-reload`; add-on Elisp is global and cannot be unloaded |
| `direnv.el` (wbolster) | Switches the **global** environment | Wrong for several projects at once (its sibling's README says so) |
| `buffer-env` (astoff, GNU ELPA) | Buffer-local environment from any script, with or without direnv | Same limits as `envrc.el`; no direnv trust |
| `mise.el` | `envrc.el` clone for mise | Not relevant to direnv + Nix |
| `direnv exec … emacs --daemon` / a dev-shell Emacs (this report) | The process gets the environment at start | Exact, simple, per project; costs RAM and cross-project buffers. nixpkgs ships a setup hook (`addToEmacsLoadPath`) for the dev-shell case (read) |
| `emacsWithPackages` (nixpkgs wrapper) | Wraps Emacs with `EMACSLOADPATH` / `EMACSNATIVELOADPATH` | Used for the base; it keeps a pre-set `EMACSLOADPATH` (tested). Cannot be copied together with a re-signed bare binary |
| `devenv.local.nix` / `devenv.local.yaml` | Untracked per-user overlay, imported automatically | Valid for devenv projects; a new input there changes `devenv.lock` (tracked). I did not use it because the add-on must work for flake projects too |
| twist.nix | Lock-file-based Emacs packaging | Alpha per its README; heavy for a minimal base |
| emacs-overlay | `emacsWithPackagesFromUsePackage` | Useful only to derive package lists from a config; adds a large overlay |
| nix-doom-emacs(-unstraightened) | Doom under Nix | A framework you are leaving; the older repo has had no commit since 2025-09-14 |

None of the frameworks offers per-project add-ons loaded from a dev shell; most Nix + Emacs users do this with `envrc.el` or `buffer-env` (my reading of the READMEs, not a survey).

---

## 5. Trade-offs: per-project server (B), shared daemon (A), plain process (C)

| | A: shared daemon | B: server per project | C: plain `emacs -nw` |
|---|---|---|---|
| Environment | Buffer-local; leaks to temp buffers unless advised | Whole process | Whole process |
| Add-on Elisp | Global, accumulates until restart | Per process, gone with the server | Per process |
| Second environment layer | Custom code (no merge in `envrc.el`) | Two `direnv exec` calls (tested) | Same as B |
| Trust | Custom Elisp code | `direnv allow` + pin | Same as B |
| RAM | One process | One per open project (sandbox: 36–49 MB for a minimal Emacs; **I don't know** for your bundle) | One per window |
| Start | Warm | First start per project; sandbox: bare Emacs 31 batch start about 50 ms, 213 ms with Eglot, Project, Treesit and Flymake required; `direnv exec … emacs --daemon` returned in about 116 ms. Your real base on your Mac: **I don't know** | Every time |
| Cross-project buffers | Yes | No | No |
| LSP warm-up | Once per project while the daemon lives | Once per project while its server lives | Every time |
| Commit window | Needs the daemon | Not needed (`-Q`) | Natural fit |

The sandbox is Linux, 2 vCPUs, Emacs 31.1 nox, `-Q` or an empty init: these are relative magnitudes, not your numbers.

---

## 6. Sketches

All files below were validated as stated in their headers. `{{...}}` markers do not appear in the code.

### 6.1 Launcher (Nushell) — tested against a real Emacs 31.1 server; `em` itself not tested (needs a terminal)

```nu
# Prototype launcher (sandbox test). Not production code.

# Nearest ancestor directory (including `from`) that contains `name`, or null.
def find-up [name: string, from: path]: nothing -> any {
  mut dir = ($from | path expand)
  loop {
    if ($dir | path join $name | path exists) { return $dir }
    let parent = ($dir | path dirname)
    if $parent == $dir { return null }
    $dir = $parent
  }
}

# A secondary jj workspace has `.jj/repo` as a FILE holding a path relative to `.jj`.
def primary-root [ws: path]: nothing -> path {
  let repo = ($ws | path join ".jj" "repo")
  if ($repo | path exists) and (($repo | path type) == "file") {
    $ws | path join ".jj" ($repo | open --raw | str trim) | path expand | path dirname | path dirname
  } else { $ws }
}

# Server name derived from the environment directory (stable, filesystem-safe).
def server-name [dir: path]: nothing -> string {
  $"em-(($dir | hash sha256) | str substring 0..9)"
}

# Absolute socket path: independent of TMPDIR, which dev shells may rewrite.
def socket-path [name: string]: nothing -> path {
  let dir = ($env.EM_SOCKET_DIR? | default ($env.HOME | path join ".local" "state" "emacs-servers"))
  mkdir $dir
  ^chmod 700 $dir
  $dir | path join $name
}

def em-up [sock: path]: nothing -> bool {
  (^emacsclient -s $sock -e t | complete | get exit_code) == 0
}

# Start (if needed) the per-project server inside the composed environment.
def em-start [dir?: path] {
  let root = (find-up ".envrc" ($dir | default "."))
  if $root == null { error make { msg: "no .envrc above here" } }
  let name = (server-name $root)
  let sock = (socket-path $name)
  if (em-up $sock) { return { name: $name, sock: $sock, root: $root, started: false } }
  let addon_here = ($root | path join ".emacs-addon")
  let addon = if ($addon_here | path exists) { $addon_here } else { (primary-root $root) | path join ".emacs-addon" }
  if ($addon | path exists) {
    # project env first (fails closed if its .envrc is blocked), then strip direnv's bookkeeping, then the add-on env
    ^direnv exec $root env -u DIRENV_DIFF -u DIRENV_DIR -u DIRENV_FILE -u DIRENV_WATCHES direnv exec $addon env $"SHELL=($env.SHELL)" emacs $"--daemon=($sock)"
  } else {
    ^direnv exec $root emacs $"--daemon=($sock)"
  }
  { name: $name, sock: $sock, root: $root, started: true }
}

# Print the pin for an add-on directory: sha256 over "name\ncontent" of each
# existing file, in this order. Must match emacs_addon_pin in emacs-addon.sh.
def em-pin [dir?: path]: nothing -> string {
  cd ($dir | default ".")
  ["flake.nix" "flake.lock" "addon.el"]
  | where {|f| $f | path exists }
  | each {|f| $"($f)\n" + (open --raw $f) }
  | str join
  | hash sha256
}

# Stop the server of the project that contains dir.
def em-stop [dir?: path] {
  let root = (find-up ".envrc" ($dir | default "."))
  if $root == null { error make { msg: "no .envrc above here" } }
  ^emacsclient -s (socket-path (server-name $root)) -e "(kill-emacs)" | ignore
}

# NOT TESTED (needs a terminal): start the project server if needed, then attach.
def em [...files: path] {
  let r = (em-start)
  ^emacsclient -s $r.sock -nw ...$files
}
```

### 6.2 direnv library: the pin — tested

```bash
# ~/.config/direnv/lib/emacs-addon.sh   (loaded by direnv, so bash, not Nushell)
# emacs_addon_pin SHA256: refuse to load unless flake.nix, flake.lock and
# addon.el still hash to SHA256.  `direnv allow` only covers .envrc itself.
_emacs_addon_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1
}
emacs_addon_pin() {
  local want=$1 got f
  local files=(flake.nix flake.lock addon.el)
  for f in "${files[@]}"; do [ -e "$f" ] && watch_file "$f"; done
  got=$(for f in "${files[@]}"; do [ -e "$f" ] && { printf '%s\n' "$f"; cat "$f"; }; done | _emacs_addon_sha256)
  if [ "$got" != "$want" ]; then
    log_error "emacs-addon: files changed since pinned (now $got). Review them, then put this hash in .envrc"
    exit 1
  fi
}
```

This file is read by direnv, so it is bash, not Nushell. The `shasum` branch exists for macOS; I ran it in the sandbox only.

### 6.3 Add-on flake — tested on x86_64-linux (builds, dev shell sets the variables); evaluation for `aarch64-darwin` was not repeated after the last edit

```nix
{
  description = "Emacs add-on for this project (generated, not tracked)";

  inputs = {
    # Emacs-side packages must match the Emacs binary: use the registry entry
    # that home-manager pins to the dotfiles' nixpkgs.
    emacs-nixpkgs.url = "nixpkgs";
    # Tools (LSP servers, debuggers) must match the project: the skill replaces
    # this URL with the owner/repo/rev found in the project's lock file.
    project-nixpkgs.url = "nixpkgs";
  };

  outputs = { self, emacs-nixpkgs, project-nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAll = f: emacs-nixpkgs.lib.genAttrs systems f;
    in {
      devShells = forAll (system:
        let
          epkgs = emacs-nixpkgs.legacyPackages.${system}.emacs31-nox.pkgs;
          tools = project-nixpkgs.legacyPackages.${system};

          # --- the part the skill edits --------------------------------------
          elisp    = _: [ ];                                  # extra Emacs packages
          grammars = g: [ g.tree-sitter-rust ];               # tree-sitter grammars
          packages = [ tools.rust-analyzer ];                 # LSP, debugger, ...
          # -------------------------------------------------------------------

          lisp = emacs-nixpkgs.legacyPackages.${system}.buildEnv {
            name = "addon-elisp";
            paths = elisp epkgs;
            pathsToLink = [ "/share/emacs" ];
            # keep the directories present even when elisp is empty
            postBuild = "mkdir -p $out/share/emacs/site-lisp $out/share/emacs/native-lisp";
          };
          gram = epkgs.treesit-grammars.with-grammars grammars;
        in {
          default = emacs-nixpkgs.legacyPackages.${system}.mkShell {
            inherit packages;
            shellHook = ''
              export EMACSLOADPATH="${lisp}/share/emacs/site-lisp:''${EMACSLOADPATH-}"
              export EMACSNATIVELOADPATH="${lisp}/share/emacs/native-lisp:''${EMACSNATIVELOADPATH-}"
              export EMACS_ADDON_TREESIT_DIR="${gram}/lib"
              export EMACS_ADDON_INIT="$PWD/addon.el"
            '';
          };
        });
    };
}
```

`addon.el` and `.envrc` for the same project. The `.envrc` hash is printed by `em-pin .emacs-addon`; the end-to-end run opened a `.rs` file in `rust-ts-mode` with the grammar loaded, found `rust-analyzer`, and showed the project's own variable:

```elisp
;;; addon.el --- Rust add-on (generated)  -*- lexical-binding: t; -*-
(add-to-list 'major-mode-remap-alist '(rust-mode . rust-ts-mode))
(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))
;; eglot-server-programs already knows rust-analyzer; start it with M-x eglot.
```

```text
emacs_addon_pin 6900bbe00e95343bdc5a3611ee96911a6b21a935662f283d501d399a8642d958   # example hash
use flake "path:$PWD" --no-write-lock-file
```

`--no-write-lock-file` exists in upstream Nix; on Lix 2.95.4 it is **I don't know**.

### 6.4 Base `init.el` — tested

```elisp
;;; init.el --- base stub  -*- lexical-binding: t; -*-
;; The base is generic.  A per-project add-on arrives through the environment
;; of the server process, so nothing here knows about any project.
(setq treesit-auto-install-grammar 'never) ; never wait on a prompt in a daemon
(when-let* ((d (getenv "EMACS_ADDON_TREESIT_DIR")) ((file-directory-p d)))
  (add-to-list 'treesit-extra-load-path d))
(defvar my/addon-loaded nil)
(when-let* ((f (getenv "EMACS_ADDON_INIT")) ((file-readable-p f)))
  (load f nil t)
  (setq my/addon-loaded t))
```

An earlier run of mine with a base that lacked the grammar line hung `emacsclient` on `find-file` of a `.rs` file. I did not isolate the cause; `treesit-auto-install-grammar` set to `never` is a precaution against a prompt that nobody can answer in a daemon. **I don't know** that this was the cause.

C support in the base (from Eglot's language-id rule, read; not run):

```elisp
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((simpc-mode :language-id "c") . ("clangd"))))
```

### 6.5 Commit window — byte-compiles without warnings; functions run in batch; not run interactively

```elisp
;;; commit.el --- jj description buffer  -*- lexical-binding: t; -*-
;; Always-on, tiny.  Needs only built-in libraries.
(require 'cl-lib)
(require 'subr-x)

(defvar my/commit-ruler 72
  "Column of the ruler.  Placeholder: the dotfiles CLAUDE.md gives no width.")

;; jj starts the editor with its own working directory, but the temp
;; file lives in the system temp dir, so ask for the startup directory.
(defun my/jj-areas ()
  "Areas already used in recent jj titles, most frequent first."
  (let ((default-directory command-line-default-directory)
        (case-fold-search nil)
        (counts (make-hash-table :test #'equal))
        areas)
    (with-temp-buffer
      ;; (t nil): stdout into this buffer, stderr discarded.
      (ignore-errors
        (call-process "jj" nil (list t nil) nil
                      "log" "--no-graph" "-r" "ancestors(@, 300)"
                      "-T" "description.first_line() ++ \"\\n\""))
      (goto-char (point-min))
      (while (re-search-forward "^\\([a-z0-9._-]+\\): " nil t)
        (cl-incf (gethash (match-string 1) counts 0))))
    (maphash (lambda (k v) (push (cons k v) areas)) counts)
    (mapcar #'car (sort areas (lambda (a b) (> (cdr a) (cdr b)))))))

(defun my/jj-area-capf ()
  "Complete the area on line 1, before the first colon."
  (when (and (= (line-number-at-pos) 1)
             (not (string-search ":" (buffer-substring (line-beginning-position) (point)))))
    (list (line-beginning-position) (point)
          (completion-table-dynamic (lambda (_) (my/jj-areas)))
          :exclusive 'no)))

(defun my/commit-hint ()
  "Header-line text: checks the title and body against the commit rules."
  (save-excursion
    (goto-char (point-min))
    (let* ((title (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
           (body 0) (past-blank nil) (problems nil))
      (forward-line 1)
      (while (not (eobp))
        (let ((l (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
          (cond ((string-prefix-p "JJ:" l))
                ((string-empty-p l) (setq past-blank t))
                (past-blank (cl-incf body))))
        (forward-line 1))
      (unless (string-match-p "\\`[a-z0-9._-]+: ." title)
        (push "title is not `area: summary`" problems))
      (when (let ((case-fold-search nil)) (string-match-p "[A-Z]" title))
        (push "capitals in title (proper names only)" problems))
      (when (> (length title) my/commit-ruler)
        (push (format "title is %d chars" (length title)) problems))
      (when (> body 1) (push (format "%d body lines (max 1)" body) problems))
      (if problems
          (propertize (string-join (nreverse problems) " | ") 'face 'warning)
        (propertize "ok" 'face 'success)))))

(define-derived-mode my/jjdesc-mode text-mode "jj-desc"
  "Major mode for jj description buffers."
  (setq-local fill-column my/commit-ruler)
  (display-fill-column-indicator-mode 1)
  (font-lock-add-keywords nil '(("^JJ:.*$" 0 'font-lock-comment-face t)))
  (add-hook 'completion-at-point-functions #'my/jj-area-capf nil t)
  (setq-local header-line-format '(:eval (my/commit-hint))))

(add-to-list 'auto-mode-alist '("\\.jjdescription\\'" . my/jjdesc-mode))

;; Harper on demand: M-x my/commit-harper.
(defvar eglot-server-programs)
(defvar eglot-workspace-configuration)
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((my/jjdesc-mode :language-id "jjdescription") . ("harper-ls" "--stdio")))
  (setq-default eglot-workspace-configuration
                '(:harper-ls (:linters (:SentenceCapitalization :json-false)))))
(defun my/commit-harper () (interactive) (call-interactively #'eglot))
;;; commit.el ends here
```

The jj setting that uses it takes an argument array and appends the temp file (tested with jj 0.46.0). In the module it becomes `[ "${base}/bin/emacs" "-nw" "-Q" "-l" "${commitEl}" ]`, an absolute store path, no `~`.

### 6.6 Home Manager module — parses; not built, not evaluated

```nix
# modules/home/editor/default.nix  (sketch; Home Manager options only, no osConfig)
{ config, lib, pkgs, ... }:
let
  cfg = config.renman-ymd.editor;
  emacs = pkgs.emacs31-nox;                       # terminal-only; confirmed by ticket 34

  simpc = emacs.pkgs.trivialBuild {
    pname = "simpc-mode";
    version = "unstable";
    src = pkgs.fetchFromGitHub {
      owner = "rexim";
      repo = "simpc-mode";
      rev = cfg.simpcRev;                         # pin it: not in nixpkgs
      hash = lib.fakeHash;                        # replace after the first build
    };
  };

  # Light by default: the same base on every machine. Language packages belong in add-ons.
  base = emacs.pkgs.withPackages (e:
    [ e.vertico e.consult e.marginalia e.orderless e.corfu   # placeholder: use the list from PLAN.md
      e.nix-mode e.nushell-mode ]
    ++ lib.optional cfg.c.enable simpc);

  commitEl = ./commit.el;                         # tiny, built-ins only, loaded with -Q
in
{
  options.renman-ymd.editor = {
    enable = lib.mkEnableOption "Emacs base";
    # Sub-switch in the style of cli.full and dev.toolchains; its name is settled in ticket 35.
    c.enable = lib.mkEnableOption "C support in the base (simpc-mode and clangd entry)";
    simpcRev = lib.mkOption { type = lib.types.str; description = "simpc-mode commit"; };
  };

  config = lib.mkIf cfg.enable {
    # nil comes from dev core and clang-tools from dev.toolchains, so they are not listed here.
    home.packages = [ base pkgs.harper pkgs.wakatime-cli ];

    xdg.configFile."emacs/init.el".source = ./init.el;
    xdg.configFile."direnv/lib/emacs-addon.sh".source = ./emacs-addon.sh;

    # The launcher is a static Nushell snippet (no store paths), so it can go through the shell
    # feature's snippet mechanism from ticket 05. programs.nushell.extraConfig is a stand-in.
    programs.nushell.extraConfig = builtins.readFile ./launcher.nu;

    # Reaches jj through $XDG_CONFIG_HOME/git/ignore (report, section 3.4). Extend the
    # existing list in home.nix, next to ".direnv".
    programs.git.ignores = [ ".emacs-addon/" ".wakatime-project" ];

    # Commit window: no server, no init file, built-ins only.
    programs.jujutsu.settings.ui.editor =
      [ "${base}/bin/emacs" "-nw" "-Q" "-l" "${commitEl}" ];
  };

  # The C switch is on in shared-personal and off in the work-machine host (ticket 11).
}
```

This follows ADR 0002 (feature `editor`, option `renman-ymd.editor.enable`, Home Manager options only). `nil` and `clang-tools` are left to `dev`. The C switch is `editor.c.enable`; its name is settled in ticket 35. Placeholders: the package list (take it from your `PLAN.md`), the `simpc-mode` revision and hash, and the snippet mechanism (ticket 05). Attributes `trivialBuild`, `withPackages`, `vertico`, `nushell-mode`, `treesit-grammars` exist in the `emacs31-nox` package set on `aarch64-darwin` (evaluated). `jjdescription` also exists as a package there; I used my own 10-line mode instead because it needs no dependency under `-Q`.

---

## 7. Verified and not verified

| Claim | Status |
|---|---|
| A daemon started with `direnv exec` gives all its subprocesses the project environment; the client's environment is not propagated | tested; manual + `server.el` read |
| Add-on packages laid out as `site-lisp/elpa/<pkg>/…` on `EMACSLOADPATH` are activated with autoloads before `init.el` | tested (needs a daemon or interactive start with an init file; `--batch` does not activate) |
| The directory must be named `site-lisp` for that activation; `lisp` gives `require` but no autoloads | tested |
| `EMACSLOADPATH` needs the trailing colon, or the default path is lost | tested |
| The stock `emacsWithPackages` wrapper keeps a pre-set `EMACSLOADPATH`: wrapper base first, add-on next, defaults after | tested (load-path order); activation of the add-on package through the stock wrapper not repeated |
| A thin wrapper around a separate base bundle merges correctly (add-on, base, defaults) and the add-on native-comp path appears in `native-comp-eln-load-path` | tested |
| Nix grammar loads through `treesit-extra-load-path` set from `EMACS_ADDON_TREESIT_DIR` | tested (`nix`, `rust`) |
| Composition of two `direnv exec` calls works; blocked `.envrc` fails closed | tested |
| `direnv allow` covers only `.envrc` | tested |
| The pin check refuses changed files and the launcher starts nothing | tested |
| Server reuse on the second call; absolute socket path; directory mode 700 required | tested |
| jj: ignored add-on is untracked; workspace pointer resolution | tested (jj 0.46.0) |
| `jj log` template for areas; `ui.editor` as an array; temp file suffix `.jjdescription` | tested |
| Harper config shape (`:harper-ls (:linters (:SentenceCapitalization :json-false))`), supported language id `jjdescription` | read (Harper docs); not run against `harper-ls` |
| `.wakatime-project` detection | read (`wakatime-cli` source); not run |
| `cachix/devenv-nixpkgs` is a flake (Bootstrap uses `rolling` as an input and reads `legacyPackages`) | read (`Bootstrap/nix/flake.nix`) |
| Bootstrap `.envrc`: `use flake ./nix` (devenv only) before `use devenv`; `ufda --with-devenv` writes them in that order | read (`Bootstrap/.envrc`, ufda README) |

**I don't know** list (each is decision-relevant):

1. Real start time and memory of your base on your Mac (macOS, Apple silicon, your comfort bundle).
2. Language-server warm-up per project server on your projects.
3. Whether a shell-started daemon gets file-access permission (TCC) on macOS without the re-signed binary, and whether home-manager's `/bin/sh … wait4path` wrapper changes which process macOS holds responsible.
4. Whether `emacs31-nox` builds and runs well in your terminal on Darwin.
5. Native-comp `.eln` validity with a re-signed copy of the binary (relevant only if you keep it).
6. Lix 2.95.4: `--no-write-lock-file`, registry resolution of `nixpkgs` as a flake input, `nix develop` behaviour; and the work laptop's Nix flavour and version.
7. Whether pinning `github:cachix/devenv-nixpkgs/<rev>` evaluates (the repository is a flake, read from your Bootstrap; the rev form is not evaluated).
8. Whether `programs.git.ignores` reaches jj on your setup.
9. How sideline, flymake-popon, eldoc-box and dape look on a terminal; `consult-eglot` features (README not fetched).
10. Harper's behaviour on jj descriptions with this configuration; WakaTime CLI flag names.
11. Idle shutdown of servers (not tested; no policy proposed).
12. The grammar ABI that Emacs 31.1 expects versus `tree-sitter-grammars` in your nixpkgs (it worked in the sandbox on Linux).
13. Whether Eglot 1.24 on the macport 30.2.50 build builds cleanly (relevant only if you keep macport).
14. How the pin and `--no-write-lock-file` behave under nix-direnv's `use flake` (enabled on your machines); my tests used direnv's built-in one.
15. Which versions your locked nixpkgs (`b6c98e9e`, 2026-09-22) has for `emacs31-nox`, `harper`, `wakatime-cli` and `jujutsu`; I could not evaluate that rev from the sandbox.
16. How `wakatime-mode` behaves when no key exists (work machine).
14. Whether `trusted-content`-style prompts appear for add-on Elisp in Emacs 31 (not tested; NEWS.31 has no dir-locals change).

---

## 8. Decisions

### 8.1 Settled (2026-11-01)

1. A server per project on every machine, the work machine included. The base is light by default; no second light config.
2. C support is a switch: on for personal machines, off on the work machine, where an add-on provides it if ever needed.
3. devenv projects need nothing global: the project's own `use flake` exposes `devenv`.
4. `glibtool` is deferred to ticket 41.
5. ADR 0004 records the decision; tickets 34 to 42 carry the work, in the `multi-machine` effort.

### 8.2 Still open (ticket 35 grills them; my default in brackets)

1. **Emacs 31 `nox` instead of macport 30.2.50** [yes, once ticket 34 confirms it builds and runs].
2. **Outside any project** (no `.envrc` above the file) [one base-only server; not implemented].
3. **Idle shutdown** [none; `em-stop`].
4. **Does the skill run `direnv allow`?** [no; you review the folder first].
5. **Pin scope** [`flake.nix`, `flake.lock`, `addon.el`].
6. **Commit window** [plain process with `-Q`, not the project's server].
7. **Ruler width** [72, a placeholder; your `CLAUDE.md` has none].
8. **Markdown, YAML, TOML in the base** [not configured; built-in modes remain].
9. **Nix and Nushell modes on the work machine** [kept].
10. **launchd agent and re-signed Emacs** [drop them if the TCC test passes; ticket 39].
11. **A `--bare` option** that skips the project environment [not provided].
12. **Acceptable first-start time** for `em` in a project, and for later ones. This decides whether the shared daemon comes back (section 2.4).
13. **`$EDITOR`, `$VISUAL` and the aliases** `em`, `emg`, `eml`, `em-kill`, `em-restart` [`emg` goes; `em-kill` and `em-restart` become `em-stop`; the rest open].
14. **Name of the C switch** [`editor.c.enable`].
15. **WakaTime on the work machine** [off, since there is no key].

---

## 9. Prototype checklist (run on your Mac; Nushell)

Run these in order. Each answers one entry of the "I don't know" list.

```nu
# 0. Versions and flags (answers 6)
nix --version
nix registry list | lines | where $it =~ "nixpkgs"
nix develop --help | lines | where $it =~ "no-write-lock-file"

# 1. Does emacs31-nox build and start in a terminal? (answer 4)
nix build nixpkgs#emacs31-nox --no-link --print-out-paths
# then run the printed path's bin/emacs -nw -Q and look at the screen

# 2. Real start time and memory of your base, once the module exists (answer 1)
mkdir /tmp/em-bench; ^chmod 700 /tmp/em-bench
let sock = "/tmp/em-bench/s"
let t = (timeit { ^emacs $"--daemon=($sock)" })
print $t
let pid = (^emacsclient -s $sock -e "(emacs-pid)" | into int)
^ps -o rss= -p $pid          # kilobytes
^emacsclient -s $sock -e "(native-comp-available-p)"

# 3. File-access permission for a shell-started daemon (answer 3)
^emacsclient -s $sock -e '(directory-files "~/Documents")'
# macOS shows a prompt, or the call fails with a permission error, or it works
^emacsclient -s $sock -e "(kill-emacs)"

# 4. Ignore reaches jj (answer 8): in a repo, after the module is active
mkdir .emacs-addon; "x" | save .emacs-addon/probe
^jj file list .emacs-addon       # empty output = ignored
rm -r .emacs-addon

# 5. Nushell side of the pin: compare with the direnv side
source ~/.config/nushell/emacs.nu     # path depends on ticket 05; on the Air the config dir differs
em-pin .emacs-addon

# 6. Under nix-direnv (answer 14): in a scratch project with an add-on and its pin
direnv allow .emacs-addon
direnv exec . true                 # must load without error
"# change" | save --append .emacs-addon/addon.el
direnv exec . true                 # must refuse: files changed since pinned

# 7. Versions in your locked nixpkgs (answer 15)
let sys = (nix eval --raw --impure --expr "builtins.currentSystem")
nix eval --raw $"github:NixOS/nixpkgs/b6c98e9e6633ee64753b594ff4a5febf0367fc00#legacyPackages.($sys).emacs31-nox.version"
```

For language-server warm-up (answer 2) there is no clean script: open a real file in a project, run `M-x eglot`, and note the time until the "initialized" message. Do this once on a project with a large language server, once on a small one.

---

## Appendix A. Draft Claude Code skill: `emacs-addon`

````markdown
---
name: emacs-addon
description: Create or update the untracked per-project Emacs add-on (.emacs-addon/) with LSP servers, tree-sitter grammars and Emacs packages for a project's toolchain. Use when the user wants Emacs support for a project, or asks to refresh it after the toolchain changed.
---

# Emacs add-on for a project

The add-on is a small Nix flake plus one Elisp file, kept in `.emacs-addon/` at the
project root. It is never tracked, never committed, and disposable: delete the folder
and the project is back to the plain base Emacs. The launcher (`em`) starts one Emacs
server per project inside the project's direnv environment and then the add-on's.

## Rules

- Never edit a tracked file. Never touch the project's `.envrc`, `devenv.*` or `flake.*`.
- Never run `direnv allow`. The user runs it after reading the diff; that review is the trust gate.
- Never commit anything, never `jj` anything beyond read-only commands.
- Put only editor-side things in the add-on (language server, debug adapter, grammar,
  Emacs package, mode wiring). The project's own build tools stay in the project's environment.
- Write nothing that holds a secret.

## Steps

1. Find the project root: the directory holding the project's `.envrc` (walk up from the
   current directory). In a jj secondary workspace, `.jj/repo` is a file holding a path
   relative to `.jj/`; the add-on belongs to the primary workspace the path leads to,
   and the workspace uses it automatically.
2. Check the add-on is untracked and ignored. Run `jj file list .emacs-addon` at the root:
   the output must be empty. Run `jj status` afterwards: it must not list `.emacs-addon`.
   If either fails, stop and tell the user (the global ignore is missing); do not edit
   `.gitignore` to work around it.
3. Read the toolchain: `devenv.nix`, `devenv.yaml`, `flake.nix` (also `nix/flake.nix`) and
   the lock files. Decide which language servers, debug adapters and grammars the project
   needs. If the project already provides the server, do not add it twice.
   In a devenv project the project's `.envrc` already starts with `use flake <dir>`, a flake
   that exposes only `devenv`; nothing global provides devenv, so do not add it to the add-on.
4. Read the project's nixpkgs pin from `devenv.lock` or `flake.lock`: the node named
   `nixpkgs`, its `locked` fields (`type`, `owner`, `repo`, `rev`). Use them in the
   `project-nixpkgs` input of the add-on flake. If `owner/repo` is not `NixOS/nixpkgs`,
   run `nix flake metadata <url>`; if that fails, ask the user instead of guessing.
   For a devenv project the node is `cachix/devenv-nixpkgs`, which is a flake (the project's own
   bootstrap flake uses it as an input), so the URL is `github:cachix/devenv-nixpkgs/<rev>`.
5. Copy the flake from the Template section below and edit only the three lines
   between the `the part the skill edits` markers: `elisp`, `grammars`, `packages`.
   Use grammar names from `tree-sitter-grammars` (for example `g.tree-sitter-rust`).
   Do not add inputs other than the two in the template.
6. Write `.emacs-addon/addon.el`: mode wiring only (`major-mode-remap-alist`, `auto-mode-alist`,
   `eglot-server-programs` or `dape-configs` entries). Eglot starts on demand (`M-x eglot`);
   do not add `eglot-ensure` hooks unless the user asked.
7. Pin the files. In `.emacs-addon`, compute the hash with
   `nu -c 'source ~/.config/nushell/emacs.nu; em-pin .'` and write `.envrc` as:

   ```
   emacs_addon_pin <hash>
   use flake "path:$PWD" --no-write-lock-file
   ```

   Re-compute the hash after every later edit of `flake.nix`, `flake.lock` or `addon.el`.
8. Check without running anything: from `.emacs-addon`, `nix eval --raw .#devShells.<system>.default.drvPath --no-write-lock-file`
   for the current system. Report any error verbatim.
9. If the project root has no `.wakatime-project`, write one line there with the project name
   (the primary workspace's directory name). It must be ignored; if `jj status` lists it, remove it.
10. Stop and tell the user, in two lines: what the add-on contains, and that they should read
    `.emacs-addon/` and run `direnv allow .emacs-addon`. Mention that an already running server
    keeps its old environment until `em-stop` and the next `em`.

## Updating

Re-read the toolchain, change only what changed, re-run steps 7, 8 and 10. If the toolchain
no longer needs anything from the add-on, offer to delete `.emacs-addon/` instead.

## Template: .emacs-addon/flake.nix

```nix
{
  description = "Emacs add-on for this project (generated, not tracked)";

  inputs = {
    # Emacs-side packages must match the Emacs binary: use the registry entry
    # that home-manager pins to the dotfiles' nixpkgs.
    emacs-nixpkgs.url = "nixpkgs";
    # Tools (LSP servers, debuggers) must match the project: the skill replaces
    # this URL with the owner/repo/rev found in the project's lock file.
    project-nixpkgs.url = "nixpkgs";
  };

  outputs = { self, emacs-nixpkgs, project-nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAll = f: emacs-nixpkgs.lib.genAttrs systems f;
    in {
      devShells = forAll (system:
        let
          epkgs = emacs-nixpkgs.legacyPackages.${system}.emacs31-nox.pkgs;
          tools = project-nixpkgs.legacyPackages.${system};

          # --- the part the skill edits --------------------------------------
          elisp    = _: [ ];                                  # extra Emacs packages
          grammars = g: [ g.tree-sitter-rust ];               # tree-sitter grammars
          packages = [ tools.rust-analyzer ];                 # LSP, debugger, ...
          # -------------------------------------------------------------------

          lisp = emacs-nixpkgs.legacyPackages.${system}.buildEnv {
            name = "addon-elisp";
            paths = elisp epkgs;
            pathsToLink = [ "/share/emacs" ];
            # keep the directories present even when elisp is empty
            postBuild = "mkdir -p $out/share/emacs/site-lisp $out/share/emacs/native-lisp";
          };
          gram = epkgs.treesit-grammars.with-grammars grammars;
        in {
          default = emacs-nixpkgs.legacyPackages.${system}.mkShell {
            inherit packages;
            shellHook = ''
              export EMACSLOADPATH="${lisp}/share/emacs/site-lisp:''${EMACSLOADPATH-}"
              export EMACSNATIVELOADPATH="${lisp}/share/emacs/native-lisp:''${EMACSNATIVELOADPATH-}"
              export EMACS_ADDON_TREESIT_DIR="${gram}/lib"
              export EMACS_ADDON_INIT="$PWD/addon.el"
            '';
          };
        });
    };
}
```

## Example: .emacs-addon/addon.el (Rust)

```elisp
;;; addon.el --- Rust add-on (generated)  -*- lexical-binding: t; -*-
(add-to-list 'major-mode-remap-alist '(rust-mode . rust-ts-mode))
(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))
;; eglot-server-programs already knows rust-analyzer; start it with M-x eglot.
```
````

Differences from your earlier brief: it never runs `direnv allow` (decision 5), and it pins the files (section 3.5).

---

## Appendix B. Sources

- Emacs manual and source at tags `emacs-30.2` and `emacs-31.1` (`cmdargs.texi`, `misc.texi`, `server.el`, `lread.c`, `files.el`, `treesit.c`, `package.el`, `etc/NEWS`, `etc/NEWS.30`, `etc/NEWS.31`): https://github.com/emacs-mirror/emacs
- envrc.el: https://github.com/purcell/envrc · inheritenv: https://github.com/purcell/inheritenv · buffer-env: https://github.com/astoff/buffer-env · direnv.el: https://github.com/wbolster/emacs-direnv
- direnv manual and stdlib: https://github.com/direnv/direnv (`man/direnv.1.md`, `man/direnv-stdlib.1.md`) · nix-direnv: https://github.com/nix-community/nix-direnv
- nixpkgs Emacs wrapper and setup hook: https://github.com/NixOS/nixpkgs/tree/nixpkgs-unstable/pkgs/applications/editors/emacs/build-support
- devenv (local overlay files, out-of-tree devenvs): https://github.com/cachix/devenv
- home-manager (`launchd`, `programs.emacs`): https://github.com/nix-community/home-manager · nix-darwin: https://github.com/nix-darwin/nix-darwin
- jj 0.46.0 (`cli/src/cli_util.rs`, `lib/src/workspace.rs`, `docs/working-copy.md`, `cli/src/description_util.rs`): https://github.com/jj-vcs/jj
- Eglot NEWS, `dape` README (https://github.com/svaante/dape), treemacs README (https://github.com/Alexander-Miller/treemacs), consult README (https://github.com/minad/consult), sideline (https://github.com/emacs-sideline/sideline), vc-jj (GNU ELPA)
- Harper: https://writewithharper.com/docs/integrations/emacs and https://writewithharper.com/docs/integrations/language-server
- WakaTime: https://github.com/wakatime/wakatime-cli (`pkg/project`), https://github.com/wakatime/wakatime-mode
- simpc-mode: https://github.com/rexim/simpc-mode
- twist.nix https://github.com/emacs-twist/twist.nix · emacs-overlay https://github.com/nix-community/emacs-overlay · nix-doom-emacs-unstraightened https://github.com/marienz/nix-doom-emacs-unstraightened · nix-doom-emacs https://github.com/nix-community/nix-doom-emacs
- Your dotfiles (branch `emacs-config-rewrite`, `PLAN.md`, `REVIEW.md`, `CLAUDE.md`) and Ciznia's `great-reset` branch as the structure reference.
- Your nix-darwin repository, read 2026-11-01: `CLAUDE.md`, `CONTEXT.md`, `docs/adr/0001` to `0003`, `docs/agents/`, `.scratch/multi-machine/map.md` and tickets 05, 06, 11, 12, 16, 17, 30 to 33, `modules/home.nix`, `modules/darwin.nix`, `flake.lock`; the research notes only by keyword search.
- Your Bootstrap folder: `.envrc`, `nix/flake.nix`, `devenv.yaml`. ufda README: https://github.com/renman-ymd/ufda
