;;; early-init.el --- Editor core, before the first frame  -*- lexical-binding: t; -*-

(defvar native-comp-async-report-warnings-errors)

(setq gc-cons-threshold most-positive-fixnum)
(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 16 1024 1024))))

(setq inhibit-startup-message t
      initial-scratch-message nil
      native-comp-async-report-warnings-errors 'silent)

(push '(menu-bar-lines . 0) default-frame-alist)

;;; early-init.el ends here
