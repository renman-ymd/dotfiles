;;; vc-jj.el --- Extra: vc-jj  -*- lexical-binding: t; -*-

(defun my/project-find-jj (dir)
  "Take the directory holding `.jj' at or above DIR as a project root."
  (when-let* ((root (locate-dominating-file dir ".jj")))
    (cons 'transient root)))

(use-package vc-jj
  :demand t
  :config
  (add-to-list 'vc-handled-backends 'JJ)
  (add-hook 'project-find-functions #'my/project-find-jj))

;;; vc-jj.el ends here
