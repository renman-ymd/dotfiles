;;; multiple-cursors.el --- Extra: multiple-cursors  -*- lexical-binding: t; -*-

(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C->"         . mc/mark-next-like-this)
         ("C-<"         . mc/mark-previous-like-this)
         ("C-c C-<"     . mc/mark-all-like-this)
         ("C-c C->"     . mc/mark-all-dwim)
         ("C-\""        . mc/skip-to-next-like-this)
         ("C-:"         . mc/skip-to-previous-like-this)
         ("C-c C-,"     . mc/unmark-next-like-this))
  :hook
  ;; hl-line hides the extra cursors on its line.
  ((multiple-cursors-mode-enabled . (lambda () (global-hl-line-mode -1)))
   (multiple-cursors-mode-disabled . (lambda () (global-hl-line-mode 1)))))

;;; multiple-cursors.el ends here
