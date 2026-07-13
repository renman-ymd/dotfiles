# Emacs Improvement Plan

_Companion to `REVIEW.md`. This is a **proposal only** — nothing here is implemented. Each phase ends at a checkpoint where you approve before I touch any file._

Two focus areas:

- **A.** Split configs: lightweight **TUI/CLI** config (trim to essentials, code modes simpc-style) + heavy **GUI** config as the default.
- **B.** Caret behavior + multiple-cursors setup and keybindings.

At the bottom there's a **"Decisions I need from you"** section. I'd like those answered before writing any code, since several branch the work.

---

## A. Lightweight TUI + heavy GUI split

### A.0 Current wiring (so we know what we're changing)

From `modules/home.nix`:

| Alias / var | Current value | Meaning |
|---|---|---|
| `em` | `emacsclient -s main -nw` | heavy config, in terminal, via daemon |
| `emg` | `emacsclient -s main -c` | heavy config, GUI frame, via daemon |
| `eml` | `emacs -nw --init-dir ~/.config/emacs-light` | light config, terminal |
| `EDITOR` | daemon `-nw` if running, else `emacs-light` | **heavy** is the effective default |
| `VISUAL` | `emacsclient -s main -c` | heavy GUI |
| `git core.editor` | `emacs -nw --init-dir ~/.config/emacs-light` | already light |

So today the **heavy** config is the terminal default. Your goal inverts this: **light = the terminal/CLI default; heavy = GUI and the "real" editor.**

### A.1 Target design

- `configs/emacs-light/` → the default for **quick terminal edits** (`$EDITOR`, git commits, `$VISUAL` fallback when no GUI). Trim-to-essentials; code files use vendored **simpc-style** minor modes, not treesit/LSP.
- `configs/emacs/` (heavy) → the **GUI** experience, launched via the daemon (`emg`). Reframe from "terminal-first" to "GUI-first"; keep the full stack.
- The daemon keeps running for instant GUI frames; the light config is a plain (non-daemon) `emacs -nw` for millisecond-ish startup on throwaway edits.

### A.2 What the light config becomes (trim-to-essentials + simpc code modes)

Proposed **keep** (essentials): UTF-8, no-backups, `electric-pair`, `delete-selection`, `show-paren`, `column-number`, line numbers, clipboard (`xclip`/`clipetty`), catppuccin theme, `which-key`, `move-text`, `hl-todo`, and your small keybinds (`C-c d`, `C-c /`, TAB/S-TAB indent).

Proposed **drop** from light (moves to GUI-only): `treesit-auto`, `vc-jj`, and the per-language modes (`yaml/toml/nix/smalltalk/markdown`) — or keep only markdown+the config formats you actually edit in a pinch. **You chose "keep code modes simpc-style,"** so:

- Vendor `simpc-mode.el` into `configs/emacs-light/` (the rexim/valignatev file — a ~150-line, zero-dep C major mode: comment/string syntax table, keyword + type font-lock, simple 4-space indent).
- Route `.c`/`.h`/`.cpp`/`.hpp` → `simpc-mode`.
- For other languages, rely on Emacs' **built-in** `prog-mode` + `font-lock` (basic highlighting, no grammar downloads). Optionally add one or two more simpc-style micro-modes only for languages you quick-edit often.
- Net effect: highlighting + sane indent, **no network, no LSP, no treesit grammar compilation** — startup stays tiny.

Rough shape of the light `init.el` (illustrative, ~60–80 lines vs 152 today):

```elisp
;; essentials only
(set-language-environment "UTF-8")
(setq make-backup-files nil auto-save-default nil create-lockfiles nil
      ring-bell-function 'ignore use-short-answers t)
(setq-default indent-tabs-mode nil tab-width 4)
(electric-pair-mode 1) (delete-selection-mode 1)
(column-number-mode 1) (show-paren-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; clipboard + theme (unchanged)
;; which-key, move-text, hl-todo (unchanged)

;; code = simpc-style, no treesit / no LSP
(load (expand-file-name "simpc-mode.el" user-emacs-directory))
(add-to-list 'auto-mode-alist '("\\.[hc]\\(pp\\)?\\'" . simpc-mode))

;; small keybinds: C-c d duplicate, C-c / comment, TAB/S-TAB indent
```

