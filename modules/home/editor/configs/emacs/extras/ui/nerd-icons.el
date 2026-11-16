;;; nerd-icons.el --- Extra: nerd-icons  -*- lexical-binding: t; -*-

(use-package nerd-icons)

(use-package nerd-icons-dired
  :hook (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-completion
  :init (nerd-icons-completion-mode 1))

;;; nerd-icons.el ends here
