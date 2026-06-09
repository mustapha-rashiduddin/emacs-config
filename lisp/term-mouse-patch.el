;;; tmux-mouse-patch.el --- Terminal/tmux Ctrl-mouse support -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This makes Ctrl-left-click and Ctrl-right-click work in terminal Emacs
;; when running through Docker/tmux.
;;
;; It:
;;   1. enables xterm mouse decoding
;;   2. kills Emacs' built-in C-mouse-1 buffer menu
;;   3. maps Ctrl-left-click to my/org-jump-drill-down
;;   4. maps Ctrl-right-click to my/org-jump-surface-up
;;   5. works both with Evil/Vim mode on and off
;;
;; The tmux side still needs mouse forwarding in flake.nix.

;;; Code:

(unless (display-graphic-p)
  ;; Make terminal Emacs decode xterm mouse events.
  (require 'xt-mouse)
  (xterm-mouse-mode 1)

  ;; Allow the commands when:
  ;;   1. Evil is not installed/loaded, OR
  ;;   2. Evil is globally disabled, OR
  ;;   3. Evil is disabled in this buffer, OR
  ;;   4. Evil is enabled and currently in normal state.
  (defun student-terminal--evil-allows-mouse-p ()
    (or (not (boundp 'evil-state))
        (and (boundp 'evil-mode) (not evil-mode))
        (and (boundp 'evil-local-mode) (not evil-local-mode))
        (eq evil-state 'normal)))

  (defun student-terminal--org-drill-down (event)
    (interactive "e")
    (mouse-set-point event)
    (when (and (derived-mode-p 'org-mode)
               (student-terminal--evil-allows-mouse-p))
      (if (fboundp 'my/org-jump-drill-down)
          (my/org-jump-drill-down)
        (user-error "my/org-jump-drill-down is not defined"))))

  (defun student-terminal--org-surface-up (event)
    (interactive "e")
    (mouse-set-point event)
    (when (student-terminal--evil-allows-mouse-p)
      (if (fboundp 'my/org-jump-surface-up)
          (my/org-jump-surface-up)
        (user-error "my/org-jump-surface-up is not defined"))))

  ;; This map is deliberately high-priority.
  ;; It beats the built-in Emacs C-mouse buffer menu.
  (defvar student-terminal-mouse-mode-map
    (let ((map (make-sparse-keymap)))
      ;; Kill Emacs' menu-triggering press events.
      (define-key map (kbd "<C-down-mouse-1>") #'ignore)
      (define-key map (kbd "<C-down-mouse-3>") #'ignore)

      ;; Use release/click events for your actual commands.
      (define-key map (kbd "<C-mouse-1>") #'student-terminal--org-drill-down)
      (define-key map (kbd "<C-mouse-3>") #'student-terminal--org-surface-up)

      map))

  ;; Put our map in emulation-mode-map-alists so it wins over global,
  ;; minor-mode, Evil, Org, and menu bindings.
  (defvar student-terminal-mouse--emulation-alist
    `((student-terminal-mouse-mode . ,student-terminal-mouse-mode-map)))

  (unless (memq 'student-terminal-mouse--emulation-alist
                emulation-mode-map-alists)
    (add-to-list 'emulation-mode-map-alists
                 'student-terminal-mouse--emulation-alist))

  (define-minor-mode student-terminal-mouse-mode
    "Terminal Ctrl-mouse bindings for Docker/tmux Emacs."
    :global t
    :init-value nil
    :keymap student-terminal-mouse-mode-map)

  (student-terminal-mouse-mode 1)

  ;; Org has extra mouse maps for links and other clickable text.
  ;; Override those too.
  (with-eval-after-load 'org
    (define-key org-mode-map (kbd "<C-down-mouse-1>") #'ignore)
    (define-key org-mouse-map (kbd "<C-down-mouse-1>") #'ignore)
    (define-key org-mouse-map (kbd "<C-mouse-1>")
      #'student-terminal--org-drill-down)

    (define-key org-mode-map (kbd "<C-down-mouse-3>") #'ignore)
    (define-key org-mouse-map (kbd "<C-down-mouse-3>") #'ignore)
    (define-key org-mouse-map (kbd "<C-mouse-3>")
      #'student-terminal--org-surface-up)))

(provide 'tmux-mouse-patch)

;;; tmux-mouse-patch.el ends here
