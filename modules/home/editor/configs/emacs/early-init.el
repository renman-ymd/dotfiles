;;; early-init.el --- Pre-initialization -*- lexical-binding: t; -*-
;;; Commentary:
;; Runs before init.el. Used for GC tuning, disabling UI chrome early
;; (before frames are drawn), and setting up the package system.
;;; Code:

;; ── GC tuning ────────────────────────────────────────────────────────
;; Raise GC threshold during startup for speed; restore it afterward.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)
(add-hook 'emacs-startup-hook
          (lambda ()
            ;; 16 MB is a good runtime threshold (default is 800 KB).
            (setq gc-cons-threshold (* 16 1024 1024)
                  gc-cons-percentage 0.1)))

;; ── Native compilation ───────────────────────────────────────────────
(when (featurep 'native-compile)
  (setq native-comp-async-report-warnings-errors 'silent
        native-comp-deferred-compilation t))

;; ── Disable UI chrome before first frame is drawn ────────────────────
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(internal-border-width . 0) default-frame-alist)

;; GUI-specific frame defaults (ignored in -nw mode)
(push '(font . "JetBrainsMono Nerd Font-12") default-frame-alist)
(push '(width . 140) default-frame-alist)
(push '(height . 45) default-frame-alist)

;; ── Package system ───────────────────────────────────────────────────
;; We use built-in package.el + use-package. Prevent package.el from
;; loading packages before init.el runs (we handle it ourselves).
(setq package-enable-at-startup t)

(provide 'early-init)
;;; early-init.el ends here