### A.3 home.nix rewiring

Target: `$EDITOR` = light (fast, for commits/quick edits), GUI heavy = the everyday default you reach for.

Because you want both **nushell** and **powershell** syntax, here's what the env logic looks like in each (bash/zsh omitted per your preference):

**nushell** (`config.nu` / the block home.nix writes):

```nu
# EDITOR: light, fast terminal editor for quick edits & git commits
$env.EDITOR = "emacs -nw --init-dir ~/.config/emacs-light"
# VISUAL: the real editor — GUI heavy config via the daemon
$env.VISUAL = "emacsclient -s main -c -a ''"   # -a '' auto-starts the daemon if down
```

**powershell** (`$PROFILE`):

```powershell
# EDITOR: light, fast terminal editor
$env:EDITOR = 'emacs -nw --init-dir ~/.config/emacs-light'
# VISUAL: GUI heavy config via the daemon
$env:VISUAL = 'emacsclient -s main -c -a ""'
```

> Note on `emacsclient -a ''`: the `-a`/`--alternate-editor` flag with an empty string tells emacsclient to **start the daemon itself** if it isn't running, instead of erroring. Handy so `emg` always works cold.

Alias changes to propose (keep `em`/`emg`/`eml`, adjust meaning):

- `em` → keep as heavy-in-terminal for when you explicitly want the full stack in a pane.
- `emg` → heavy GUI (unchanged) — becomes your "default" editor.
- `eml` → light terminal (unchanged).
- `git core.editor` → stays light (already correct).

### A.4 Phased steps (each ends at a checkpoint)

1. **Confirm the target** (this doc) → you approve the design + the decisions below.
2. **Rewrite `configs/emacs-light/`**: trim `init.el`, vendor `simpc-mode.el`, adjust `early-init.el`. I show you the diff; you approve.
3. **Reframe `configs/emacs/`**: flip the "terminal-first" comments + theme default to GUI-first; move any TUI-only bits (e.g. clipetty, diff-hl margin) behind `(unless (display-graphic-p) …)` cleanly. Diff for approval.
4. **Rewire `home.nix`** env/aliases (nushell + powershell blocks). Diff for approval.
5. **Clean up** the stray root `init.el` / `early-init.el` duplicates (pending the verification in `REVIEW.md` §6.5).
6. **Verify**: `nix flake check` / `darwin-rebuild build`, then measure light startup (`emacs -nw --init-dir ~/.config/emacs-light --eval '(message "%s" (emacs-init-time))'`) and confirm the GUI daemon still loads clean. You sign off.

---

## B. Caret behavior + multiple-cursors

### B.1 Caret (the text cursor)

Current state: your config never sets `cursor-type` and never touches `blink-cursor-mode`, so you get the default blinking box in GUI and whatever the terminal draws in TUI. Options, all small:

**GUI (heavy config):**

- `cursor-type` — `'box` (default), `'bar` (thin I-beam, VS Code-like), `'(bar . 2)` (2px bar), `'hbar` (underline), `'hollow`.
- `blink-cursor-mode` — `0` to stop blinking (valignatev does this), or tune `blink-cursor-blinks`/`blink-cursor-interval`.
- `cursor-in-non-selected-windows` — set to `'hollow` or `nil` so only the active window shows a solid caret.
- `set-cursor-color` — chshersh sets an explicit color; you could tie it to a catppuccin accent.

**TUI (light + heavy-in-terminal):**

