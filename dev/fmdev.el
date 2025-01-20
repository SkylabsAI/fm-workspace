;;; fmdev.el --- Emacs helpers for FM devs -*- lexical-binding:t -*-

;; Inspired from file dev/tools/coqdev.el in the Coq repository.
;; Copyright (C) 2018-2024 The Coq Development Team

(require 'seq)
(require 'subr-x)

(defun workspace-directory ()
  "Return the `default-directory' of our Dune/Coq workspace."
  (let ((dir (seq-some
              (lambda (f) (locate-dominating-file default-directory f))
              '("dune-workspace" "fmdeps"))))
    (when dir (expand-file-name dir))))

(defvar coq-prog-args)
(defvar coq-prog-name)

;; Lets us detect whether there are file local variables
;; even though PG sets it with `setq' when there's a _CoqProject.
;; Also makes sense generally, so might make it into PG someday.
(make-variable-buffer-local 'coq-prog-args)
(setq-default coq-prog-args nil)

(defun coqdev-setup-proofgeneral ()
  "Setup Proofgeneral variables for Coq development.

Note that this function is executed before _CoqProject is read if it exists."
  (let ((dir (workspace-directory)))
    (when dir
     (setq-local coq-prog-name
      (concat dir "_build/default/fmdeps/coq/dev/shim/coqtop")))))
(add-hook 'hack-local-variables-hook #'coqdev-setup-proofgeneral)

(provide 'fmdev)
;;; fmdev ends here
