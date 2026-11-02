;;; early-init.el --- Lightweight early-init -*- lexical-binding: t; -*-
;;; Commentary:
;; Minimal early-init for fast one-off editing (commit messages, configs, etc.)
;;; Code:

(setq gc-cons-threshold (* 8 1024 1024)
      gc-cons-percentage 0.1)

(setq inhibit-startup-message t
      initial-scratch-message nil)

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

(setq package-enable-at-startup t)

(provide 'early-init)
;;; early-init.el ends here
