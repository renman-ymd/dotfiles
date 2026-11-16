# Emacs Config Review

_Comparison of your config against three reference dotfiles, with recommendations._
_Companion document: `PLAN.md` (the two focus areas: light/GUI split + caret & multi-cursor)._

Sources reviewed:

- **valignatev/dotemacs** — `init.el` (+ vendored `simpc-mode.el`)
- **rexim/dotfiles** — `.emacs`, `.emacs.rc/{rc,misc-rc}.el`, `.emacs.custom.el`, `.emacs.local/simpc-mode.el`, snippets tree
- **chshersh/dotfiles** — `.emacs`
- **You** — `configs/emacs/init.el` (1106 lines), `configs/emacs/early-init.el`, `configs/emacs-light/init.el`, `modules/home.nix`

---

## 1. TL;DR

All three references are **modest, single-file, keyboard-vanilla** configs. Yours is **an order of magnitude larger** (≈70 packages: full LSP stack, AI tooling, treemacs, vterm, jj integration, DAP, WakaTime, Elcord). You are not "missing" much in raw features — you have far more than any of them. What they do better is **restraint, startup discipline, and a clean TUI story**, plus a handful of small quality-of-life pieces you genuinely lack.

The three most valuable things to take from them:

1. **`exec-path-from-shell`** (chshersh) — a real gap on macOS GUI Emacs; without it your GUI frame won't see the same `PATH` as your shell (LSP servers, `jj`, `cargo`, `gh` may silently fail to launch from `emg`).
2. **`gcmh` + selective deferral** (valignatev) — your config loads ~70 packages eagerly (`use-package-always-defer nil`); this is the single biggest thing hurting your startup.
3. **The simpc-mode discipline** (rexim/valignatev) — a tiny, dependency-free C mode is exactly the model for your lightweight TUI config.

Keybinding-wise you are closest to **rexim** (classic Emacs chords) with a **VS Code familiarity layer** bolted on. None of the three would feel foreign to you except chshersh (full Vim/evil).

---

## 2. Keybinding styles

| Config | Modal editing? | Package manager | Completion stack | Binding philosophy |
|---|---|---|---|---|
| **rexim** | No | `package.el` + `rc/require` helper | ido + smex + helm + company | Pure classic Emacs. Deep `C-c`-prefix trees (`C-c h …` helm, `C-c m …` magit). Adds `windmove` (Shift+arrows), `M-x`→smex. |
| **valignatev** | **Hybrid** | elpaca | vertico + consult + marginalia + orderless | Vanilla Emacs by default, but `evil` is installed with `evil-default-state 'emacs` — modal editing only turns on in `prog/text/conf/fundamental` buffers. Function keys for actions (`F5/F6` deadgrep, `F7` recompile). |
| **chshersh** | **Yes (full evil)** | `package.el` (manual) | ido + smex | True Vim modal. `evil-mode t` globally. Minimal chords beyond that; a quirky "save buffer on leaving insert state" hook. |
| **You** | No | `package.el` + `use-package` | vertico + consult + corfu + cape + embark + orderless | Classic Emacs chords **plus a VS Code layer**: `C-/` comment, `C-c d` duplicate line, `TAB`/`S-TAB` region indent, `M-↑/↓` move line, `<escape>`→quit. Modern minibuffer + in-buffer completion. |

**Read on the three styles:**

- **rexim** is the "Emacs the way it shipped, just sharpened" school. No modal editing, everything is a chord, and the interesting keybindings live under mnemonic prefixes. Your config is philosophically the same family — you just replaced his ido/smex/helm/company generation with the modern vertico/consult/corfu generation, and layered VS Code muscle-memory on top.

- **valignatev** is the most sophisticated: he keeps Emacs bindings as the default but opts into Vim normal-mode _per major mode_. It is a genuinely interesting middle path if you ever want modal editing for code without giving up Emacs everywhere else. His completion stack is essentially a subset of yours.

- **chshersh** is the outlier: full Vim. Nothing here maps to how you work today; its value to you is mostly the small non-modal pieces (`exec-path-from-shell`, `desktop-save-mode`, cursor color, spell-check in comments).

---

## 3. Where you overlap each reference

- **rexim:** `multiple-cursors` (identical base binds — `C-S-c C-S-c`, `C->`, `C-<`, `C-c C-<`), `move-text` (he uses `M-p/M-n`, you bind both `M-↑/↓` and `M-p/M-n`), a `duplicate-line` command, `magit`-style VCS entry points, `display-line-numbers`, `yasnippet`, a pile of language modes, whitespace/trailing-space handling.
- **valignatev:** vertico + consult + orderless + marginalia, `eglot`/LSP (he uses eglot, you use lsp-mode), `editorconfig`, `which-key`-like discoverability, `show-paren`, `global-hl-line`, treesit-based major modes, `magit`-equivalent, per-language indent offsets, ansi-color in compilation.
- **chshersh:** `markdown-mode` (same recipe), `diff-hl` (`global-diff-hl-mode`), `global-auto-revert-mode`, `hl-line`, trailing-whitespace-on-save, `column-number-mode`.

