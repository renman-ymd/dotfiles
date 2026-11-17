;;; consult.el --- Extra: consult  -*- lexical-binding: t; -*-

(use-package consult
  :bind (("C-s"     . consult-line)
         ("C-r"     . consult-line)
         ("C-x b"   . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("M-g g"   . consult-goto-line)
         ("M-g M-g" . consult-goto-line)
         ("M-g o"   . consult-outline)
         ("M-g i"   . consult-imenu)
         ("M-s r"   . consult-ripgrep)
         ("M-s f"   . consult-find)
         ("M-s l"   . consult-line)
         ("M-s g"   . consult-grep)
         ("M-y"     . consult-yank-pop))
  :custom
  (xref-show-xrefs-function #'consult-xref)
  (xref-show-definitions-function #'consult-xref))

;;; consult.el ends here