- Emacs `-nw` does **not** natively change the terminal cursor shape from `cursor-type`. To get a bar/underline caret in the terminal you need a helper that emits the `DECSCUSR` escape (`ESC [ n q`), e.g. the small package **`term-cursor`**, or the standalone emitter inside **`evil-terminal-cursor-changer`** (usable without evil). Your terminals (Kitty/Ghostty, per your clipetty note) support DECSCUSR, so this will work — but I want to **verify against your actual `$TERMINAL`** before adding it.
- Alternative: do nothing in TUI and let Kitty/Ghostty's own cursor config stand. Simplest, zero Emacs code.

### B.2 multiple-cursors

Current binds (heavy config): `C-S-c C-S-c` (edit-lines), `C->`, `C-<`, `C-c C-<` (mark all). Gaps and proposals:

- **Fill the obvious holes** (rexim already does these): `mc/skip-to-next-like-this` (`C-"`), `mc/skip-to-previous-like-this` (`C-:`), `mc/mark-all-dwim`, `mc/mark-all-in-region`, and `mc/unmark-next-like-this`. This gives you the full "add / skip / unmark / mark-all" set.
- **hl-line interaction:** with `global-hl-line-mode` on, MC's fake cursors can be hard to see. Fix is a one-liner to disable hl-line while MC is active (`multiple-cursors-mode-enabled-hook`/`-disabled-hook`), or set a distinct `mc/cursor-face`.
- **Region-active caret:** consider making the fake-cursor bar match your real caret choice from B.1 for consistency.

### B.3 Optional: consider `macrursors` instead of / alongside MC

Verified: `multiple-cursors` still works but is effectively in maintenance-only mode (upstream closed issues/PRs). **`macrursors`** is a faster, minimal kmacro-based alternative (records once, applies at the end, less flicker than MC jumping cursor-by-cursor). This is **optional** — MC is fine and battle-tested. I'd only switch if you want the speed/minimalism. `iedit` is a third option for the narrower "rename this identifier everywhere" case.

### B.4 Steps

1. You pick caret shapes (GUI + whether to bother with TUI cursor shape) and the MC-vs-macrursors question below.
2. I draft the caret block (GUI settings + optional TUI helper) and the expanded MC binds. Diff for approval.
3. Verify visually in both `emg` (GUI) and a terminal frame; confirm no keybind clashes (`C-"`/`C-:` are free in your map).

---

## Decisions I need from you

Per how you like to work, I won't write any code until these are settled:

1. **LSP in the light config:** confirm _none_ (pure simpc + built-in font-lock), or do you want `eglot` available on demand in light too?
2. **Heavy config LSP:** keep `lsp-mode` (current, heaviest) as-is for GUI, or also evaluate switching to `eglot` (lighter, built-in) as valignatev does?
3. **`$EDITOR` default:** confirm you want `$EDITOR` = **light** always (fast quick-edits), with GUI heavy reached via `emg`/`$VISUAL`. Or should `$EDITOR` prefer the heavy daemon when it's up (closer to today)?
4. **TUI caret shape:** do you want a real bar/underline caret _inside_ terminal Emacs (needs a small `DECSCUSR` helper + I verify your `$TERMINAL`), or leave the terminal's own cursor alone?
5. **GUI caret:** preferred shape — box, thin bar (VS Code-like), or underline — and blink on or off?
6. **Multi-cursor engine:** keep `multiple-cursors` (just expand the binds), or also add/try `macrursors`?
7. **Adopt list from `REVIEW.md` §5:** OK to include the "strong adopt" set (`exec-path-from-shell`, `gcmh`, `no-littering`, `winner-mode`, ansi-color compilation) in the heavy config while we're in there? Any you want to skip?
8. **Startup diet:** OK to add `:defer`/`:commands` to the heavy background packages (dap-mode, treemacs, pdf-tools, elcord, wakatime, gptel, copilot-chat, majutsu) to cut startup?
9. **Shared code:** want a small shared `lisp/common.el` for the bits duplicated across light+heavy, or keep them independent?

Answer any subset — for anything you don't specify I'll come back rather than assume.
