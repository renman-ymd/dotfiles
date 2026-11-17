;;; orderless.el --- Extra: orderless  -*- lexical-binding: t; -*-

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;;; orderless.el ends here
