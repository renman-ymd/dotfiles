;;; vundo.el --- Extra: vundo  -*- lexical-binding: t; -*-

(use-package vundo
  :bind ("C-x u" . vundo)
  :config (setq vundo-glyph-alist vundo-unicode-symbols))

;;; vundo.el ends here
