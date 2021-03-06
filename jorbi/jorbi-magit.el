;;; jorbi-magit.el ---
;;
;; Filename: jorbi-magit.el
;; Description: Functions for magit.
;; Author: Jordon Biondo
;; Package-Requires: ()
;; Last-Updated: Mon Feb  9 11:09:26 2015 (-0500)
;;           By: Jordon Biondo
;;     Update #: 5
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:
(require 'magit)

(defun jorbi-magit/-line-region-of-section-at-point ()
  "If point is in a hunk return a list of info about the hunk.

The info is like (expanded-file-name starting-line number-of-lines-show)"
  (let* ((section (magit-current-section))
         (context-type (magit-section-context-type section)))
    (when (and (member 'hunk context-type))
      (let* ((info
              (mapcar 'string-to-number
                      (split-string
                       (second (split-string
                                (magit-section-info
                                 (magit-current-section))
                                "[ @]" t))
                       ",")))
             (start-line (car info))
             (line-count (or (and (cdr info) (cadr info)) 1)))
        (let ((parent (magit-section-parent section)))
          (while (and parent
                      (not (equal (magit-section-type parent)
                                  'diff)))
            (setq magit-section-parent parent))
          (list (expand-file-name (magit-section-info parent))
                start-line
                line-count))))))

(defmacro define-magit-unstaged-hunk-action (name args &optional docstring &rest body)
  "NAME will be command that executes BODY in a way that has access to the beginning
and end of the region shown by the unstaged magit hunk at point.

The function will automatically open the hunks file, evaluated the body, and then
save the file and refresh the magit status buffer.

Args needs to be in the form (BEG END) where BEG and END are symbols that will be bound
to the regions beginning and end respectively.

In this example, the function `cleanup-this-hunk' is defined as a function
that deletes the trailing whitespace in the current unstaged magit hunk:

  (define-magit-unstaged-hunk-action cleanup-this-hunk (beg end)
    \"Delete trailing whitespace in the current unstaged magit hunk.\"
    (delete-trailing-whitespace beg end))

\(fn NAME (BEG END) &optional DOCSTRING &rest BODY)"
  (declare (indent-defun) (doc-string 3))
  (unless (and (= (length args) 2)
               (symbolp (car args))
               (symbolp (cadr args)))
    (error "Invalid args format to `define-magit-unstaged-hunk-action', see doc."))
  (let ((docstring (if (car-safe docstring) "" docstring))
        (body (append (and (car-safe docstring) (list docstring)) body))
        (file-sym (make-symbol "file-name"))
        (start-line-sym (make-symbol "starting-line"))
        (total-lines-sym (make-symbol "total-lines-shown"))
        (area-sym (make-symbol "hunk-data")))
    `(defun ,name ()
       ,docstring
       (interactive)
       (let ((,area-sym (jorbi-magit/-line-region-of-section-at-point)))
         (if (and ,area-sym (member 'unstaged (magit-section-context-type (magit-current-section))))
             (destructuring-bind (,file-sym ,start-line-sym ,total-lines-sym) ,area-sym
               (save-some-buffers)
               (with-current-buffer (find-file-noselect ,file-sym)
                 (save-excursion
                   (let ((,(car args) (progn (goto-char (point-min))
                                             (forward-line (1- ,start-line-sym))
                                             (point-at-bol)))
                         (,(cadr args) (progn (forward-line (1- ,total-lines-sym))
                                              (point-at-eol))))
                     ,@body))
                 (save-buffer))
               (magit-refresh))
           (message "Cannot perform. Point is not on an unstaged hunk."))))))

(defconst jorbi-magit/font-lock-keywords
  '(("\\((\\)\\(define-magit-unstaged-hunk-action\\)\\_>[ \t']*\\(\\(?:\\sw\\|\\s_\\)+\\)?"
     (2 font-lock-keyword-face)
     (3 font-lock-function-name-face nil t))))
(font-lock-add-keywords 'emacs-lisp-mode jorbi-magit/font-lock-keywords)

(define-magit-unstaged-hunk-action jorbi-magit/cleanup-this-hunk (beg end)
  "Delete trailing whitespace in the current unstaged magit hunk."
  (delete-trailing-whitespace beg end))

(provide 'jorbi-magit)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; jorbi-magit.el ends here
