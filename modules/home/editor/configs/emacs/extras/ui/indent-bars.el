;;; indent-bars.el --- Extra: indent-bars  -*- lexical-binding: t; -*-

(use-package indent-bars
  :hook (prog-mode . indent-bars-mode)
  :custom
  (indent-bars-treesit-support t)
  (indent-bars-no-descend-string t))

;;; indent-bars.el ends here
