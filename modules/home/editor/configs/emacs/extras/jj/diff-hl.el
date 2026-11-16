;;; diff-hl.el --- Extra: diff-hl  -*- lexical-binding: t; -*-

(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode)
         (text-mode . diff-hl-mode)
         (conf-mode . diff-hl-mode)
         (dired-mode . diff-hl-dired-mode))
  :config (diff-hl-margin-mode 1))

;;; diff-hl.el ends here
