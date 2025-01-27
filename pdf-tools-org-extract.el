;;; pdf-tools-org-extract.el --- Extract PDF annotations to org-mode  -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Paul D. Nelson

;; Author: Paul D. Nelson <nelson.paul.david@gmail.com>
;; Version: 0.1
;; URL: https://github.com/ultronozm/pdf-tools-org-extract.el
;; Package-Requires: ((emacs "27.1") (pdf-tools "1.0"))
;; Keywords: convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides functionality to extract text annotations from PDF files
;; (viewed with pdf-tools) into org-mode buffers.  The main entry point is the
;; command `pdf-tools-org-extract-annotations'.

;;; Code:

(require 'pdf-tools)
(require 'pdf-annot)
(require 'org)

;;;; Customization

(defgroup pdf-tools-org-extract nil
  "Extract PDF annotations to `org-mode'."
  :group 'pdf-tools
  :prefix "pdf-tools-org-extract-")

(defcustom pdf-tools-org-extract-format 'latex-source-block
  "Format to use when extracting annotations.
See `pdf-tools-org-extract-format-handlers' for available formats."
  :type '(choice (const :tag "LaTeX source block" latex-source-block)
                 (const :tag "Plain text" plain))
  :group 'pdf-tools-org-extract)

(defcustom pdf-tools-org-extract-buffer-name-template "*%s-text-notes*"
  "Template for naming extraction buffers.
%s is replaced with the PDF buffer name."
  :type 'string
  :group 'pdf-tools-org-extract)

(defcustom pdf-tools-org-extract-header-template "#+TITLE: Text Notes from %s\n\n"
  "Template for the header of extraction buffers.
%s is replaced with the PDF buffer name."
  :type 'string
  :group 'pdf-tools-org-extract)

;;;; Format handlers

(defun pdf-tools-org-extract--format-latex (content)
  "Format annotation CONTENT as a LaTeX source block."
  (concat "#+begin_src latex\n"
          content
          "\n#+end_src"))

(defun pdf-tools-org-extract--format-plain (content)
  "Format annotation CONTENT as plain text."
  content)

(defvar pdf-tools-org-extract-format-handlers
  '((latex-source-block . pdf-tools-org-extract--format-latex)
    (plain . pdf-tools-org-extract--format-plain))
  "Alist mapping format types to handler functions.
Each handler function should take a content string and return a
formatted string.")

;;;; Core functionality

(defun pdf-tools-org-extract--format-content (content)
  "Format annotation CONTENT according to `pdf-tools-org-extract-format'."
  (let ((handler (cdr (assq pdf-tools-org-extract-format
                            pdf-tools-org-extract-format-handlers))))
    (if handler
        (funcall handler content)
      (error "No handler found for format %s" pdf-tools-org-extract-format))))

;;;###autoload
(defun pdf-tools-org-extract-annotations ()
  "Extract text annotations from current PDF buffer to an `org-mode' buffer."
  (interactive)
  (pdf-util-assert-pdf-buffer)
  (let* ((pdf-name (buffer-name))
         (org-buffer (generate-new-buffer
                      (format pdf-tools-org-extract-buffer-name-template
                              pdf-name)))
         (annotations (pdf-annot-getannots nil 'text)))

    (unless annotations
      (user-error "No text annotations found in PDF"))

    ;; Sort annotations by page
    (setq annotations
          (sort annotations
                (lambda (a b)
                  (< (pdf-annot-get a 'page)
                     (pdf-annot-get b 'page)))))

    (with-current-buffer org-buffer
      (org-mode)
      (insert (format pdf-tools-org-extract-header-template pdf-name))

      ;; Process each annotation
      (dolist (annot annotations)
        (let ((page (pdf-annot-get annot 'page))
              (contents (pdf-annot-get annot 'contents)))
          (when contents  ; Skip if no content
            (insert (format "* Page %d\n" page)
                    (pdf-tools-org-extract--format-content contents)
                    "\n\n"))))

      (goto-char (point-min))
      (pop-to-buffer (current-buffer))
      (message "Extracted %d annotations" (length annotations)))))

;;;###autoload
(defun pdf-tools-org-extract-enable ()
  "Enable pdf-tools-org-extract by binding the default key."
  (define-key pdf-view-mode-map (kbd "C-c C-a e")
              #'pdf-tools-org-extract-annotations))

(provide 'pdf-tools-org-extract)
;;; pdf-tools-org-extract.el ends here