---

## 4. Config you have that none of them do

This is most of your file. Highlights, so you can see how far ahead you already are:

- **Completion/UX:** corfu + corfu-terminal + cape (in-buffer completion), embark + embark-consult, wgrep, expand-region, avy, ace-window, vundo, consult-todo, nerd-icons (+ dired/completion), doom-modeline.
- **LSP/diagnostics:** lsp-mode + lsp-ui (sideline/peek/doc), flycheck + flycheck-inline, lsp-treemacs, dap-mode debugger, yasnippet-snippets.
- **VCS:** first-class **jujutsu** support (`vc-jj`, `majutsu`, `project.el` jj-root detection, diff-hl margin in TUI) — none of them touch jj.
- **AI:** copilot.el, copilot-chat, gptel (Copilot-backed), agent-shell scaffolding for Claude Code.
- **Terminal/UI:** vterm + multi-vterm toggle, treemacs (right-side) + nerd-icons theme, indent-bars, hl-todo with a full keyword palette, rainbow-mode, rainbow-csv, pdf-tools.
- **Clipboard:** clipetty (OSC-52) for TUI/SSH copy — a genuinely nice touch none of them have.
- **Tooling:** WakaTime, Elcord (with a smart "only when a code buffer is visible" toggler), `gh` CLI helpers.

Nobody in the reference set has anything approaching this. Your risk is **weight**, not gaps.

---

## 5. Config they have that you don't — candidates to adopt

Each item: what it is, and my verdict. Verdicts are recommendations for you to accept/reject, not changes I've made.

### Strong adopt

- **`exec-path-from-shell`** _(chshersh)_ — Copies `PATH`/env from your login shell into Emacs. On macOS, a GUI Emacs launched by launchd (your daemon) does **not** inherit your shell `PATH`, so `rust-analyzer`, `jj`, `gh`, `nu`, node LSP servers may not be found from `emg`. This is the most concrete real gap in your config. Small, one-time cost. **→ Add to the heavy/GUI config.**
- **`gcmh`** _(valignatev)_ — "Garbage Collector Magic Hack": raises the GC threshold while you work, collects when idle. Directly addresses your eager-loading startup cost. ~10 lines. **→ Add.**
- **`no-littering`** _(valignatev)_ — Redirects the dozens of package state files (`recentf`, `savehist`, treesit grammars, lsp session, etc.) into `var/` and `etc/` subdirs instead of spraying `~/.config/emacs`. You install a lot of packages, so this keeps the dir clean. **→ Add.**
- **`winner-mode`** _(valignatev)_ — Built-in. `C-c ←` / `C-c →` to undo/redo window layout changes. Free, no package. Pairs well with your treemacs/vterm side windows. **→ Enable.**
- **ansi-color in `*compilation*`** _(both valignatev & rexim)_ — Colorizes compiler output (cargo, jai, etc.). ~5 lines, no package. **→ Add.**

### Adopt if it fits your workflow

- **`git-link`** _(valignatev)_ — Copies a GitHub/GitLab permalink to the current line (`git-link-open-in-browser`). Complements your `gh` helpers and jj workflow. Small.
- **`windmove-default-keybindings`** _(rexim)_ — Shift+arrow to move between windows. Simpler than `ace-window` (`M-o`) for 2–3 window layouts; they coexist fine. Built-in, one line.
- **extra `multiple-cursors` binds** _(rexim)_ — `mc/skip-to-next-like-this` (`C-"`) and `mc/skip-to-previous-like-this` (`C-:`), plus he also uses `mc/mark-all-like-this`. These fill obvious holes in your current 4 binds. **→ Folded into `PLAN.md` (focus area 2).**
- **`paredit`** _(rexim)_ — Structural editing for Lisp/Scheme/Clojure/elisp. Worth it only if you edit elisp/lisp regularly (you do maintain this config). Alternative: built-in `electric-pair` (you already have) + `puni`.
- **`desktop-save-mode`** _(chshersh)_ — Restores your open buffers/windows across restarts. Nice for a long-lived GUI daemon; can slow startup if you keep many buffers. **→ Maybe, GUI only.**
- **`flyspell-prog-mode`** _(chshersh)_ — Spell-checks comments and strings only. Low-noise, helpful in prose-heavy code. Needs `aspell`/`hunspell`.

### Skip (you already have a better equivalent, or it's personal)

- **helm / ido / smex** _(rexim, chshersh)_ — superseded by your vertico/consult/embark stack.
- **company / tide** _(rexim)_ — superseded by corfu + lsp-mode.
- **rexim's whitespace-on-save** — you have `ws-butler` (only cleans lines you touched; strictly better for diffs).
- **valignatev's HiDPI/multi-monitor scaling** — Windows/Linux-oriented; on `emacs-macport` the OS handles scaling differently.
- **valignatev's `disable-bold-and-italic` advice, rexim's transparency toggle, russian input method, org autocommit** — pure personal taste; adopt only if you want them.
- **`deadgrep`** _(valignatev)_ — overlaps your `consult-ripgrep` + `wgrep`.
- **`minions`** _(valignatev)_ — you already tame the modeline with `doom-modeline` + `diminish`.

