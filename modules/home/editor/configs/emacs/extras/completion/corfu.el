;;; corfu.el --- Extra: corfu  -*- lexical-binding: t; -*-

(use-package corfu
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.15)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  (corfu-popupinfo-delay '(0.5 . 0.2))
  :init
  (global-corfu-mode 1)
  (corfu-popupinfo-mode 1))

;;; corfu.el ends here
