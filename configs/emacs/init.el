;;; init.el --- Main Emacs configuration -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; A terminal-first, vanilla Emacs 30 configuration.
;; GUI enhancements are conditionally loaded.
;;
;; ┌─────────────────────────────────────────┐
;; │            TABLE OF CONTENTS            │
;; ├─────────────────────────────────────────┤
;; │  1. Package System                      │
;; │  2. Core Settings                       │
;; │  3. Clipboard Integration               │
;; │  4. UI / Theme                          │
;; │  5. Modeline                            │
;; │  6. Completion (Minibuffer)             │
;; │  7. In-Buffer Completion                │
;; │  8. Navigation & Search                 │
;; │  9. Editing Enhancements                │
;; │ 10. Project Management                  │
;; │ 11. VCS — Jujutsu (jj)                  │
;; │ 12. Tree-sitter                         │
;; │ 13. LSP                                 │
;; │ 14. Language Modes                      │
;; │ 15. AI — Copilot, gptel & Claude Code   │
;; │ 16. Terminal Emulator                   │
;; │ 17. File Sidebar                        │
;; │ 18. Tools                               │
;; │ 19. Keybindings                         │
;; │ 20. GUI-Specific Settings               │
;; │ 21. Daemon / Frame Hooks                │
;; └─────────────────────────────────────────┘
;;
;;; Code:

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║  1. PACKAGE SYSTEM                                                ║
;; ╚═══════════════════════════════════════════════════════════════════╝

(require 'package)
(setq package-archives
      '(("melpa"  . "https://melpa.org/packages/")
        ("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")))

;; use-package is built-in since Emacs 29.
(require 'use-package)
(setq use-package-always-ensure t          ; auto-install missing packages
      use-package-always-defer  nil        ; load eagerly unless :defer is set
      use-package-verbose       nil)

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║  2. CORE SETTINGS                                                 ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; ── Encoding ─────────────────────────────────────────────────────────
(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)

;; ── Files & Backup ───────────────────────────────────────────────────
(setq make-backup-files nil              ; no ~ files
      auto-save-default nil              ; no #file# files
      create-lockfiles  nil              ; no .#file symlinks
      custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file 'noerror 'nomessage))

;; ── History & State ──────────────────────────────────────────────────
(savehist-mode 1)                        ; persist minibuffer history
(save-place-mode 1)                      ; remember cursor position
(recentf-mode 1)                         ; track recent files
(setq recentf-max-saved-items 200)
(setq history-length 300)

;; ── Indentation ──────────────────────────────────────────────────────
(setq-default indent-tabs-mode nil       ; spaces, not tabs
              tab-width 4)
(setq-default c-basic-offset 4
              js-indent-level 2
              typescript-ts-mode-indent-offset 2
              css-indent-offset 2)

;; ── Scrolling ────────────────────────────────────────────────────────
(setq scroll-margin 4
      scroll-conservatively 101          ; no recentering on scroll
      scroll-preserve-screen-position t)
(pixel-scroll-precision-mode 1)          ; smooth scrolling (GUI)

;; ── Misc ─────────────────────────────────────────────────────────────
(setq ring-bell-function 'ignore         ; no beep
      use-short-answers t                ; y/n instead of yes/no
      confirm-kill-emacs 'y-or-n-p       ; confirm before quitting
      enable-recursive-minibuffers t
      read-process-output-max (* 1024 1024)) ; 1 MB (helps LSP perf)

(global-auto-revert-mode 1)             ; auto-refresh changed files
(setq global-auto-revert-non-file-buffers t)

(delete-selection-mode 1)               ; typing replaces selection
(column-number-mode 1)                  ; show column in modeline
(global-hl-line-mode 1)                 ; highlight current line
(show-paren-mode 1)                     ; highlight matching paren
(setq show-paren-delay 0)
(electric-pair-mode 1)                  ; auto-close brackets/parens

