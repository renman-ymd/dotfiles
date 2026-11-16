;;; helpful.el --- Extra: helpful  -*- lexical-binding: t; -*-

(use-package helpful
  :bind (("C-h f" . helpful-callable)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)
         ("C-h x" . helpful-command)
         ("C-h o" . helpful-symbol)))

;;; helpful.el ends here
