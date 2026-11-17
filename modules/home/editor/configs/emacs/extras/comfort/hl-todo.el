;;; hl-todo.el --- Extra: hl-todo  -*- lexical-binding: t; -*-

(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :custom
  (hl-todo-keyword-faces
   '(("TODO"    . (:foreground "#f9e2af" :weight bold))
     ("FIXME"   . (:foreground "#f38ba8" :weight bold))
     ("BUG"     . (:foreground "#f38ba8" :weight bold))
     ("HACK"    . (:foreground "#fab387" :weight bold))
     ("NOTE"    . (:foreground "#a6e3a1" :weight bold))
     ("REVIEW"  . (:foreground "#89b4fa" :weight bold))
     ("PERF"    . (:foreground "#cba6f7" :weight bold))
     ("WARNING" . (:foreground "#fab387" :weight bold))
     ("DEPRECATED" . (:foreground "#6c7086" :strike-through t)))))

;;; hl-todo.el ends here