;; ── Line numbers ─────────────────────────────────────────────────────
(setq display-line-numbers-type 'relative)
(add-hook 'prog-mode-hook   #'display-line-numbers-mode)
(add-hook 'text-mode-hook   #'display-line-numbers-mode)
(add-hook 'conf-mode-hook   #'display-line-numbers-mode)

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║  3. CLIPBOARD INTEGRATION                                         ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; Link the kill-ring to the system clipboard.
;; In GUI mode, Emacs does this by default.
;; In terminal mode, we use clipetty which sends OSC 52 escape
;; sequences — supported by Kitty, Ghostty, and most modern terminals.
;; It also works transparently over SSH.

(setq select-enable-clipboard t
      select-enable-primary t)

(use-package clipetty
  :hook (after-init . global-clipetty-mode)
  :config
  ;; clipetty intercepts kill-ring operations and sends them to the
  ;; system clipboard via the terminal's OSC 52 support.
  (setq clipetty-assume-nested-mux nil))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║  4. UI / THEME                                                    ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; ── Catppuccin theme ─────────────────────────────────────────────────
;; Terminal → macchiato (dark), GUI → latte (light).
;; When running as a daemon, init.el runs with no frame, so we default
;; to macchiato. The GUI hook (my/gui-setup) switches to latte when
;; a graphical frame is created.
(use-package catppuccin-theme
  :config
  (setq catppuccin-flavor (if (display-graphic-p) 'latte 'macchiato))
  (load-theme 'catppuccin t))

;; ── Nerd Icons (works in terminal with Nerd Fonts!) ──────────────────
(use-package nerd-icons
  ;; Run M-x nerd-icons-install-fonts once if icons look wrong in GUI.
  )

(use-package nerd-icons-dired
  :hook (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-completion
  :after marginalia
  :config (nerd-icons-completion-mode 1)
  :hook (marginalia-mode . nerd-icons-completion-marginalia-setup))

;; ── Diminish — hide minor modes from modeline clutter ────────────────
(use-package diminish)

;; ── Which-key — shows available keybindings after prefix ─────────────
;; Press C-x and wait ~0.5s: a popup lists all C-x continuations.
(use-package which-key
  :diminish
  :config
  (setq which-key-idle-delay 0.4
        which-key-sort-order 'which-key-prefix-then-key-order)
  (which-key-mode 1))

;; ── Helpful — better *Help* buffers with source links & examples ─────
(use-package helpful
  :bind (("C-h f" . helpful-callable)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)
         ("C-h x" . helpful-command)
         ("C-h o" . helpful-symbol)))

;; ── Rainbow delimiters ───────────────────────────────────────────────
(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

;; ── Indent guides (Indent Rainbow equivalent) ────────────────────────
;; indent-bars draws colored bars at each indent level.
;; It uses Unicode stipple characters and works in terminal.
(use-package indent-bars
  :hook (prog-mode . indent-bars-mode)
  :custom
  (indent-bars-color '(highlight :face-bg t :blend 0.2))
  (indent-bars-width-frac 0.15)
  (indent-bars-pad-frac 0.1)
  (indent-bars-zigzag nil)
  (indent-bars-color-by-depth '(:regexp "outline-\\([0-9]+\\)" :blend 0.4))
  (indent-bars-highlight-current-depth '(:blend 0.5))
  (indent-bars-treesit-support t)
  (indent-bars-no-descend-string t)
  (indent-bars-no-descend-lists nil))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║  5. MODELINE                                                      ║
;; ╚═══════════════════════════════════════════════════════════════════╝

(use-package doom-modeline
  :hook (after-init . doom-modeline-mode)
  :custom
  (doom-modeline-height 28)
  (doom-modeline-bar-width 4)
  (doom-modeline-icon t)                 ; nerd-icons work in terminal!
  (doom-modeline-major-mode-icon t)
  (doom-modeline-buffer-file-name-style 'relative-from-project)
  (doom-modeline-buffer-encoding nil)    ; hide encoding (usually obvious)
  (doom-modeline-vcs-max-length 20)
  (doom-modeline-workspace-name nil))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║  6. COMPLETION (MINIBUFFER)                                       ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; Vertico — vertical completion UI in the minibuffer
(use-package vertico
  :init (vertico-mode 1)
  :custom
  (vertico-count 15)
  (vertico-cycle t)
  (vertico-resize nil))

;; Orderless — flexible matching (space-separated components, regex, etc.)
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; Marginalia — rich annotations next to completion candidates
(use-package marginalia
  :init (marginalia-mode 1))

;; Consult — enhanced search/navigation commands replacing builtins
(use-package consult
  :bind (("C-s"     . consult-line)       ; replace isearch with consult-line
         ("C-r"     . consult-line)       ; reverse search too
         ("C-x b"   . consult-buffer)     ; enhanced buffer switcher
         ("C-x 4 b" . consult-buffer-other-window)
         ("M-g g"   . consult-goto-line)
         ("M-g M-g" . consult-goto-line)
         ("M-g o"   . consult-outline)    ; jump to outline headings
         ("M-g i"   . consult-imenu)      ; jump to symbol definitions
         ("M-s r"   . consult-ripgrep)    ; project-wide grep (needs ripgrep)
         ("M-s f"   . consult-find)       ; find files
         ("M-s l"   . consult-line)       ; search in buffer
         ("M-s g"   . consult-grep)
         ("M-y"     . consult-yank-pop))  ; better kill-ring browsing
  :config
  (setq consult-narrow-key "<"
        consult-preview-key "M-."))

;; Embark — contextual actions on minibuffer candidates
;; e.g., while browsing files in C-x C-f, press C-. to get
;; actions like "open in other window", "delete", "rename", etc.
(use-package embark
  :bind (("C-."   . embark-act)
         ("C-;"   . embark-dwim)
         ("C-h B" . embark-bindings))
  :config
  (setq prefix-help-command #'embark-prefix-help-command))

(use-package embark-consult
  :after (embark consult)
  :hook (embark-collect-mode . consult-preview-at-point-mode))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║  7. IN-BUFFER COMPLETION                                          ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; Corfu — lightweight in-buffer completion popup
;; Works in terminal via corfu-terminal.
(use-package corfu
  :custom
  (corfu-auto t)                         ; auto-popup
  (corfu-auto-delay 0.15)
  (corfu-auto-prefix 2)                  ; popup after 2 chars
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  (corfu-popupinfo-delay '(0.5 . 0.2))  ; show docs after 0.5s
  :init
  (global-corfu-mode 1)
  (corfu-popupinfo-mode 1))

;; corfu-terminal — makes corfu work in terminal Emacs
(use-package corfu-terminal
  :unless (display-graphic-p)
  :after corfu
  :config (corfu-terminal-mode 1))

;; Cape — extra completion-at-point backends
(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-file)    ; filename completion
  (add-hook 'completion-at-point-functions #'cape-dabbrev)  ; buffer words
  (add-hook 'completion-at-point-functions #'cape-keyword)) ; language keywords

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║  8. NAVIGATION & SEARCH                                           ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; Avy — jump to any visible character
;; Press C-' then type the character you want to jump to.
(use-package avy
  :bind (("C-'"   . avy-goto-char-timer)
         ("M-g w" . avy-goto-word-1)))

;; Ace-window — quick window switching
;; Press M-o, then type the number shown on each window.
(use-package ace-window
  :bind ("M-o" . ace-window)
  :custom (aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l)))

;; wgrep — make grep/ripgrep results editable
;; Run consult-ripgrep, press C-c C-e to edit results in-place,
;; then C-c C-c to apply changes across all files.
(use-package wgrep
  :custom (wgrep-auto-save-buffer t))

;; Expand-region — progressively expand selection
;; Press C-= repeatedly: word → symbol → expression → block → function.
(use-package expand-region
  :bind ("C-=" . er/expand-region))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║  9. EDITING ENHANCEMENTS                                          ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; ── Move lines up/down (VS Code: Alt+Up/Down) ───────────────────────
(use-package move-text
  :config
  (move-text-default-bindings)           ; binds M-up / M-down
  ;; Also bind M-n / M-p for terminal convenience (doesn't clash
  ;; with anything globally; mode-specific maps override these).
  (global-set-key (kbd "M-p") #'move-text-up)
  (global-set-key (kbd "M-n") #'move-text-down))

;; ── hl-todo — highlight TODO/FIXME/HACK/NOTE in comments ────────────
;; This is the "Better Comments" equivalent.
(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :custom
  (hl-todo-keyword-faces
   '(("TODO"    . (:foreground "#f9e2af" :weight bold))    ; yellow
     ("FIXME"   . (:foreground "#f38ba8" :weight bold))    ; red
     ("BUG"     . (:foreground "#f38ba8" :weight bold))    ; red
     ("HACK"    . (:foreground "#fab387" :weight bold))    ; orange
     ("NOTE"    . (:foreground "#a6e3a1" :weight bold))    ; green
     ("REVIEW"  . (:foreground "#89b4fa" :weight bold))    ; blue
     ("PERF"    . (:foreground "#cba6f7" :weight bold))    ; mauve
     ("WARNING" . (:foreground "#fab387" :weight bold))    ; orange
     ("DEPRECATED" . (:foreground "#6c7086" :strike-through t))))) ; grey

;; consult-todo — search all TODOs in project (TODO Tree equivalent)
;; Use M-s t to search TODOs across the project.
(use-package consult-todo
  :after (consult hl-todo)
  :bind ("M-s t" . consult-todo))

;; ── Trailing whitespace ──────────────────────────────────────────────
;; Show trailing whitespace in prog/text modes.
(defun my/show-trailing-whitespace ()
  "Enable trailing whitespace display."
  (setq show-trailing-whitespace t))
(add-hook 'prog-mode-hook #'my/show-trailing-whitespace)
(add-hook 'text-mode-hook #'my/show-trailing-whitespace)

;; ws-butler — clean up trailing whitespace only on lines you changed.
;; Avoids noisy diffs from reformatting untouched lines.
(use-package ws-butler
  :diminish
  :hook (prog-mode . ws-butler-mode))

;; ── Multiple cursors ─────────────────────────────────────────────────
(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . mc/edit-lines)        ; add cursor to each line in region
         ("C->"          . mc/mark-next-like-this)
         ("C-<"          . mc/mark-previous-like-this)
         ("C-c C-<"      . mc/mark-all-like-this)))

;; ── Vundo — visual undo tree ─────────────────────────────────────────
;; Press C-x u to see your undo history as a visual tree.
(use-package vundo
  :bind ("C-x u" . vundo)
  :custom (vundo-glyph-alist vundo-unicode-symbols))

;; ── Editorconfig ─────────────────────────────────────────────────────
;; Built-in since Emacs 30, just enable it.
(editorconfig-mode 1)

;; ── Emoji insertion ──────────────────────────────────────────────────
;; Built-in since Emacs 29. C-x 8 e opens the emoji picker.
;; For a more VS-Code-like experience:
(global-set-key (kbd "C-c e") #'emoji-insert)

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 10. PROJECT MANAGEMENT                                            ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; Built-in project.el works with vc-jj for jj repos.
(use-package project
  :ensure nil                            ; built-in
  :config
  ;; Teach project.el to recognize .jj directories as project roots.
  (defun my/project-find-jj (dir)
    "Identify a jj project root by looking for a .jj directory."
    (let ((root (locate-dominating-file dir ".jj")))
      (when root (cons 'transient root))))
  (add-to-list 'project-find-functions #'my/project-find-jj))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 11. VCS — JUJUTSU (jj)                                            ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; ── vc-jj — built-in VC integration for jj (GNU ELPA) ───────────────
;; Provides: C-x v = (diff), C-x v l (log), C-x v d (dir status),
;; C-x v v (next VC action), modeline branch indicator.
(use-package vc-jj
  :config
  ;; Ensure jj repos are detected even without .git
  (add-to-list 'vc-handled-backends 'JJ))

;; ── Majutsu — Magit-like interface for jj ────────────────────────────
;; Run M-x majutsu to open the jj status/log buffer.
;; Requires jj >= 0.37.0 (you have 0.38.0, good).
(use-package majutsu
  :vc (:url "https://github.com/0WD0/majutsu")
  :bind ("C-c j" . majutsu)
  :commands (majutsu majutsu-log))

;; ── diff-hl — show VCS changes in the gutter ────────────────────────
;; Works with vc-jj to show added/modified/deleted lines.
(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode)
         (text-mode . diff-hl-mode)
         (conf-mode . diff-hl-mode)
         (dired-mode . diff-hl-dired-mode))
  :config
  ;; In terminal mode, use the margin instead of the fringe.
  (unless (display-graphic-p)
    (diff-hl-margin-mode 1)))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 12. TREE-SITTER                                                   ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; Emacs 30 has built-in treesit, but not the grammar libraries.
;; treesit-auto will auto-install grammars and remap major modes.

(use-package treesit-auto
  :demand t
  :custom
  (treesit-auto-install 'prompt)         ; ask before installing a grammar
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode 1))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 13. LSP                                                           ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; ── Yasnippet — snippet expansion engine ─────────────────────────────
;; Required by lsp-mode for snippet completions (e.g., function
;; signatures with placeholders). TAB / C-c y n to jump between fields.
;; yasnippet-snippets provides a large collection of premade snippets
;; for many languages. No system install needed — pure Emacs packages.
(use-package yasnippet
  :diminish yas-minor-mode
  :hook (prog-mode . yas-minor-mode)
  :config
  (yas-reload-all))

(use-package yasnippet-snippets
  :after yasnippet)

;; lsp-mode — feature-rich LSP client (heavier than eglot, more features)
(use-package lsp-mode
  :hook ((c-ts-mode          . lsp-deferred)
         (c++-ts-mode        . lsp-deferred)
         (rust-ts-mode       . lsp-deferred)
         (python-ts-mode     . lsp-deferred)
         (go-ts-mode         . lsp-deferred)
         (js-ts-mode         . lsp-deferred)
         (typescript-ts-mode . lsp-deferred)
         (tsx-ts-mode        . lsp-deferred)
         ;; (java-ts-mode       . lsp-deferred)
         (haskell-mode       . lsp-deferred)
         (zig-mode           . lsp-deferred)
         (nix-mode           . lsp-deferred)
         ;; (astro-ts-mode      . lsp-deferred)
         (kotlin-mode        . lsp-deferred))
  :custom
  (lsp-keymap-prefix "C-c l")           ; C-c l as LSP prefix
  (lsp-idle-delay 0.3)
  (lsp-completion-provider :none)        ; use corfu instead of lsp's own
  (lsp-enable-snippet t)
  (lsp-enable-on-type-formatting nil)
  (lsp-enable-indentation nil)           ; let Emacs handle indentation
  (lsp-headerline-breadcrumb-enable t)   ; breadcrumbs in header
  (lsp-modeline-code-actions-enable t)
  (lsp-modeline-diagnostics-enable t)
  (lsp-diagnostics-provider :flycheck)
  (lsp-log-io nil)                       ; disable for performance
  :config
  ;; Performance tuning
  (setq lsp-response-timeout 5)

  ;; Disable LSP servers we don't use (stops noisy "not on path" log lines).
  ;; semgrep-lsp: heavy SAST tool, not needed with proper language LSPs.
  ;; rls: deprecated Rust Language Server, superseded by rust-analyzer.
  (setq lsp-disabled-clients '(semgrep-lsp rls))

  ;; ;; Tailwind CSS LSP (for React/Astro/HTML)
  ;; (with-eval-after-load 'lsp-mode
  ;;   (add-to-list 'lsp-language-id-configuration '(astro-ts-mode . "astro"))))
  )

;; lsp-ui — inline diagnostics, peek, sideline
;; This is the closest to VS Code's "Error Lens" and "Pretty TS Errors".
(use-package lsp-ui
  :after lsp-mode
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  ;; Sideline: shows diagnostics and code actions on the right side
  ;; of the current line — very similar to Error Lens.
  (lsp-ui-sideline-enable t)
  (lsp-ui-sideline-show-diagnostics t)
  (lsp-ui-sideline-show-hover nil)       ; hover can be noisy
  (lsp-ui-sideline-show-code-actions t)
  (lsp-ui-sideline-delay 0.2)
  ;; Doc popup on hover
  (lsp-ui-doc-enable t)
  (lsp-ui-doc-delay 0.5)
  (lsp-ui-doc-position 'at-point)
  (lsp-ui-doc-show-with-cursor nil)      ; only show on hover, not cursor
  (lsp-ui-doc-show-with-mouse t)
  ;; Peek — inline file/reference preview
  (lsp-ui-peek-enable t)
  :bind (:map lsp-ui-mode-map
         ("M-." . lsp-ui-peek-find-definitions)
         ("M-?" . lsp-ui-peek-find-references)))

;; Flycheck — inline error checking
(use-package flycheck
  :hook (lsp-mode . flycheck-mode)
  :custom
  (flycheck-display-errors-delay 0.2)
  (flycheck-indication-mode 'right-margin))  ; use margin in terminal

;; flycheck-inline — show error messages inline beneath the error line
;; Closest to VS Code Error Lens behavior.
(use-package flycheck-inline
  :after flycheck
  :hook (flycheck-mode . flycheck-inline-mode))

;; Define a face that lsp-mode references but doesn't ship.
;; Without this, "unnecessary code" diagnostics (unused variables,
;; unreachable code) show as plain warnings instead of grayed-out.
(defface lsp-flycheck-warning-unnecessary
  '((t :inherit flycheck-warning :foreground "#6c7086"))
  "Face for unnecessary/unused code diagnostics from LSP.")

;; lsp-treemacs — LSP + treemacs integration (errors, symbols, etc.)
(use-package lsp-treemacs
  :after (lsp-mode treemacs)
  :commands lsp-treemacs-errors-list)

;; DAP Mode — debugger (for LLDB, etc.)
(use-package dap-mode
  :after lsp-mode
  :commands (dap-debug dap-debug-edit-template)
  :custom
  (dap-auto-configure-features '(sessions locals breakpoints expressions controls tooltip))
  :config
  ;; C/C++ via codelldb (Code LLDB equivalent)
  (require 'dap-codelldb nil t)
  ;; Rust
  (require 'dap-gdb-lldb nil t)
  ;; Python
  (require 'dap-python nil t))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 14. LANGUAGE MODES                                                ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; Most languages use tree-sitter modes (auto-remapped by treesit-auto):
;;   C → c-ts-mode, C++ → c++-ts-mode, Python → python-ts-mode,
;;   JS → js-ts-mode, TS → typescript-ts-mode, TSX → tsx-ts-mode,
;;   Rust → rust-ts-mode, Go → go-ts-mode, Java → java-ts-mode,
;;   JSON → json-ts-mode, YAML → yaml-ts-mode, TOML → toml-ts-mode,
;;   Dockerfile → dockerfile-ts-mode, CMake → cmake-ts-mode

;; ── Rust ─────────────────────────────────────────────────────────────
;; rust-ts-mode is built-in. rust-analyzer is the LSP server.
;; No extra package needed, lsp-mode handles it.

;; ── Zig ──────────────────────────────────────────────────────────────
(use-package zig-mode
  :mode "\\.zig\\'"
  :custom (zig-format-on-save nil))      ; format via LSP instead

;; ── Haskell ──────────────────────────────────────────────────────────
(use-package haskell-mode
  :mode ("\\.hs\\'" "\\.lhs\\'")
  :hook (haskell-mode . interactive-haskell-mode))

;; ── Kotlin ───────────────────────────────────────────────────────────
(use-package kotlin-mode
  :mode "\\.kt\\'")

;; —— SmallTalk / Pharo ————————————————————————————————————————————————
(use-package smalltalk-mode
  :mode ("\\.st\\'"
         "\\.class\\.st\\'"
         "\\.extension\\.st\\'"
         "\\.package\\.st\\'"))

(defun my/smalltalk-mode-setup ()
  "Apply Pharo formatting conventions for Smalltalk code."
  (setq-local indent-tabs-mode t)
  (setq-local tab-width 3)
  (setq-local smalltalk-indent-amount 3)
  (when (bound-and-true-p ws-butler-mode)
    (ws-butler-mode -1)))
(add-hook 'smalltalk-mode-hook #'my/smalltalk-mode-setup)

;; ── Web (HTML/JSX/TSX/Astro auto-close & rename tags) ────────────────
;; web-mode handles auto-close and auto-rename of tags.
(use-package web-mode
  :mode ("\\.html\\'" "\\.svelte\\'" "\\.vue\\'")
  :custom
  (web-mode-markup-indent-offset 2)
  (web-mode-css-indent-offset 2)
  (web-mode-code-indent-offset 2)
  (web-mode-enable-auto-closing t)       ; auto close tags
  (web-mode-enable-auto-pairing t)
  (web-mode-enable-auto-quoting t)
  (web-mode-enable-current-element-highlight t)) ; highlight matching tag

;; ── Astro ────────────────────────────────────────────────────────────
(use-package astro-ts-mode
  :mode "\\.astro\\'"
  :after web-mode)

;; ── Nix ──────────────────────────────────────────────────────────────
(use-package nix-mode
  :mode "\\.nix\\'")

;; ── Markdown ─────────────────────────────────────────────────────────
(use-package markdown-mode
  :mode (("\\.md\\'"  . markdown-mode)
         ("\\.mdx\\'" . markdown-mode))  ; MDX uses markdown-mode as base
  :custom
  (markdown-command "pandoc")            ; use pandoc for preview if available
  (markdown-fontify-code-blocks-natively t))

;; ── Mermaid ──────────────────────────────────────────────────────────
(use-package mermaid-mode
  :mode "\\.mmd\\'")

;; ── Meson ────────────────────────────────────────────────────────────
(use-package meson-mode
  :mode "\\meson\\.build\\'")

;; ── Gradle (Groovy) ──────────────────────────────────────────────────
(use-package groovy-mode
  :mode ("\\.gradle\\'" "\\.groovy\\'"))

;; ── Docker ───────────────────────────────────────────────────────────
;; dockerfile-ts-mode is handled by treesit-auto.

;; ── Tailwind CSS ─────────────────────────────────────────────────────
;; lsp-tailwindcss provides LSP support for Tailwind.
;; (use-package lsp-tailwindcss
;;   :after lsp-mode
;;   :init (setq lsp-tailwindcss-add-on-mode t))

;; ── x86 Assembly ─────────────────────────────────────────────────────
(use-package nasm-mode
  :mode ("\\.asm\\'" "\\.nasm\\'" "\\.s\\'"))

;; ── CSV with rainbow columns ─────────────────────────────────────────
(use-package csv-mode
  :mode "\\.csv\\'"
  :hook (csv-mode . csv-align-mode))

(use-package rainbow-csv
  :vc (:url "https://github.com/emacs-vs/rainbow-csv")
  :hook (csv-mode . rainbow-csv-mode))

;; ── YAML ─────────────────────────────────────────────────────────────
;; yaml-ts-mode is handled by treesit-auto, but ansible files etc.
;; may benefit from yaml-mode as fallback.
(use-package yaml-mode
  :mode "\\.ya?ml\\'")

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 15. AI — COPILOT, gptel & CLAUDE CODE                             ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; No API keys or ~/.authinfo needed. Everything authenticates through
;; your existing GitHub Copilot subscription (via gh CLI / copilot.el)
;; and your Claude subscription (via Claude Code login).

;; ── copilot.el — inline ghost-text completions ───────────────────────
;; TAB to accept, C-] to dismiss. Authenticates via gh CLI.
;; Run M-x copilot-login on first use.
(use-package copilot
  :diminish
  :hook (prog-mode . copilot-mode)
  :custom
  (copilot-indent-offset-warning-disable t)
  :bind (:map copilot-completion-map
         ("<tab>"   . copilot-accept-completion)
         ("TAB"     . copilot-accept-completion)
         ("C-]"     . copilot-clear-overlay)
         ("M-]"     . copilot-next-completion)
         ("M-["     . copilot-previous-completion)
         ("C-<tab>" . copilot-accept-completion-by-word)))

;; ── request.el — HTTP library (dependency of copilot-chat) ───────────
(use-package request)

;; ── copilot-chat.el — GitHub Copilot chat interface ──────────────────
;; Provides code-specific commands: explain, review, fix, optimize, test.
;; Authenticates through copilot.el (no API key needed).
;; Run M-x copilot-chat-display to open the chat window.
(use-package copilot-chat
  :vc (:url "https://github.com/chep/copilot-chat.el"
       :branch "main")
  :after (request markdown-mode)
  :bind (("C-c c c" . copilot-chat-display)
         ("C-c c e" . copilot-chat-explain)
         ("C-c c r" . copilot-chat-review)
         ("C-c c f" . copilot-chat-fix)
         ("C-c c o" . copilot-chat-optimize)
         ("C-c c t" . copilot-chat-test)
         ("C-c c d" . copilot-chat-doc))
  :custom
  (copilot-chat-frontend 'markdown))

;; ── gptel — general-purpose LLM chat from any buffer ─────────────────
;; Configured to use GitHub Copilot's models (Claude, GPT, etc.)
;; through your existing Copilot subscription.
;; Keys: C-c g g = open chat, C-c g s = send prompt from any buffer.
;; Use C-c g m to switch between available models.
(use-package gptel
  :bind (("C-c g g" . gptel)
         ("C-c g s" . gptel-send)
         ("C-c g m" . gptel-menu)
         ("C-c g a" . gptel-add))        ; add context (files/buffers)
  :config
  (setq gptel-default-mode 'org-mode)

  ;; gptel has built-in GitHub Copilot support.
  ;; It reuses copilot.el's authentication — no API key needed.
  ;; After copilot.el is authenticated (M-x copilot-login), gptel
  ;; will show "Copilot:" models in the model menu (C-c g m).
  ;; Available models include Claude Sonnet, GPT-4o, Gemini, etc.
  ;;
  ;; If the Copilot backend doesn't auto-appear, ensure copilot.el
  ;; is authenticated, then restart Emacs.
  )

;; ── agent-shell — Claude Code inside Emacs (ACP protocol) ────────────
;; Runs Claude Code as a native Emacs shell buffer using the Agent
;; Client Protocol. Uses your Claude subscription (login-based auth,
;; no API key needed).
;;
;; Prerequisites (install once):
;;   npm install -g @zed-industries/claude-agent-acp
;;
;; Usage:
;;   C-c a c  → Start/toggle Claude Code session
;;   C-c a a  → Pick any agent (Claude, Gemini, etc.)
;;
;; Inside the agent-shell buffer:
;;   Type your prompt and press RET to send.
;;   Permission requests show y/n/! bindings.
;;   The agent can read/write files in your project.

;; (use-package shell-maker
;;   :ensure t)

;; (use-package acp
;;   :vc (:url "https://github.com/xenodium/acp.el")
;;   :ensure t)

;; (use-package agent-shell
;;   :vc (:url "https://github.com/xenodium/agent-shell")
;;   :after (shell-maker acp)
;;   :bind (("C-c a c" . agent-shell-anthropic-start-claude-code)
;;          ("C-c a a" . agent-shell)       ; pick from all agents
;;          ("C-c a t" . agent-shell-toggle)) ; toggle current agent
;;   :config
;;   ;; Use login-based auth (your Claude subscription, no API key).
;;   (setq agent-shell-anthropic-authentication
;;         (agent-shell-anthropic-make-authentication :login t))

;;   ;; Inherit PATH and other env vars so Claude Code can find
;;   ;; your tools (LSP servers, jj, cargo, etc.)
;;   (setq agent-shell-anthropic-claude-environment
;;         (agent-shell-make-environment-variables :inherit-env t)))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 16. TERMINAL EMULATOR                                             ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; vterm — fast, full-featured terminal emulator inside Emacs.
;; Requires cmake and libtool-bin to compile the native module.
;; Install them: sudo dnf install cmake libtool (Fedora/Nobara)
;;              brew install cmake libtool (macOS)

(use-package vterm
  :commands vterm
  :bind ("C-c t" . my/vterm-toggle)
  :custom
  (vterm-max-scrollback 10000)
  (vterm-shell (or (executable-find "nu")
                   (executable-find "zsh")
                   shell-file-name))
  :config
  ;; Toggle vterm in a bottom window (like VS Code integrated terminal).
  (defun my/vterm-toggle ()
    "Toggle a vterm buffer in a bottom window."
    (interactive)
    (let ((buf (get-buffer "*vterm*")))
      (if (and buf (get-buffer-window buf))
          (delete-window (get-buffer-window buf))
        (if buf
            (display-buffer-in-side-window buf
              '((side . bottom) (slot . 0) (window-height . 0.3)))
          (let ((default-directory (or (project-root (project-current))
                                      default-directory)))
            (vterm)
            (let ((win (get-buffer-window (current-buffer))))
              (delete-window win)
              (display-buffer-in-side-window (get-buffer "*vterm*")
                '((side . bottom) (slot . 0) (window-height . 0.3)))))))))

  ;; Additional named vterm buffers
  (defun my/vterm-new ()
    "Open a new vterm with a unique name."
    (interactive)
    (vterm (generate-new-buffer-name "*vterm*"))))

;; Multi-vterm for managing multiple terminal instances
(use-package multi-vterm
  :after vterm
  :bind (("C-c T" . multi-vterm)))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 17. FILE SIDEBAR                                                  ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; Treemacs — file explorer sidebar, positioned on the RIGHT.
(use-package treemacs
  :defer t
  :bind (("C-c s" . treemacs)
         :map treemacs-mode-map
         ("C-c s" . treemacs))
  :custom
  (treemacs-position 'right)             ; sidebar on the RIGHT
  (treemacs-width 35)
  (treemacs-indentation 2)
  (treemacs-show-hidden-files t)
  (treemacs-is-never-other-window nil)
  :config
  (treemacs-follow-mode 1)              ; highlight current file
  (treemacs-filewatch-mode 1)           ; auto-refresh on file changes
  (treemacs-fringe-indicator-mode 'always)
  (treemacs-git-mode 'deferred))        ; show VCS status (works with vc-jj)

(use-package treemacs-nerd-icons
  :after treemacs
  :config (treemacs-load-theme "nerd-icons"))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 18. TOOLS                                                         ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; ── WakaTime — track coding activity ─────────────────────────────────
;; Requires the wakatime-cli binary. Install via your package manager
;; or see https://wakatime.com/terminal
;; Your API key goes in ~/.wakatime.cfg
(use-package wakatime-mode
  :diminish
  :config (global-wakatime-mode 1))

;; ── Elcord — Discord Rich Presence ───────────────────────────────────
;; Active whenever any emacs window (in any frame) is showing a buffer
;; whose major mode derives from prog-mode (i.e., code files).
;; Disconnect from Discord as soon as no code buffer is visible.
(use-package elcord
  :commands (elcord-mode)
  :config
  (setq elcord-display-buffer-details t  ; show file name
        elcord-use-major-mode-as-main-icon t
        elcord-editor-icon "emacs_icon"
        elcord-idle-message "Idle in Emacs...")

  (defun my/elcord-coding-visible-p ()
    "Return non-nil if any window in any currently shows a prog-mode buffer."
    (cl-some
     (lambda (frame)
       (cl-some
        (lambda (win)
          (with-current-buffer (window-buffer win)
            (derived-mode-p 'prog-mode)))
        (window-list frame)))
     (frame-list)))

  (defun my/elcord-auto-toggle ()
    "Enable elcord when a code buffers is visible, disable otherwise."
    (if (my/elcord-coding-visible-p)
        (unless elcord-mode (elcord-mode 1))
      (when elcord-mode (elcord-mode -1))))

  ;; Poll every 5 seconds to check if we should toggle elcord mode.
  (defvar my/elcord-timer nil
    "Timer object for periodically checking if Elcord should be toggled.")
  (when my/elcord-timer
    (cancel-timer my/elcord-timer))
  (setq my/elcord-timer
        (run-with-timer 5 5 #'my/elcord-auto-toggle )))

;; ── PDF viewing (GUI mode) ───────────────────────────────────────────
(use-package pdf-tools
  :if (display-graphic-p)
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :config (pdf-tools-install :no-query))

;; ── Rainbow mode — colorize color strings (#ff0000, rgb(), etc.) ─────
(use-package rainbow-mode
  :diminish
  :hook (prog-mode . rainbow-mode))

;; ── GitHub CLI integration (for PRs, Actions, etc.) ──────────────────
;; Since you use jj without colocation, forge/magit won't work.
;; Instead, use gh CLI from vterm or M-x compile:
;;   gh pr list, gh pr create, gh run list, gh run watch
;; Convenience functions:
(defun my/gh-pr-list ()
  "List GitHub PRs using gh CLI."
  (interactive)
  (compile "gh pr list" t))

(defun my/gh-actions-list ()
  "List GitHub Actions runs using gh CLI."
  (interactive)
  (compile "gh run list" t))

(defun my/gh-pr-create ()
  "Create a GitHub PR using gh CLI interactively in vterm."
  (interactive)
  (vterm)
  (vterm-send-string "gh pr create\n"))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 19. KEYBINDINGS                                                   ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; ── Summary of custom bindings ───────────────────────────────────────
;; M-up / M-down       → move line up/down
;; M-p / M-n           → move line up/down (terminal-friendly)
;; C-=                  → expand region
;; C-'                  → avy jump to char
;; M-o                  → ace-window (switch windows)
;; C-.                  → embark-act (contextual actions)
;; C-/                  → comment/uncomment line(s)
;; TAB (with region)    → indent region by one level
;; S-TAB (with region)  → unindent region by one level
;; C-c d               → ducplicate line
;; C-c l               → LSP prefix (C-c l r = rename, etc.)
;; C-c g g             → gptel chat (Copilot models)
;; C-c g s             → gptel send
;; C-c g m             → gptel menu (switch model)
;; C-c g a             → gptel add context
;; C-c c c             → copilot-chat
;; C-c c e/r/f/o/t/d   → copilot explain/review/fix/optimize/test/doc
;; C-c a c             → Claude Code (agent-shell)
;; C-c a a             → pick any agent
;; C-c a t             → toggle agent shell
;; C-c j               → majutsu (jj status)
;; C-c t               → toggle vterm at bottom
;; C-c T               → new vterm
;; C-c s               → treemacs sidebar (right)
;; C-c e               → emoji insert
;; C-s / C-r           → consult-line (search in buffer)
;; M-s r               → consult-ripgrep (project-wide search)
;; M-s t               → consult-todo (search TODOs)
;; M-y                  → consult-yank-pop (browse kill-ring)
;; C-x u               → vundo (visual undo tree)
;; C-h f/v/k/x/o       → helpful variants

;; ── Duplicate line (VS Code: Shift+Alt+Down) ────────────────────────
(defun my/duplicate-line ()
  "Duplicate the current line below."
  (interactive)
  (let ((col (current-column)))
    (save-excursion
      (move-beginning-of-line 1)
      (kill-line 1)
      (yank)
      (yank))
    (forward-line 1)
    (move-to-column col)))
(global-set-key (kbd "C-c d") #'my/duplicate-line)

;; ── Comment/uncomment (keep Emacs default: M-;) ─────────────────────
;; But also add the VS Code-like C-/ binding:
(global-set-key (kbd "C-c /") #'comment-line)

;; ── TAB / S-TAB region inden/unindent ───────────────────────────────
;; When a region is active:
;;   TAB     → indent all lines in region by one level (tab-width spaces)
;;   S-TAB   → unindent all lines in region by one level
;; When no region is active, TAB behaves normally (indent or complete).
;; The region stays active after the operation.

(defun my/indent-or-default ()
  "Indent by `tab-width' spaces. Else do default TAB.
  Work on region too."
  (interactive)
  (if (use-region-p)
      (let ((deactivate-mark nil))
        (indent-rigidly (region-beginning) (region-end) tab-width))
    ;; Fall through to whatever TAB normally does in this mode
    (indent-for-tab-command)))

(defun my/unindent ()
  "Unindent by `tab-width' spaces.
  Work on region too."
  (interactive)
  (if (use-region-p)
      (let ((deactivate-mark nil))
        (indent-rigidly (region-beginning) (region-end) (- tab-width)))
    ;; No region: unindent the current line
    (indent-rigidly (line-beginning-position) (line-end-position) (- tab-width))))

(global-set-key (kbd "<tab>")     #'my/indent-or-default)
(global-set-key (kbd "TAB")       #'my/indent-or-default)
(global-set-key (kbd "<backtab>") #'my/unindent)

;; ── Escape to quit (like VS Code) ───────────────────────────────────
(global-set-key (kbd "<escape>") #'keyboard-escape-quit)

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 20. GUI-SPECIFIC SETTINGS                                         ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; These run when a graphical frame exists.
(defun my/gui-setup (&optional frame)
  "Apply GUI-specific settings to FRAME."
  (when (display-graphic-p (or frame (selected-frame)))
    (with-selected-frame (or frame (selected-frame))
      ;; Switch theme to latte (light) for GUI frames.
      (setq catppuccin-flavor 'latte)
      (load-theme 'catppuccin t)

      ;; Font
      (set-face-attribute 'default nil
                          :family "JetBrainsMono Nerd Font"
                          :height 120     ; 12pt
                          :weight 'normal)
      ;; Ligatures (if your font supports them)
      (when (fboundp 'set-fontset-font)
        (set-fontset-font t 'unicode "JetBrainsMono Nerd Font"))

      ;; Smooth scrolling
      (pixel-scroll-precision-mode 1)

      ;; Frame opacity (optional, comment out if not wanted)
      ;; (set-frame-parameter nil 'alpha-background 95)

      ;; Fringe (thin indicators on left/right edge)
      (fringe-mode '(8 . 8))

      ;; diff-hl: use fringe in GUI (margin in terminal)
      (diff-hl-margin-mode -1)
      (diff-hl-flydiff-mode 1))))

;; ╔═══════════════════════════════════════════════════════════════════╗
;; ║ 21. DAEMON / FRAME HOOKS                                          ║
;; ╚═══════════════════════════════════════════════════════════════════╝

;; When running as a daemon, the init runs before any frame exists.
;; We use after-make-frame-functions to apply per-frame settings.
(if (daemonp)
    (add-hook 'after-make-frame-functions #'my/gui-setup)
  (my/gui-setup))

;; ── Server name (for emacsclient) ────────────────────────────────────
(setq server-name "main")

;; ── Startup message ──────────────────────────────────────────────────
(defun my/display-startup-time ()
  "Show startup time in the echo area."
  (message "Emacs loaded in %.2f seconds with %d garbage collections."
           (float-time (time-subtract after-init-time before-init-time))
           gcs-done))
(add-hook 'emacs-startup-hook #'my/display-startup-time)

(provide 'init)
;;; init.el ends here