---

## 6. Things to remove or change in _your_ config

These are the higher-signal issues I found while reading your `init.el`. None are changed yet.

1. **Eager loading of ~70 packages.** `use-package-always-defer nil` (line 48) means almost everything loads at startup. Combine with `gcmh` and add `:defer`/`:hook`/`:commands` to the heavy, rarely-immediate packages (dap-mode, lsp-treemacs, pdf-tools, treemacs, elcord, wakatime, gptel, copilot-chat, majutsu). This is your biggest single win. **Change.**

2. **Global `TAB` rebinding is risky.** Lines 1042–1043 bind `<tab>`/`TAB` globally to `my/indent-or-default`. `TAB` is heavily overloaded: copilot accept, corfu completion, yasnippet field jump, org cycling. A global rebind can shadow those depending on keymap precedence. Safer: bind it in `prog-mode-map`/`text-mode-map`, or only rebind `S-TAB` (unindent) globally and let `TAB` fall through. **Review/change.**

3. **`lsp-mode` is heavy for a "vanilla" config.** You run lsp-mode + lsp-ui + flycheck + flycheck-inline + lsp-treemacs + dap-mode. That's the heaviest possible LSP setup. For the GUI-default config it's defensible; but valignatev shows `eglot` (built-in, ~zero config, uses your existing corfu/flymake) does 90% of it. **Decision for `PLAN.md`:** keep lsp-mode in GUI, use nothing/eglot in light.

4. **The "terminal-first" framing is now backwards.** Your header (line 4) and theme logic (line 141: dark in TUI, light in GUI) were written for a terminal-primary world. After the split you want, the heavy config is **GUI-primary**. Comments + theme defaults should be inverted/clarified. **Change (part of the split).**

5. **Duplicate/stray files.** `~/.config/nix-darwin/init.el` and `early-init.el` at the repo root are **byte-identical** to `configs/emacs/init.el` / `early-init.el`, but `home.nix` only deploys the `configs/emacs/*` copies. The root copies look like leftovers. Confirm and delete to avoid editing the wrong file. **Verify & clean.**

6. **Config duplicated between heavy and light.** `duplicate-line`, the `indent-or-default`/`unindent` helpers, catppuccin setup, and a few binds are copy-pasted in both `configs/emacs/init.el` and `configs/emacs-light/init.el`. Consider a tiny shared `lisp/common.el` loaded by both, so fixes don't have to be made twice. **Maybe (part of the split).**

7. **`global-hl-line-mode` + `multiple-cursors`.** `hl-line` can visually swallow the fake cursors that MC draws. Minor, but relevant to your caret goal — covered in `PLAN.md`.

8. **Always-on background timers.** Elcord polls every 5s and WakaTime reports continuously. Fine, but they're pure overhead/telemetry running even during quick edits. Keep them out of the light config, and consider making them opt-in. **Minor.**

---

## 7. Feeding the two focus areas

Two things carry directly into `PLAN.md`:

- **Lightweight TUI config:** rexim's and valignatev's **`simpc-mode.el`** (identical file) is the template — a ~150-line, zero-dependency C major mode (syntax table + font-lock keyword/type lists + a simple indent function). Your light config should vendor this and route `.c/.h/.cpp` to it, drop `treesit-auto`, and keep only essentials. That matches your "trim to essentials, keep code modes simpc-style" choice.

- **Caret & multi-cursor:** verified current state — `multiple-cursors` still works and is on NonGNU ELPA, but its maintainer has stepped back (issue tracker/PRs closed); **`macrursors`** is a faster, minimal kmacro-based alternative worth a look. Cursor shape is controlled by `cursor-type` (`box`/`bar`/`hbar`/`hollow`) + `blink-cursor-mode` in GUI; in the **TUI** Emacs does **not** natively emit the `DECSCUSR` escape to change the terminal cursor — you need a small helper (`term-cursor`, or the emitter from `evil-terminal-cursor-changer`) and a terminal that supports it (Kitty/Ghostty do). Details and options are in `PLAN.md`.

---

_Sources: [valignatev/dotemacs](https://github.com/valignatev/dotemacs), [rexim/dotfiles](https://github.com/rexim/dotfiles), [chshersh/dotfiles](https://github.com/chshersh/dotfiles), [magnars/multiple-cursors.el](https://github.com/magnars/multiple-cursors.el), [corytertel/macrursors](https://github.com/corytertel/macrursors), [GNU Emacs — Cursor Display](https://www.gnu.org/software/emacs/manual/html_node/emacs/Cursor-Display.html)._
