;;; init.el --- Editor core  -*- lexical-binding: t; -*-

;;; Commentary:

;; The configuration every machine gets, for terminal frames only.  Nix
;; installs every package, so nothing here downloads anything.  A project
;; brings its own languages through its add-on, and optional packages
;; live one per file under extras/.

;;; Code:

(require 'seq)

(defvar catppuccin-flavor)
(defvar treesit-auto-install-grammar)
(defvar eglot-server-programs)
(defvar savehist-file)
(defvar save-place-file)
(defvar recentf-save-file)
(declare-function global-wakatime-mode "wakatime-mode")

;;;; Editing

(set-language-environment "UTF-8")
(setq make-backup-files nil
      auto-save-default nil
      create-lockfiles nil
      ring-bell-function #'ignore
      use-short-answers t
      custom-file (locate-user-emacs-file "custom.el"))
(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 80)

(electric-pair-mode 1)
(delete-selection-mode 1)
(column-number-mode 1)
(show-paren-mode 1)
(global-auto-revert-mode 1)
(global-hl-line-mode 1)
(xterm-mouse-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'conf-mode-hook #'display-line-numbers-mode)

;; The launchd daemon still starts a bare Emacs 30 on this file, without
;; the packages Nix wraps around emacs31-nox.
(when (locate-library "catppuccin-theme")
  (setq catppuccin-flavor 'macchiato)
  (load-theme 'catppuccin t))

;;;; Keys

(defun my/duplicate-line ()
  "Duplicate the current line below itself."
  (interactive)
  (let ((column (current-column))
        (line (buffer-substring (line-beginning-position) (line-end-position))))
    (end-of-line)
    (newline)
    (insert line)
    (move-to-column column)))

(defun my/indent-or-default ()
  "Indent the region by one step when it is active, else do what TAB does."
  (interactive)
  (if (use-region-p)
      (let ((deactivate-mark nil))
        (indent-rigidly (region-beginning) (region-end) tab-width))
    (indent-for-tab-command)))

(defun my/unindent ()
  "Remove one indentation step from the region or the current line."
  (interactive)
  (let ((deactivate-mark nil)
        (start (if (use-region-p) (region-beginning) (line-beginning-position)))
        (end (if (use-region-p) (region-end) (line-end-position))))
    (indent-rigidly start end (- tab-width))))

(global-set-key (kbd "C-c d") #'my/duplicate-line)
(global-set-key (kbd "C-c /") #'comment-line)
(global-set-key (kbd "<escape>") #'keyboard-escape-quit)
(dolist (map (list prog-mode-map text-mode-map))
  (define-key map (kbd "TAB") #'my/indent-or-default)
  (define-key map (kbd "<backtab>") #'my/unindent))

;;;; Core languages

(setq treesit-auto-install-grammar 'never)
(autoload 'markdown-ts-mode "markdown-ts-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-ts-mode))
(add-to-list 'auto-mode-alist '("\\.ya?ml\\'" . yaml-ts-mode))
(add-to-list 'auto-mode-alist '("\\.toml\\'" . toml-ts-mode))
(add-to-list 'auto-mode-alist '("\\.nu\\'" . nushell-mode))

(when (locate-library "simpc-mode")
  (autoload 'simpc-mode "simpc-mode" nil t)
  (add-to-list 'auto-mode-alist '("\\.[hc]\\(pp\\)?\\'" . simpc-mode)))

;;;; Language servers, on demand

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(nushell-mode . ("nu" "--lsp")))
  (add-to-list 'eglot-server-programs '((simpc-mode :language-id "c") . ("clangd"))))

(defun my/harper ()
  "Check the English of this buffer with Harper."
  (interactive)
  (require 'eglot)
  (let ((eglot-server-programs `((,major-mode . ("harper-ls" "--stdio")))))
    (call-interactively #'eglot)))

;;;; Extras

(dolist (file (and (file-directory-p (locate-user-emacs-file "extras"))
                   (directory-files-recursively
                    (locate-user-emacs-file "extras") "\\.el\\'")))
  (load file nil t))

;;;; Server

(defvar my/last-frame-time (current-time)
  "When a client frame was last seen on this server.")

(defun my/unsaved-file-buffers-p ()
  "Non-nil when a buffer visiting a file has unsaved changes."
  (seq-some (lambda (buffer)
              (and (buffer-file-name buffer) (buffer-modified-p buffer)))
            (buffer-list)))

(defun my/stop-when-idle ()
  "Stop this server after four hours without a client frame.
A file with unsaved changes keeps it alive."
  (if (cdr (frame-list))
      (setq my/last-frame-time (current-time))
    (when (and (> (float-time (time-since my/last-frame-time)) (* 4 60 60))
               (not (my/unsaved-file-buffers-p)))
      (kill-emacs))))

(when (daemonp)
  ;; Each server keeps its own history, so that the last one to exit does
  ;; not overwrite the others'.
  (let ((state (locate-user-emacs-file
                (format "servers/%s/"
                        (if (stringp (daemonp))
                            (file-name-nondirectory (daemonp))
                          "server")))))
    (make-directory state t)
    (setq savehist-file (expand-file-name "history" state)
          save-place-file (expand-file-name "places" state)
          recentf-save-file (expand-file-name "recentf" state)))
  (savehist-mode 1)
  (save-place-mode 1)
  (recentf-mode 1)
  (run-with-timer 600 600 #'my/stop-when-idle))

(when (and (locate-library "wakatime-mode")
           (file-exists-p "~/.wakatime.cfg"))
  (require 'wakatime-mode)
  (global-wakatime-mode 1))

;;;; Project add-on

(when-let* ((dir (getenv "EMACS_ADDON_TREESIT_DIR"))
            ((file-directory-p dir)))
  (add-to-list 'treesit-extra-load-path dir))

(defvar my/addon-loaded nil
  "Non-nil once the add-on of this server's project is loaded.")

(when-let* ((file (getenv "EMACS_ADDON_INIT"))
            ((file-readable-p file)))
  (load file nil t)
  (setq my/addon-loaded t))

(provide 'init)
;;; init.el ends here
