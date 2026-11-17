;;; tui-caret.el --- Extra: tui-caret  -*- lexical-binding: t; -*-

;; A terminal frame ignores `cursor-type', so the caret's shape is set with
;; the DECSCUSR escape: 6 is a steady bar, 0 the terminal's own default.

(defun my/tui-caret (shape &optional terminal)
  "Send the DECSCUSR sequence for SHAPE to TERMINAL."
  (send-string-to-terminal (format "\e[%d q" shape) terminal))

(add-hook 'tty-setup-hook (lambda () (my/tui-caret 6)))
(add-hook 'delete-frame-functions
          (lambda (frame)
            (unless (display-graphic-p frame)
              (my/tui-caret 0 (frame-terminal frame)))))
(add-hook 'kill-emacs-hook (lambda () (my/tui-caret 0)))

;;; tui-caret.el ends here
