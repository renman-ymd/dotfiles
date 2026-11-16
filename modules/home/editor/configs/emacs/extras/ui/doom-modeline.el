;;; doom-modeline.el --- Extra: doom-modeline  -*- lexical-binding: t; -*-

(use-package doom-modeline
  :custom
  (doom-modeline-buffer-file-name-style 'relative-from-project)
  (doom-modeline-buffer-encoding nil)
  (doom-modeline-vcs-max-length 20)
  (doom-modeline-workspace-name nil)
  :init (doom-modeline-mode 1))

;;; doom-modeline.el ends here
