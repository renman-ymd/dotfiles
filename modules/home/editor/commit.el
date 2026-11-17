;;; commit.el --- The jj description window  -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded by a plain `emacs -nw -Q', so it uses built-in libraries only.
;; The header line checks the message against the commit rules: a title of
;; at most 72 characters (85 and 14 words at the very most, the area not
;; counted), a body of at most two paragraphs of three lines, and a footer
;; of trailers after two blank lines.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defconst my/commit-title-soft 72)
(defconst my/commit-hard 85)
(defconst my/commit-title-words 14)
(defconst my/commit-area-regexp "\\`[a-z0-9._/, -]+: ")

(defvar my/commit-recent-titles 'unknown
  "Recent titles of the repository, or `unknown' before the first lookup.")

(defun my/commit-recent-titles ()
  "Return the recent jj titles of the repository the editor started in."
  (when (eq my/commit-recent-titles 'unknown)
    (setq my/commit-recent-titles
          ;; The description file is in a temporary directory, so jj runs
          ;; where the editor started.
          (let ((default-directory command-line-default-directory))
            (with-temp-buffer
              (ignore-errors
                (call-process "jj" nil (list t nil) nil
                              "log" "--no-graph" "-r" "ancestors(@, 300)"
                              "-T" "description.first_line() ++ \"\\n\""))
              (split-string (buffer-string) "\n" t)))))
  my/commit-recent-titles)

(defun my/commit-areas ()
  "Return the areas of the recent titles, most frequent first."
  (let ((case-fold-search nil)
        (counts (make-hash-table :test #'equal))
        areas)
    (dolist (title (my/commit-recent-titles))
      (when (string-match "\\`\\([a-z0-9._/-]+\\): " title)
        (cl-incf (gethash (match-string 1 title) counts 0))))
    (maphash (lambda (area count) (push (cons area count) areas)) counts)
    (mapcar #'car (sort areas (lambda (a b) (> (cdr a) (cdr b)))))))

(defun my/commit-uses-areas-p ()
  "Non-nil when most recent titles of the repository start with an area."
  (let ((titles (my/commit-recent-titles))
        (case-fold-search nil))
    (and titles
         (> (* 2 (cl-count-if (lambda (title)
                                (string-match-p my/commit-area-regexp title))
                              titles))
            (length titles)))))

(defun my/commit-area-capf ()
  "Complete the area on the first line, before its colon."
  (when (and (= (line-number-at-pos) 1)
             (not (string-search ":" (buffer-substring (line-beginning-position)
                                                       (point)))))
    (list (line-beginning-position) (point)
          (completion-table-dynamic (lambda (_) (my/commit-areas)))
          :exclusive 'no)))

(defun my/commit-parts (text)
  "Split TEXT into (TITLE BODY-PARAGRAPHS FOOTER-LINES).
Lines starting with \"JJ:\" are comments and dropped.  The footer is
what follows the first two blank lines in a row."
  (let* ((lines (cl-remove-if (lambda (line) (string-prefix-p "JJ:" line))
                              (split-string text "\n")))
         (title (or (car lines) ""))
         (rest (string-trim-right (string-join (cdr lines) "\n") "[ \n]+"))
         ;; Two blank lines right under the title: a footer with no body.
         (split (if (string-prefix-p "\n\n" rest) 0 (string-match "\n\n\n+" rest)))
         (body (if split (substring rest 0 split) rest))
         (footer (if split (string-trim-left (substring rest split) "\n+") "")))
    (list title
          (mapcar (lambda (paragraph) (split-string paragraph "\n" t))
                  (split-string body "\n\n+" t))
          (split-string footer "\n" t))))

(defun my/commit-problems (text use-areas)
  "Return (ERRORS . WARNINGS) for the commit message TEXT.
USE-AREAS says whether the repository's titles start with an area."
  (pcase-let* ((`(,title ,paragraphs ,footer) (my/commit-parts text))
               (case-fold-search nil)
               (summary (if (string-match my/commit-area-regexp title)
                            (substring title (match-end 0))
                          title))
               (errors nil)
               (warnings nil))
    (when (> (length summary) my/commit-hard)
      (push (format "title is %d characters (max %d)" (length summary) my/commit-hard)
            errors))
    (when (> (length (split-string summary)) my/commit-title-words)
      (push (format "title is %d words (max %d)" (length (split-string summary))
                    my/commit-title-words)
            errors))
    (when (and (> (length title) my/commit-title-soft)
               (<= (length summary) my/commit-hard))
      (push (format "title is %d characters (aim for %d)" (length title)
                    my/commit-title-soft)
            warnings))
    (when use-areas
      (unless (string-match-p my/commit-area-regexp title)
        (push "title is not `area: summary'" warnings))
      (when (string-match-p "[A-Z]" title)
        (push "capitals in the title (proper names only)" warnings)))
    (when (> (length paragraphs) 2)
      (push (format "%d paragraphs (max 2)" (length paragraphs)) warnings))
    (when (cl-some (lambda (paragraph) (> (length paragraph) 3)) paragraphs)
      (push "a paragraph has more than 3 lines" warnings))
    (when (cl-some (lambda (line) (> (length line) my/commit-hard))
                   (apply #'append paragraphs))
      (push (format "a body line is over %d characters" my/commit-hard) errors))
    (when (cl-some (lambda (line) (not (string-match-p "\\`[A-Za-z-]+: ." line)))
                   footer)
      (push "the footer holds a line that is no `Key: value' trailer" warnings))
    (cons (nreverse errors) (nreverse warnings))))

(defun my/commit-hint ()
  "Return the header line: the problems of the message, or \"ok\"."
  (pcase-let ((`(,errors . ,warnings)
               (my/commit-problems
                (buffer-substring-no-properties (point-min) (point-max))
                (my/commit-uses-areas-p))))
    (cond (errors (propertize (string-join (append errors warnings) " | ")
                              'face 'error))
          (warnings (propertize (string-join warnings " | ") 'face 'warning))
          (t (propertize "ok" 'face 'success)))))

(define-derived-mode my/jjdesc-mode text-mode "jj-desc"
  "Major mode for jj description buffers."
  (setq-local fill-column my/commit-title-soft)
  (display-fill-column-indicator-mode 1)
  (font-lock-add-keywords nil '(("^JJ:.*$" 0 'font-lock-comment-face t)))
  (add-hook 'completion-at-point-functions #'my/commit-area-capf nil t)
  (setq-local header-line-format '(:eval (my/commit-hint))))

(add-to-list 'auto-mode-alist '("\\.jjdescription\\'" . my/jjdesc-mode))

(defvar eglot-server-programs)
(defvar eglot-workspace-configuration)

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((my/jjdesc-mode :language-id "jjdescription")
                 . ("harper-ls" "--stdio")))
  ;; Titles start with a lowercase area.
  (setq-default eglot-workspace-configuration
                '(:harper-ls (:linters (:SentenceCapitalization :json-false)))))

(defun my/commit-harper ()
  "Check the English of the message with Harper."
  (interactive)
  (call-interactively #'eglot))

(provide 'commit)
;;; commit.el ends here
