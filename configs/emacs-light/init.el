;;; init.el --- Lightweight Emacs config -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Designed for quick, one-off editing: commit messages, config files,
;; shell scripts, etc. No LSP, no AI, no heavy packages.
;;
;; Usage:
;;   emacs -nw --init-dir ~/.config/emacs-light <file>
;;   Set as EDITOR/VISUAL in your shell.
;;
;;; Code:

;; ── Package system (minimal) ─────────────────────────────────────────
(require 'package)
(setq package-archives
      '(("melpa"  . "https://melpa.org/packages/")
        ("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(require 'use-package)
(setq use-package-always-ensure t)

;; ── Core ─────────────────────────────────────────────────────────────
(set-language-environment "UTF-8")
(setq make-backup-files nil
      auto-save-default nil
      create-lockfiles nil
      custom-file (expand-file-name "custom.el" user-emacs-directory)
      ring-bell-function 'ignore
      use-short-answers t)

;; ── Editing ──────────────────────────────────────────────────────────
(setq-default indent-tabs-mode nil
              tab-width 4)
(electric-pair-mode 1)
(delete-selection-mode 1)
(column-number-mode 1)
(show-paren-mode 1)
(setq show-paren-delay 0)

;; Line numbers
(setq display-line-numbers-type t)       ; absolute for quick editing
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'conf-mode-hook #'display-line-numbers-mode)

;; ── Clipboard ────────────────────────────────────────────────────────
(setq select-enable-clipboard t
      select-enable-primary t)
(use-package xclip
  :config (xclip-mode 1))

;; ── Theme (catppuccin, same as main config) ──────────────────────────
(use-package catppuccin-theme
  :config
  (setq catppuccin-flavor 'macchiato)
  (load-theme 'catppuccin t))

;; ── Minimal completion ───────────────────────────────────────────────
;; Use built-in fido-mode (a lightweight icomplete alternative).
(fido-vertical-mode 1)

;; ── Which-key (still useful even in light mode) ──────────────────────
(use-package which-key
  :config
  (setq which-key-idle-delay 0.5)
  (which-key-mode 1))

;; ── Better hl-todo (highlight TODOs even in quick edits) ─────────────
(use-package hl-todo
  :hook (prog-mode . hl-todo-mode))

;; ── Move lines ───────────────────────────────────────────────────────
(use-package move-text
  :config (move-text-default-bindings))

;; ── Tree-sitter (built-in, for better syntax highlighting) ───────────
(use-package treesit-auto
  :config
  (setq treesit-auto-install 'prompt)
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode 1))

;; ── Jujutsu awareness ────────────────────────────────────────────────
;; At minimum, recognize jj repos for project detection.
(use-package vc-jj)

;; ── Markdown (for editing READMEs, etc.) ─────────────────────────────
(use-package markdown-mode
  :mode "\\.md\\'")

;; ── YAML/TOML (common config formats) ────────────────────────────────
(use-package yaml-mode :mode "\\.ya?ml\\'")

;; ── Nix ──────────────────────────────────────────────────────────────
(use-package nix-mode :mode "\\.nix\\'")

;; ── Duplicate line ───────────────────────────────────────────────────
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

;; ── Comment/uncomment (VS Code Ctrl+: on French AZERTY) ──────────────
(global-set-key (kbd "C-c /") #'comment-line)

;; ── TAB / S-TAB region inden/unindent ───────────────────────────────
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

;; ── Startup time ─────────────────────────────────────────────────────
(add-hook 'emacs-startup-hook
          (lambda ()
            (message "Emacs-light loaded in %.2f seconds."
                     (float-time (time-subtract after-init-time before-init-time)))))

(provide 'init)
;;; init.el ends here
