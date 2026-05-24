;; -*- lexical-binding: t; -*-
;(when (boundp 'native-comp-async-report-warnings-errors)
;  (setq native-comp-async-report-warnings-errors nil))
;; Silence background native-compilation warnings
(setq native-comp-async-report-warnings-errors 'silent)
;; Maximize memory for insanely fast startup
(setq gc-cons-threshold (* 100 1024 1024)) ;; 100 MB

;; ==========================================
;; 0. Emacs Core & Custom UI Settings
;; ==========================================

(server-start)

;; Always prefer newer source files over stale byte-compiled files
(setq load-prefer-newer t)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

(xterm-mouse-mode 1)

;; ==========================================
;; 1. Setup Package Archives & Use-Package
;; ==========================================
;; Bootstrap straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; ---------------------------------------------------------
;; THE REAL FIX: FORCE-INJECT THE LOCKFILE
;; ---------------------------------------------------------
;; straight.el silently ignores `:commit` in recipes. The ONLY way to pin 
;; commits is via its lockfile. We write it programmatically here so that 
;; when straight clones a package, it natively checks out these exact hashes.
;;(let ((lockfile (expand-file-name "straight/versions/default.el" user-emacs-directory))
;;      (pinned-commits
;;       '(("org"                . "13b24185576b4063021378cf8c77577bb61c1c31")
;;         ;;("transient"          . "7131bec61e558e022ce75e2d2d5e55c748fcf8e0")
;;         ("evil"               . "b06f644bdb5b06c6ac46c11b0259f15ac9ffd5da")
;;         ("evil-collection"    . "a18d16675c194203c00f46334fd7c22f46e7671a")
;;         ("evil-org"           . "233f8b723351801910527b4c39c1f85652131f6e")
;;         ("org-roam"           . "b4857fd7a140361883dfb95e1193ee42698a4afb")
;;         ("org-roam-ui"        . "fc909566222669dd1ae9c642e2898c3d67bc6fb5")
;;         ;;("org-transclusion"   . "4938093")
;;         ("lua-mode"           . "eb067bce0e832ae0dc6d06d739faffaae8e514de")
;;         ;;("eat"                . "c91451f")
;;         ;;("corfu-terminal"     . "501548c")
;;         ;;("ef-themes"          . "16681ce")
;;         ("elfeed"             . "66cfe43dfc61d0b56d9e4e72aba3dfab0ed4bdf7")
;;         ("elfeed-org"         . "d62d23e25c5e3be3d70b7fbe1eaeb6e43f93a061")
;;         ("pdf-tools"          . "5245f092e35712df6559a7782a93bb61896175dd")
;;         ("saveplace-pdf-view" . "79e76562bc5ef94c12837035fe504f07be8a8f25")
;;         ("corfu"              . "abfe0003d71b61ffdcf23fc6e546643486daeb69")
;;         ("imenu-list"         . "1447cdc8c0268e332fb4adc0c643702245d31bde")
;;         ("avy"                . "be612110cb116a38b8603df367942e2bb3d9bdbe")
;;         ;;("xclip"              . "9ab2251")
;;         ;;("dape"               . "2d63a41")
;;         ("yasnippet"          . "272b6067f17675eb4eb001a7a933a52e730152cf")
;;         ("org-download"       . "19e166f0a8c539b4144cfbc614309d47a9b2a9b7")
;;         ("org-appear"         . "81eba5d7a5b74cdb1bad091d85667e836f16b997")
;;         
;;         ;; Your hidden transitive dependencies
;;         ("async"              . "5cae78dc0a75cb86df300939af0b00035bc1c045")
;;         ("cond-let"           . "538a4162cc5b39cee2e0f85609ffc1f1716cdf8d")
;;         ("emacsql"            . "d654e4fb1d0f5addd998982754519d144df4bd4c")
;;         ("websocket"          . "3210187c107cdbb075b2e47454068a22f38213fc")
;;         ("goto-chg"           . "3baa71e27b233a966bf4168ba7432cc646658b15")
;;         ("hydra"              . "317e1de33086637579a7aeb60f77ed0405bf359b")
;;         ("llama"              . "de61773fc378d40f478f8daf67543a51889ecded")
;;         ("modus-themes"       . "a4264088b7782e135d2a6210c932eb11cc5fbecd")
;;         ;;("popon"              . "bf8174c")
;;         ("tablist"            . "5f7b71a92bfb25418d7da86ad9c45f14b149496f"))))
;;  
;;  ;; Create the directory if missing
;;  (unless (file-exists-p (file-name-directory lockfile))
;;    (make-directory (file-name-directory lockfile) t))
;;    
;;  ;; Write the lockfile
;;  (with-temp-file lockfile
;;    (let ((print-level nil) (print-length nil))
;;      (prin1 pinned-commits (current-buffer)))))

(straight-use-package 'use-package)
(setq straight-use-package-by-default t)

;; You MUST keep custom repos for forks like org and transient, 
;; but the fake :commit keywords have been removed.
(straight-use-package '(org :host github :repo "emacs-straight/org-mode"))
(straight-use-package 'transient)

;; ==========================================
;; 2. Install and enable Evil & Evil-Collection
;; (MUST be loaded before my-speed-dial, as my-speed-dial requires Evil!)
;; ==========================================

(use-package evil
  :straight (:host github :repo "emacs-evil/evil")
  :init
  (setq evil-want-integration t
	evil-want-keybinding nil
	evil-want-C-u-scroll t
    	evil-undo-system 'undo-redo)
  :config
  ;(evil-mode 1)
  (evil-set-leader 'normal (kbd "SPC"))
  ;; Moved this global keybinding inside the Evil config
  (evil-define-key 'normal 'global (kbd "<leader> f f") 'find-file))

(use-package evil-collection
  :straight (:host github :repo "emacs-evil/evil-collection")
  :after evil
  :config
  (evil-collection-init))

;; ==========================================
;; 3. Load Custom Lisp Path & My-Speed-Dial
;; ==========================================
;; We load this EARLY because later functions (like Eshell) rely on variables
;; defined inside my-speed-dial.el!
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'my-speed-dial)

;; ==========================================
;; 4. General UI & System Settings
;; ==========================================

;; Start Emacs in true full-screen mode (covers the bottom taskbar)
(add-to-list 'default-frame-alist '(fullscreen . fullboth))

;(menu-bar-mode -1)      ;; Hide the top menu bar
;(tool-bar-mode -1)      ;; Hide the icon tool bar
;(scroll-bar-mode -1)    ;; Hide the side scroll bars
(setq inhibit-startup-screen t) ;; Skip the splash screen

;; get rid of annoying bell sound
(setq ring-bell-function 'ignore)
(setq visible-bell t)

;; scrolling find section
(with-eval-after-load 'minibuffer
  
  (defun my/scroll-completions-down ()
    "Scroll the *Completions* window down without changing selection."
    (interactive)
    (let ((win (get-buffer-window "*Completions*")))
      (when win
        (with-selected-window win
          ;; In Emacs, 'scroll-up' moves the text up, meaning your view goes DOWN.
          (scroll-up 3)))))

  (defun my/scroll-completions-up ()
    "Scroll the *Completions* window up without changing selection."
    (interactive)
    (let ((win (get-buffer-window "*Completions*")))
      (when win
        (with-selected-window win
          ;; 'scroll-down' moves the text down, meaning your view goes UP.
          (scroll-down 3)))))

  ;; Enable built-in OSC 52 clipboard integration for modern terminals
  (setq xterm-extra-capabilities '(getSelection setSelection modifyOtherKeys))

  ;; Bind to M-j and M-k in the minibuffer
  (define-key minibuffer-local-map (kbd "M-j") 'my/scroll-completions-down)
  (define-key minibuffer-local-map (kbd "M-k") 'my/scroll-completions-up)
  
  (define-key minibuffer-local-completion-map (kbd "M-j") 'my/scroll-completions-down)
  (define-key minibuffer-local-completion-map (kbd "M-k") 'my/scroll-completions-up)
  
  (define-key minibuffer-local-filename-completion-map (kbd "M-j") 'my/scroll-completions-down)
  (define-key minibuffer-local-filename-completion-map (kbd "M-k") 'my/scroll-completions-up))

;; remember file position
(save-place-mode 1)

;; ==========================================
;; Typography / Font Settings
;; ==========================================

(defvar my/font-typewriter-name "CMU Typewriter Text")
(defvar my/font-retro-name "AcPlus IBM VGA 8x16:pixelsize=32:antialias=true:autohint=false")

(defvar my/font-arabic-name "Scheherazade New")
(defun my/set-arabic-font ()
  "Switch Arabic script to Scheherazade New (Quran/classical Arabic)."
  (interactive)
  (setq my/font-arabic-name "Scheherazade New")
  (my/setup-font-fallbacks)
  (message "Arabic font: Scheherazade New"))

(defun my/set-urdu-font ()
  "Switch Arabic script to Noto Nastaliq Urdu."
  (interactive)
  (setq my/font-arabic-name "Noto Nastaliq Urdu")
  (my/setup-font-fallbacks)
  (message "Arabic font: Noto Nastaliq Urdu"))

(with-eval-after-load 'evil
  (evil-ex-define-cmd "vintage"   'my/font-typewriter)
  (evil-ex-define-cmd "oldschool" 'my/font-retro)
  (evil-ex-define-cmd "arabic"    'my/set-arabic-font)
  (evil-ex-define-cmd "urdu"      'my/set-urdu-font))

(defvar my/font-symbol-name (seq-find (lambda (f) (string-match-p "JetBrains\\|Hack" f)) 
                                      (font-family-list)))

(defun my/setup-font-fallbacks ()
  "Ensure Arabic and Symbols are locked in,
   completely unaffected by the English font."
  
  ;; 1. PURGE EMACS MEMORY: Destroy all relative scaling logic.
  ;;(setq face-font-rescale-alist nil)

  ;; 2. Arabic: The Absolute Pixel Lock + Weight Override
  (when (member my/font-arabic-name (font-family-list))
    (set-fontset-font t 'arabic 
                      (font-spec :family my/font-arabic-name 
                                 ;:size 55
                                 :weight 'normal))) ;; <-- This blocks the semi-bold bleed-over!

  ;; 3. Symbols
  (when my/font-symbol-name
    (let ((sym-spec (font-spec :family my/font-symbol-name 
                               :weight 'normal)))
      (set-fontset-font t '(#x2500 . #x25FF) sym-spec nil 'prepend)
      (set-fontset-font t '(#x2600 . #x26FF) sym-spec nil 'prepend)
      (set-fontset-font t '(#xE000 . #xF8FF) sym-spec nil 'prepend)

      (make-face 'my-jj-symbol-face)
      (set-face-attribute 'my-jj-symbol-face nil :font sym-spec)

      (unless standard-display-table
        (setq standard-display-table (make-display-table)))

      (dolist (char '(?○ ?● ?◆ ?◇))
        (aset standard-display-table char 
              (vector (make-glyph-code char 'my-jj-symbol-face)))))))

(defun my/font-typewriter ()
  "Switch to CMU Typewriter (Semi-Bold)."
  (interactive)
  (set-face-attribute 'default nil 
                      :font my/font-typewriter-name 
                      :weight 'semi-bold ;; English gets semi-bold
                      :height 200)
  (my/setup-font-fallbacks)
  (clear-face-cache t)
  (message "Font: CMU Typewriter Text (Semi-Bold)"))

(defun my/font-retro ()
  "Switch to IBM VGA (Normal weight, Xft spec)."
  (interactive)
  (set-face-attribute 'default nil 
                      :font my/font-retro-name 
                      :weight 'normal)
  (my/setup-font-fallbacks)
  (clear-face-cache t)
  (message "Font: AcPlus IBM VGA 8x16 (Retro)"))

;; 1. Apply Typewriter as the default on startup
(my/font-typewriter)

;; 2. Bind the Evil Ex commands (:typewriter and :retro)
(with-eval-after-load 'evil
  (evil-ex-define-cmd "vintage" 'my/font-typewriter)
  (evil-ex-define-cmd "oldschool" 'my/font-retro))

;; ==========================================
;; Fix RTL/Arabic Cursor Movement in Evil Mode
;; ==========================================

(setq visual-order-cursor-movement t)

(with-eval-after-load 'evil
  ;; 1. Define L as an official Evil motion so the visual highlight box draws correctly
  (evil-define-motion my/evil-right-char (count)
    "Visual-order right movement that strictly respects Vim line boundaries."
    :type exclusive
    (let ((count (or count 1)))
      (dotimes (_ count)
        (let ((prev (point))
              (prev-bol (line-beginning-position)))
          (right-char 1)
          ;; If the line-beginning changed, we stepped to a new line. Snap back!
          (when (/= (line-beginning-position) prev-bol)
            (goto-char prev)
            (user-error "End of line"))))))

  ;; 2. Define H as an official Evil motion
  (evil-define-motion my/evil-left-char (count)
    "Visual-order left movement that strictly respects Vim line boundaries."
    :type exclusive
    (let ((count (or count 1)))
      (dotimes (_ count)
        (let ((prev (point))
              (prev-bol (line-beginning-position)))
          (left-char 1)
          (when (/= (line-beginning-position) prev-bol)
            (goto-char prev)
            (user-error "Beginning of line"))))))

  ;; 3. Bind them to the Evil motion map
  (define-key evil-motion-state-map (kbd "<left>") 'my/evil-left-char)
  (define-key evil-motion-state-map (kbd "<right>") 'my/evil-right-char)
  (define-key evil-motion-state-map (kbd "h") 'my/evil-left-char)
  (define-key evil-motion-state-map (kbd "l") 'my/evil-right-char))

;; ==========================================
;; Fix Visual Region Spilling (Vim Rendering)
;; ==========================================

(declare-function face-remap-remove-relative "face-remap")

;; Tell the Byte-Compiler that these functions exist elsewhere
(declare-function eshell-send-input "esh-mode")
(declare-function pdf-info-running-p "pdf-info")
(declare-function pdf-info-outline "pdf-info")
(declare-function image-mode-window-get "image-mode")
(declare-function evil-org-set-key-theme "evil-org")
(declare-function evil-org-agenda-set-keys "evil-org-agenda")

(defvar-local my/evil-visual-extend-state 'unknown)
(defvar-local my/evil-region-remap-cookie nil)

(defun my/fix-visual-region-extension ()
  "Stop extending region face to the edge of the screen in any visual mode."
  (when (fboundp 'evil-visual-state-p)
    ;; If we are in ANY visual state (v, V, or C-v), turn off screen extension
    (let ((desired-state (if (evil-visual-state-p) 'no-extend 'extend)))
      (unless (eq desired-state my/evil-visual-extend-state)
        (setq my/evil-visual-extend-state desired-state)
        
        ;; Remove old face modification
        (when my/evil-region-remap-cookie
          (face-remap-remove-relative my/evil-region-remap-cookie)
          (setq my/evil-region-remap-cookie nil))
        
        ;; Apply new face modification (disable extension)
        (when (eq desired-state 'no-extend)
          (setq my/evil-region-remap-cookie
                (face-remap-add-relative 'region :extend nil)))))))

(add-hook 'post-command-hook #'my/fix-visual-region-extension)

;; ==========================================
;; Make ESC quit prompts and cancel chords
;; ==========================================

(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

(defun my/minibuffer-keyboard-quit ()
  "Abort recursive edit. In Delete Selection mode, this is undefined."
  (interactive)
  (abort-recursive-edit))

(define-key minibuffer-local-map            (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-ns-map         (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-completion-map (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-must-match-map (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-isearch-map    (kbd "<escape>") 'my/minibuffer-keyboard-quit)

(define-key ctl-x-map         (kbd "<escape>") 'keyboard-quit)
(define-key mode-specific-map (kbd "<escape>") 'keyboard-quit)
(define-key help-map          (kbd "<escape>") 'keyboard-quit)

;; ==========================================
;; Relative Line Numbers
;; ==========================================

;;(setq display-line-numbers-type 'relative)
;;(global-display-line-numbers-mode 1)
;;
;;(dolist (mode '(eshell-mode-hook
;;                eat-mode-hook
;;                term-mode-hook
;;                shell-mode-hook))
;;  (add-hook mode (lambda () (display-line-numbers-mode 0))))

;; ==========================================
;; Remove bar (Terminal Only)
;; ==========================================
(unless (display-graphic-p)
  (setq-default mode-line-format nil))

;; ==========================================
;; Calculate Location (Terminal Only)
;; ==========================================
(defvar my-last-ruler-message nil
  "Store the last position message to prevent overwriting active messages.")

(defun my-show-position-echo ()
  "Show position in the bottom right, yielding to other messages for performance."
  (unless (active-minibuffer-window)
    (let ((msg (current-message)))
      
      ;; FAST PATH: Only do the heavy math if the echo area is empty 
      ;; OR if it's currently displaying our own ruler.
      (when (or (not msg) 
                (equal msg my-last-ruler-message))
        
        (let* ((raw-line (line-number-at-pos))
               (raw-total (line-number-at-pos (point-max)))
               (total-lines (if (and (> raw-total 1) 
                                     (eq ?\n (char-before (point-max))))
                                (- raw-total 1)
                              raw-total))
               (line (min raw-line total-lines))
               (pct (if (> total-lines 0) (floor (* 100.0 line) total-lines) 0))
               
               (info-str (format "Line %d of %d --%d%%--" line total-lines pct))
               (width (window-width (minibuffer-window)))
               (padding (- width (string-width info-str) 1)))
          
          (when (>= padding 0)
            (let ((message-log-max nil)) 
              (setq my-last-ruler-message (concat (make-string padding ?\s) info-str))
              (message "%s" my-last-ruler-message))))))))

;; ONLY attach it to the post-command hook if we are in the terminal (-nw)
(unless (display-graphic-p)
  (add-hook 'post-command-hook #'my-show-position-echo))

;; ==========================================
;; Reload / Compile Config Functions
;; ==========================================
(defun my/reload-config ()
  "Reload your Emacs init.el file instantly."
  (interactive)
  (load-file user-init-file)
  (message "Config successfully reloaded!"))

(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "<leader> h r r") 'my/reload-config))

(defun my/compile-config ()
  "Compile all config files to Machine Code (if supported)."
  (interactive)
  (let ((speed-dial (expand-file-name "lisp/my-speed-dial.el" user-emacs-directory))
        (theme      (expand-file-name "local-theme.el" user-emacs-directory))
        (init       (expand-file-name "init.el" user-emacs-directory))
        (use-native (and (fboundp 'native-comp-available-p) 
                         (native-comp-available-p))))
    
    (if use-native
        (message "🚀 Native Compilation is ON. Compiling to machine code...")
      (message "⚙️ Native Compilation not found. Falling back to byte-compilation..."))

    ;; 1. Compile my-speed-dial.el
    (when (file-exists-p speed-dial)
      (if use-native
          (native-compile speed-dial)
        (byte-compile-file speed-dial)))

    ;; 2. Compile local-theme.el
    (when (file-exists-p theme)
      (if use-native
          (native-compile theme)
        (byte-compile-file theme)))
      
    ;; 3. Compile init.el
    (when (file-exists-p init)
      (if use-native
          (native-compile init)
        (byte-compile-file init)))
      
    (message "✨ Config successfully compiled! Restart Emacs to experience the speed.")))

(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "<leader> h c c") 'my/compile-config))

;; ==========================================
;; 5. Setup Org-Mode Ecosystem
;; ==========================================
(require 'org)

(use-package evil-org
  :straight (:host github :repo "Somelauw/evil-org-mode")
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys)
  (evil-org-set-key-theme '(navigation insert textobjects additional calendar)))

;; Set base directory first so other packages can use it
(defvar org-roam-directory (expand-file-name "~/org-roam"))

(use-package org-roam
  :straight (:host github :repo "org-roam/org-roam")
  :config
  (unless (file-exists-p org-roam-directory)
    (make-directory org-roam-directory))
  (org-roam-db-autosync-mode)

;; =====================================================================
;; THE SMART DISPATCHERS (Nuclear Override for g d, g r, and K)
;; =====================================================================

(defun my/smart-gd ()
  "Traffic cop for `g d'.
If in Org-mode: Drill down into transclusion/source. 
If in Code: Tell LSP to jump to the function definition."
  (interactive)
  (if (derived-mode-p 'org-mode)
      (call-interactively 'my/org-transclusion-open-source-at-point)
    (call-interactively 'xref-find-definitions)))

(defun my/smart-gr ()
  "Traffic cop for `g r'.
If in Org-mode: Find Org-Roam backlinks. 
If in Code: Tell LSP to find where this function is used."
  (interactive)
  (if (derived-mode-p 'org-mode)
      (call-interactively 'my/org-transclusion-backlinks)
    (call-interactively 'xref-find-references)))

;; Silence the byte-compiler warning for the internal ElDoc function
;;(declare-function eldoc--doc-buffer "eldoc")

;; =====================================================================
;; NUCLEAR ELDOC HIJACK (Guaranteed No-Split Window Replacement)
;; =====================================================================

;; 1. Force ElDoc to ALWAYS use the buffer. (By default, if the doc is 
;;    short, it just flashes at the bottom. This forces it to a window).
(setq eldoc-display-functions '(eldoc-display-in-buffer))

;; 2. THE NUCLEAR BOMB: Tell the Emacs Window Manager that whenever 
;;    the *eldoc* buffer appears, it MUST replace the current window.
(add-to-list 'display-buffer-alist
             '("^\\*eldoc\\*"
               (display-buffer-same-window)))

;; 3. The newly stripped-down, bulletproof Smart K
(defun my/smart-K ()
  "Traffic cop for `K'.
If in Org-mode: Toggle transclusion.
If in Code: Force ElDoc to fetch and hijack the window seamlessly."
  (interactive)
  (if (derived-mode-p 'org-mode)
      (call-interactively 'my/org-transclusion-toggle)

    ;; 1. Drop a breadcrumb for Evil so C-o works perfectly
    (when (fboundp 'evil-set-jump)
      (evil-set-jump))

    ;; 2. Nuke old documentation to prevent flashing stale data
    (when (get-buffer "*eldoc*")
      (with-current-buffer "*eldoc*"
        (let ((inhibit-read-only t))
          (erase-buffer))))

    ;; 3. Ask Eglot to fetch data asynchronously. 
    ;;    Because of the global window rule we set above, Emacs will 
    ;;    natively hijack your screen the instant the text arrives.
    (eldoc)))

;; 4. Ensure 'q' flawlessly puts your C++ code back on the screen
(add-hook 'eldoc-mode-hook
          (lambda ()
            (when (string= (buffer-name) "*eldoc*")
              (local-set-key (kbd "q") 
                             (lambda ()
                               (interactive)
                               (quit-window)
                               (when (fboundp 'evil-jump-backward)
                                 (evil-jump-backward 1)))))))

;; Forcefully rip out any old bindings and hard-wire the Traffic Cops
;; directly into Evil's core nervous system.
(with-eval-after-load 'evil
  (define-key evil-normal-state-map (kbd "g d") 'my/smart-gd)
  (define-key evil-normal-state-map (kbd "g r") 'my/smart-gr)
  (define-key evil-normal-state-map (kbd "K")   'my/smart-K)
  
  (define-key evil-motion-state-map (kbd "g d") 'my/smart-gd)
  (define-key evil-motion-state-map (kbd "g r") 'my/smart-gr)
  (define-key evil-motion-state-map (kbd "K")   'my/smart-K))


  ;; Custom function to delete the current roam file
  (defun my/org-roam-delete-current-node ()
    "Deletes the current org-roam file and kills its buffer."
    (interactive)
    (let ((file (buffer-file-name)))
      (if (and file (string-prefix-p (expand-file-name org-roam-directory) file))
          (when (y-or-n-p (format "Delete this Org-Roam node (%s)? " (file-name-nondirectory file)))
            (delete-file file t)
            (kill-buffer)
            (message "Org-Roam node deleted."))
        (message "Current buffer is not a saved file in the org-roam directory."))))

  ;; Custom function to make searching for nodes case-insensitive
  (defun my/org-roam-node-find-ignore-case ()
    "Find an org-roam node with case-insensitive completion."
    (interactive)
    (let ((completion-ignore-case t))
      (org-roam-node-find)))

  (evil-define-key 'normal 'global
    (kbd "<leader> n l") 'org-roam-buffer-toggle
    (kbd "<leader> n f") 'my/org-roam-node-find-ignore-case
    (kbd "<leader> n i") 'org-roam-node-insert
    (kbd "<leader> n S") 'org-roam-db-sync
    (kbd "<leader> n d") 'my/org-roam-delete-current-node))

(use-package org-roam-ui
  :straight (:host github :repo "org-roam/org-roam-ui")
  :custom
  (org-roam-ui-sync-theme t)
  (org-roam-ui-follow t)
  (org-roam-ui-update-on-save t)
  (org-roam-ui-open-on-start t)
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n g") 'org-roam-ui-mode))

;; Minibuffer SPC fix
(define-key minibuffer-local-completion-map (kbd "SPC") 'self-insert-command)

(use-package org-transclusion
  :straight (:host github :repo "nobiot/org-transclusion")
  :config
  (evil-define-key '(normal motion) 'org-mode-map
    (kbd "<leader> n t") 'org-transclusion-mode
    (kbd "<leader> n a") 'org-transclusion-add
    (kbd "<leader> n m") 'org-transclusion-make-from-link
    (kbd "<leader> n r") 'org-transclusion-remove
    ;;(kbd "g d") 'my/org-transclusion-open-source-at-point
    ;;(kbd "g r") 'my/org-transclusion-backlinks
    (kbd "g s") 'my/org-toggle-link-under-cursor    ;; <-- NEW PROPER BINDING
    ;;(kbd "K") 'my/org-transclusion-toggle
    (kbd "g y") #'my/org-store-link-smart   ; 'y' for Yank link
    (kbd "g p") #'my/org-insert-link-clean))

(defun my/org-transclusion-cleanup-ephemera ()
  "Garbage collector: sweeps and removes temporary transclusions before saving."
  (let ((was-modified (buffer-modified-p))
        (found-any nil))
    (save-excursion
      (goto-char (point-min))
      (while (text-property-search-forward 'my-inline-preview t t)
        (setq found-any t)
        (beginning-of-line)
        (when (org-transclusion-within-transclusion-p)
          (org-transclusion-remove))
        (delete-region (1- (point)) (line-end-position))))
    (when found-any
      (remove-overlays (point-min) (point-max) 'my-active-link-preview t)
      ;; Don't let the cleanup itself mark the buffer as modified
      (set-buffer-modified-p was-modified))))

;; Run the garbage collector right before saving, or if Emacs kills the buffer
(add-hook 'before-save-hook #'my/org-transclusion-cleanup-ephemera)
(add-hook 'kill-buffer-hook #'my/org-transclusion-cleanup-ephemera)

(defun my/org-toggle-beacon ()
  "Turn the link into a homing beacon. 
   Secretly opens the transclusion to allow
   math jumps, but completely hides it visually, 
   using a high-priority mask to nuke the
   vertical transclusion line."
  (interactive)
  (let* ((context (org-element-context))
         (type (car context)))
         
    (if (eq type 'link)
        (let* ((beg (org-element-property :begin context))
               (end (org-element-property :end context))
               (tracker-ov nil))
               
          (dolist (ov (overlays-at beg))
            (when (overlay-get ov 'my-active-link-preview)
              (setq tracker-ov ov)))
              
          (if tracker-ov
              ;; ==========================================
              ;; TURN OFF: Remove transclusion and beacon
              ;; ==========================================
              (progn
                (save-excursion
                  (goto-char beg)
                  (end-of-line)
                  (forward-char 1)
                  (when (org-transclusion-within-transclusion-p)
                    (org-transclusion-remove))
                  (let ((was-modified (buffer-modified-p)))
                    (delete-region (1- (line-beginning-position)) (line-end-position))
                    (set-buffer-modified-p was-modified)))
                (delete-overlay tracker-ov)
                (message "Beacon deactivated."))
                
            ;; ==========================================
            ;; TURN ON: Create beacon, transclude, hide all
            ;; ==========================================
            (let ((link-str (buffer-substring-no-properties beg end)))
              (let ((ov (make-overlay beg end)))
                (overlay-put ov 'face '(:foreground "purple" :weight bold))
                (overlay-put ov 'my-active-link-preview t)
                (overlay-put ov 'my-preview-state 'beacon-hidden)
                (setq tracker-ov ov))
                
              (save-excursion
                (end-of-line)
                (let ((insert-pos (point))
                      (was-modified (buffer-modified-p)))
                  
                  (insert "\n#+transclude: " link-str)
                  (put-text-property insert-pos (point) 'my-inline-preview t)
                  
                  (goto-char (1+ insert-pos))
                  (condition-case err
                      (progn
                        (org-transclusion-add)
                        
                        (save-excursion
                          ;; 1. NUKE THE NEWLINE'S VERTICAL LINE
                          ;; We cover the \n character. It stays visible, but we strip its ability
                          ;; to project the vertical transclusion border.
                          (let ((nl-ov (make-overlay insert-pos (1+ insert-pos))))
                            (overlay-put nl-ov 'priority 100)
                            (overlay-put nl-ov 'line-prefix "")
                            (overlay-put nl-ov 'wrap-prefix "")
                            (overlay-put nl-ov 'evaporate t))
                          
                          ;; 2. HIDE THE REST OF THE TRANSCLUSION
                          (goto-char (1+ insert-pos))
                          (let ((hide-start (1+ insert-pos))) 
                            (forward-line 1)
                            (while (and (not (eobp))
                                        (save-excursion 
                                          (beginning-of-line)
                                          (org-transclusion-within-transclusion-p)))
                              (forward-line 1))
                            
                            (let ((hide-ov (make-overlay hide-start (point))))
                              (overlay-put hide-ov 'invisible t)
                              (overlay-put hide-ov 'priority 100)
                              ;; Also strip prefixes here just in case Emacs tries to draw them on the collapsed text
                              (overlay-put hide-ov 'line-prefix "")
                              (overlay-put hide-ov 'wrap-prefix "")
                              (overlay-put hide-ov 'evaporate t)
                              
                              ;; Remove underlying properties from any other overlays
                              (dolist (o (overlays-in hide-start (point)))
                                (unless (eq o hide-ov)
                                  (overlay-put o 'line-prefix nil)
                                  (overlay-put o 'wrap-prefix nil)
                                  (overlay-put o 'before-string nil)
                                  (overlay-put o 'display nil))))))
                              
                        (message "Beacon deployed! (Transclusion secretly active)"))
                    (error
                     (delete-region insert-pos (line-end-position))
                     (delete-overlay tracker-ov)
                     (message "Could not deploy beacon: %s" (error-message-string err))))
                     
                  (set-buffer-modified-p was-modified))))))
      (user-error "Not on an Org link!"))))

;; Bind to Evil Ex-command
(evil-ex-define-cmd "beacon" 'my/org-toggle-beacon)

(defun my/org-jump-to-src-block ()
  "Jump to the start of the code in the next source block.
If already inside the code body of a block, do nothing."
  (interactive)
  ;; Only execute if we are actually in an Org file
  (when (derived-mode-p 'org-mode)
    ;; `org-in-src-block-p` with a `t` argument checks if we are STRICTLY inside
    ;; the code body. If we are on the #+begin_src line, it returns nil.
    (unless (org-in-src-block-p t)
      (let* ((case-fold-search t) ; Make regex case-insensitive for #+BEGIN_SRC
             ;; Search forward, but start from the beginning of the current line
             ;; so we catch the block if the cursor is currently on #+begin_src
             (match-pos (save-excursion
                          (beginning-of-line)
                          (re-search-forward "^[ \t]*#\\+begin_src" nil t))))
        (when match-pos
          (goto-char match-pos)
          (forward-line 1)      ; Move down one line into the actual code
          (back-to-indentation) ; Move to the start of the text (skipping spaces)
          (message "Jumped to source block!"))))))

(defun my/org-transclusion-toggle ()
  "Smart K toggle. 
   Code blocks: [1] Open   -> [2] Hide Wrappers -> [3] Close
   Prose notes: [1] Open   -> [2] Close
   Beacons:     [1] Active -> [2] Off"
  (interactive)
  (let* ((context (org-element-context))
         (type (car context))
         (in-transclusion (org-transclusion-within-transclusion-p)))
         
    (cond
     ;; =======================================================
     ;; CASE 1: Inside an expanded block -> Close it & TELEPORT BACK!
     ;; =======================================================
     (in-transclusion
      (org-transclusion-remove)
      (beginning-of-line)
      (when (and (not (bobp))
                 (get-text-property (1- (point)) 'my-inline-preview))
        
        (let ((jump-pos nil)
              (was-modified (buffer-modified-p)))
          (dolist (ov (overlays-in (line-beginning-position 0) (line-end-position 0)))
            (when (overlay-get ov 'my-active-link-preview)
              (setq jump-pos (overlay-start ov))
              (delete-overlay ov)))
              
          (delete-region (1- (point)) (line-end-position))
          (set-buffer-modified-p was-modified)
          
          (when jump-pos
            (goto-char jump-pos))))
      (message "Transclusion closed"))
      
     ;; =======================================================
     ;; CASE 2: On a hard-coded `#+transclude:` line -> Toggle normally
     ;; =======================================================
     ((save-excursion
        (beginning-of-line)
        (looking-at "^[ \t]*#\\+transclude:"))
      (org-transclusion-add)
      (message "Transclusion toggled"))

     ;; =======================================================
     ;; CASE 3: On an inline link -> Dynamic Cycle (or Beacon Kill)
     ;; =======================================================
     ((eq type 'link)
      (let* ((beg (org-element-property :begin context))
             (end (org-element-property :end context))
             (tracker-ov nil))
             
        (dolist (ov (overlays-at beg))
          (when (overlay-get ov 'my-active-link-preview)
            (setq tracker-ov ov)))
            
        (let ((state (if tracker-ov (overlay-get tracker-ov 'my-preview-state) 'closed)))
          
          (cond
           ;; ---------------------------------------------------------
           ;; STATE 0 -> STATE 1: Always Open Standard First
           ;; ---------------------------------------------------------
           ((eq state 'closed)
            (let ((link-str (buffer-substring-no-properties beg end)))
              (let ((ov (make-overlay beg end)))
                (overlay-put ov 'face '(:foreground "red" :weight bold))
                (overlay-put ov 'my-active-link-preview t)
                (overlay-put ov 'my-preview-state 'standard)
                (setq tracker-ov ov))
                
              (save-excursion
                (end-of-line)
                (let ((insert-pos (point))
                      (was-modified (buffer-modified-p)))
                  
                  (insert "\n#+transclude: " link-str)
                  (put-text-property insert-pos (point) 'my-inline-preview t)
                  
                  (goto-char (1+ insert-pos))
                  (condition-case err
                      (progn
                        (org-transclusion-add)
                        (message "Inline preview: [1] Standard Mode"))
                    (error
                     (delete-region insert-pos (line-end-position))
                     (delete-overlay tracker-ov)
                     (message "Could not transclude link: %s" (error-message-string err))))
                     
                  (set-buffer-modified-p was-modified)))))

           ;; ---------------------------------------------------------
           ;; STATE 1 -> STATE 2 (Hide) OR STATE 0 (Close)
           ;; ---------------------------------------------------------
           ((eq state 'standard)
            (save-excursion
              (end-of-line)
              (let ((insert-pos (point))
                    (was-modified (buffer-modified-p))
                    (has-src nil))
                
                (goto-char (1+ insert-pos))
                (let ((search-bound (+ (point) 10000)))
                  (when (re-search-forward "^[ \t]*#\\+begin_src.*?\n" search-bound t)
                    (setq has-src t)
                    (let ((hide-top (make-overlay (1+ insert-pos) (point))))
                      (overlay-put hide-top 'invisible t)
                      (overlay-put hide-top 'evaporate t))
                      
                    (when (re-search-forward "^[ \t]*#\\+end_src" search-bound t)
                      (let* ((start-hide (max (point-min) (1- (match-beginning 0))))
                             (hide-bot (make-overlay start-hide (line-end-position))))
                        (overlay-put hide-bot 'invisible t)
                        (overlay-put hide-bot 'evaporate t)))))
                
                ;; THE SPLIT LOGIC
                (if has-src
                    ;; It is a source block -> Advance to State 2 (Hidden)
                    (progn
                      (overlay-put tracker-ov 'my-preview-state 'hidden)
                      (set-buffer-modified-p was-modified)
                      (message "Inline preview: [2/3] Hidden Wrappers"))
                      
                  ;; It is normal text -> Skip State 2 and Close it!
                  (goto-char (1+ insert-pos))
                  (when (org-transclusion-within-transclusion-p)
                    (org-transclusion-remove))
                  (delete-region insert-pos (line-end-position))
                  (set-buffer-modified-p was-modified)
                  (delete-overlay tracker-ov)
                  (message "Inline preview: Closed (Prose note)")))))

           ;; ---------------------------------------------------------
           ;; STATE 2 -> STATE 0: Closed (For code blocks)
           ;; ---------------------------------------------------------
           ((eq state 'hidden)
            (save-excursion
              (end-of-line)
              (forward-char 1)
              (when (org-transclusion-within-transclusion-p)
                (org-transclusion-remove))
                
              (let ((was-modified (buffer-modified-p)))
                (delete-region (1- (line-beginning-position)) (line-end-position))
                (set-buffer-modified-p was-modified)))
                
            (delete-overlay tracker-ov)
            (message "Inline preview: [3/3] Closed"))

           ;; ---------------------------------------------------------
           ;; STATE BEACON -> STATE 0: Turn off beacon
           ;; ---------------------------------------------------------
           ((eq state 'beacon-hidden)
            (save-excursion
              (goto-char beg)
              (end-of-line)
              (forward-char 1)
              (when (org-transclusion-within-transclusion-p)
                (org-transclusion-remove))
              (let ((was-modified (buffer-modified-p)))
                (delete-region (1- (line-beginning-position)) (line-end-position))
                (set-buffer-modified-p was-modified)))
            (delete-overlay tracker-ov)
            (message "Beacon deactivated (Toggled via K)."))))))

     ;; =======================================================
     ;; CASE 4: Fallback -> Jump to Source Block
     ;; =======================================================
     (t
      ;; Triggers when not on a transclude line, link, or inside a transclusion.
      ;; Relies on my/org-jump-to-src-block's internal logic to abort safely 
      ;; if already in a block or if no block exists.
      (my/org-jump-to-src-block)))))

(setq org-src-content-indentation 0)
(setq org-src-preserve-indentation t)


;; =======================================================
;; tangle, detangle
;; =======================================================

(defun my-quiet-detangle ()
  "Save current file, detangle silently,
   save the target Org file, and restore windows."
  (interactive)
  ;; 1. Save the current C++ file first (forces detangle to see your latest changes)
  (save-buffer)
  
  ;; 2. Save the current window/split configuration
  (save-window-excursion
    ;; 3. Run the detangle command
    (org-babel-detangle)
    
    ;; 4. Find the Org file that was just updated and save it automatically
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (and (eq major-mode 'org-mode) (buffer-modified-p))
          (save-buffer)))))
          
  ;; 5. Tell the user it worked without moving their cursor or splitting the screen
  (message "Silently detangled and saved back to Org!"))

(defun my-quiet-tangle ()
  "Save the Org file, tangle it, and silently reload any open tangled files."
  (interactive)
  ;; 1. Save the Org file
  (save-buffer)
  
  ;; 2. FORCE Emacs to use 'file:' links by temporarily disabling IDs!
  (let ((org-id-link-to-org-use-id nil))
    
    ;; 3. Tangle and capture the list of generated files
    (let ((tangled-files (org-babel-tangle)))
      
      ;; 4. Loop through the generated files
      (dolist (file tangled-files)
        (let ((buf (get-file-buffer file)))
          ;; 5. If the file is currently open in Emacs, refresh it silently
          (when buf
            (with-current-buffer buf
              (revert-buffer t t t)))))))
              
  ;; 6. Tell the user it worked
  (message "Silently tangled and refreshed open files!"))

;; Bind the new quiet function to Evil
(with-eval-after-load 'evil
  (evil-ex-define-cmd "tangle" 'my-quiet-tangle)
  (evil-ex-define-cmd "detangle" 'my-quiet-detangle))

;; =======================================================
;; org boilerplate setup from source
;; =======================================================

(defun my/org-it ()
  "Take the current source code buffer, create
   a .org file, and wrap it in a src block."
  (interactive)
  (unless (buffer-file-name)
    (error "Buffer is not visiting a file!"))
  
  (let* ((source-file (buffer-file-name))
         (source-name (file-name-nondirectory source-file))
         (source-ext  (file-name-extension source-file))
         (source-content (buffer-string))
         (org-file (concat source-file ".org")) 
         (lang (pcase source-ext
                 ("cpp" "cpp")
                 ("hpp" "cpp")
                 ("c"   "c")
                 ("lua" "lua")
                 ("py"  "python")
                 ("rs"  "rust")
                 (_     source-ext)))
         ;; ADDED FIX: Automatically add :main no for C/C++ to stop the main() wrapping
         (main-flag (if (member lang '("c" "cpp")) " :main no" "")))
    
    (with-current-buffer (find-file-noselect org-file)
      (when (> (buffer-size) 0)
        (if (y-or-n-p "Org file already exists. Overwrite? ")
            (erase-buffer)
          (error "Aborted `:org-it`")))
      
      ;; ADDED FIX: main-flag is injected here
      (insert (format "#+PROPERTY: header-args:%s :tangle %s :comments link%s\n\n" 
                      lang source-name main-flag))
      
      (insert (format "* %s\n" (capitalize (file-name-sans-extension source-name))))
      (insert ":PROPERTIES:\n:ID:       " (org-id-uuid) "\n:END:\n\n")
      
      (insert "#+name: initial-block\n")
      (insert (format "#+begin_src %s\n" lang))
      (insert source-content)
      (unless (string-suffix-p "\n" source-content)
        (insert "\n"))
      (insert "#+end_src\n")
      
      (switch-to-buffer (current-buffer))
      (org-mode)
      (save-buffer)
      (message "Successfully org-it'd! No more unwanted main() wraps."))))

(with-eval-after-load 'evil
  (evil-ex-define-cmd "org-it" 'my/org-it))

;; ==========================================
;; MANUAL LINK REVEAL (TOGGLE) LOGIC
;; ==========================================
(defvar-local my/org-manual-link-bounds nil)

(defun my/org-hide-manual-link ()
  "Force re-hide the manual link."
  (when my/org-manual-link-bounds
    (let ((beg (car my/org-manual-link-bounds))
          (end (cdr my/org-manual-link-bounds)))
      ;; Force Emacs to re-hide it cleanly
      (font-lock-flush beg end)
      (setq my/org-manual-link-bounds nil)
      (remove-hook 'post-command-hook #'my/org-hide-link-on-leave t))))

(defun my/org-hide-link-on-leave ()
  "Re-hide the link when cursor moves outside its bounds."
  (when my/org-manual-link-bounds
    (let ((beg (car my/org-manual-link-bounds))
          (end (cdr my/org-manual-link-bounds)))
      (when (or (< (point) beg) (>= (point) end))
        (my/org-hide-manual-link)))))

(defun my/org-toggle-link-under-cursor ()
  "Toggle the link unfold. Auto-hides on leave."
  (interactive)
  (if (and my/org-manual-link-bounds
           (>= (point) (car my/org-manual-link-bounds))
           (< (point) (cdr my/org-manual-link-bounds)))
      ;; Already active and cursor is inside -> Toggle OFF
      (progn
        (my/org-hide-manual-link)
        (message "Link hidden."))
    ;; Not active -> Try to Toggle ON
    (let* ((context (org-element-context))
           (type (car context)))
      (if (eq type 'link)
          (let ((beg (org-element-property :begin context))
                (end (org-element-property :end context)))
            ;; Clean up just in case another one was active somewhere else
            (my/org-hide-manual-link) 
            ;; Strip all invisibility properties so the ID shows up
            (with-silent-modifications
              (remove-text-properties beg end '(invisible nil)))
            ;; Set bounds and watch the cursor
            (setq my/org-manual-link-bounds (cons beg end))
            (add-hook 'post-command-hook #'my/org-hide-link-on-leave nil t)
            (message "Link revealed. Press `g s` to hide, or move away."))
        (message "No link under cursor.")))))

;; ==========================================
;; JUMP LOGIC TO AND BACK FROM TANGLED FILE
;; ==========================================

(defun my/org-jump-drill-down ()
  "Drill downward: Transclusion Clone -> Org Source Block -> Tangled Code.
   If on pure prose / ID link, deploys a homing beacon and jumps to source.
   Maintains exact row/col persistence with absolutely no window splitting."
  (interactive)
  (cond
   ;; =======================================================
   ;; CASE 1: Inside Org-Transclusion -> Jump to Org Source
   ;; =======================================================
   ((and (derived-mode-p 'org-mode) 
         (fboundp 'org-transclusion-within-transclusion-p)
         (org-transclusion-within-transclusion-p))
    
    (if (not (org-in-src-block-p))
        ;; -> PROSE DETECTED: Drill down natively
        (progn
          (org-transclusion-open-source)
          (message "Opened source from transclusion prose!"))
          
      ;; -> SOURCE BLOCK DETECTED: Run exact math bubbling
      (let* ((info (org-babel-get-src-block-info 'light))
             (block-name (nth 4 info))
             (current-col (current-column))
             (current-line (line-number-at-pos))
             (src-head-pos (org-babel-where-is-src-block-head))
             (head-line (save-excursion 
                          (goto-char src-head-pos) 
                          (line-number-at-pos)))
             (line-offset (- current-line head-line))
             
             (target-id (let ((search-invisible t))
                          (save-excursion
                            (goto-char src-head-pos)
                            (when (re-search-backward "id:[0-9a-fA-F-]+" nil t)
                              (beginning-of-line)
                              (let ((found-id nil))
                                (dolist (ov (overlays-in (line-beginning-position) (line-end-position)))
                                  (when (overlay-get ov 'my-active-link-preview)
                                    (let ((text (buffer-substring-no-properties (overlay-start ov) (overlay-end ov))))
                                      (when (string-match "id:\\([0-9a-fA-F-]+\\)" text)
                                        (setq found-id (match-string 1 text))))))
                                (unless found-id
                                  (when (re-search-forward "id:\\([0-9a-fA-F-]+\\)" (line-end-position) t)
                                    (setq found-id (match-string 1))))
                                found-id))))))
             
        (unless target-id
          (user-error "Could not extract the #+transclude ID!"))
             
        (evil-set-jump)
        (org-id-goto target-id)
        
        (if block-name
            (let ((regex (format "^[ \t]*#\\+name:[ \t]*%s" (regexp-quote block-name))))
              (if (re-search-forward regex nil t)
                  (re-search-forward "^[ \t]*#\\+begin_src" nil t)
                (message "Could not find block '%s' under heading." block-name)))
          (re-search-forward "^[ \t]*#\\+begin_src" nil t))
          
        (beginning-of-line)
        (forward-line line-offset)
        (move-to-column current-col)
        (recenter)
        (message "Teleported to Org Source! Zero splits."))))

   ;; =======================================================
   ;; CASE 2: In standard Org Source -> Jump to Tangled File OR ID Link
   ;; =======================================================
   ((derived-mode-p 'org-mode)
    (if (not (org-in-src-block-p))
        
        ;; -> PROSE DETECTED: Execute open-source / beacon logic
        (let* ((context (org-element-context))
               (type (car context)))
          (cond
           ;; EXACTLY on an ID link -> Deploy Beacon + Jump!
           ((and (eq type 'link) (string= (org-element-property :type context) "id"))
            (let ((id (org-element-property :path context))
                  (beacon-active nil))
              (evil-set-jump)
              
              ;; ---> BEACON CHECK LOGIC <---
              ;; Scan overlays at current cursor to see if beacon is already active
              (dolist (ov (overlays-at (point)))
                (when (eq (overlay-get ov 'my-preview-state) 'beacon-hidden)
                  (setq beacon-active t)))
              
              ;; Only toggle if the beacon is NOT active
              (unless beacon-active
                (my/org-toggle-beacon))
              
              (org-id-goto id)
              (message "Beacon active! Opened source: %s" id)))
              
           ;; On a `#+transclude:` line -> Just Jump!
           ((save-excursion
              (beginning-of-line)
              (re-search-forward "#\\+transclude:" (line-end-position) t))
            (save-excursion
              (beginning-of-line)
              (if (re-search-forward "id:\\([0-9a-fA-F-]+\\)" (line-end-position) t)
                  (let ((id (match-string 1)))
                    (evil-set-jump)
                    (org-id-goto id)
                    (message "Opened transclude source: %s" id))
                (user-error "No ID link found on this transclude line."))))
                
           (t
            (user-error "Not in a source block, and no ID link exactly under cursor!"))))

      ;; -> SOURCE BLOCK DETECTED: Run exact math bubbling to Tangled File
      (let* ((info (org-babel-get-src-block-info 'light))
             (tangle-target (cdr (assq :tangle (nth 2 info))))
             (block-name (nth 4 info))
             (current-col (current-column))
             (current-line (line-number-at-pos))
             (src-head-pos (org-babel-where-is-src-block-head))
             (head-line (save-excursion 
                          (goto-char src-head-pos) 
                          (line-number-at-pos)))
             (line-offset (- current-line head-line)))
        
        (unless tangle-target
          (user-error "Not in a source block or :tangle is not set"))
          
        (let ((tangle-file (expand-file-name tangle-target)))
          (unless (file-exists-p tangle-file)
            (user-error "Tangled file '%s' does not exist." tangle-file))
          
          (evil-set-jump)
          (find-file tangle-file)
          (goto-char (point-min))
          
          (if block-name
              (let ((regex (format "\\[\\[file:.*::%s\\]\\[%s\\]\\]" block-name block-name)))
                (if (re-search-forward regex nil t)
                    (progn
                      (beginning-of-line)         
                      (forward-line line-offset)
                      (move-to-column current-col)
                      (recenter)
                      (message "Teleported to Tangled Code! Zero splits."))                 
                  (message "Could not find block '%s' in tangled file." block-name)))
            (message "Block has no #+name."))))))

   (t (user-error "Not in an Org block or Transclusion!"))))

(evil-define-key 'normal 'global (kbd "g m") 'my/org-jump-drill-down)

(defun my/org-jump-surface-up ()
  "Surface upward: Tangled Code -> Org Source Block -> Transclusion Clone.
   Maintains exact row/col persistence with absolutely no window splitting.
   If a beacon is secretly active, exclusively uses the smart dispatcher."
  (interactive)
  (cond
   ;; =======================================================
   ;; CASE 1: In a Tangled File -> Jump up to Org Source
   ;; =======================================================
   ((not (derived-mode-p 'org-mode))
    (let ((current-win (selected-window))
          (current-col (current-column))
          (current-line (line-number-at-pos))
          org-file block-name comment-line)

      (save-excursion
        (if (re-search-backward "\\[\\[file:\\(.*?\\)::\\(.*?\\)\\]\\[" nil t)
            (setq org-file (match-string 1)
                  block-name (match-string 2)
                  comment-line (line-number-at-pos))
          (user-error "Could not find Org breadcrumb link above cursor!")))

      (let* ((line-offset (- current-line comment-line))
             (org-file-path (expand-file-name org-file (file-name-directory (buffer-file-name)))))

        (unless (file-exists-p org-file-path)
          (user-error "Org file '%s' does not exist." org-file-path))

        (evil-set-jump)
        (let ((buf (find-file-noselect org-file-path)))
          (set-window-buffer current-win buf)
          (select-window current-win)
          (set-buffer buf)

          (goto-char (point-min))
          (let ((case-fold-search t))
            (if (re-search-forward (format "^[ \t]*#\\+name:[ \t]*%s" (regexp-quote block-name)) nil t)
                (progn
                  (beginning-of-line)
                  (forward-line (1+ line-offset))
                  (move-to-column current-col)
                  (recenter)
                  (message "Teleported up to Org Source! Zero splits."))
              (message "Could not find block '%s' in %s" block-name org-file)))))))

   ;; =======================================================
   ;; CASE 2: In Org Source -> Beacon Check OR Transclusion Clone(s)
   ;; =======================================================
   ((derived-mode-p 'org-mode)
    (when (and (fboundp 'org-transclusion-within-transclusion-p)
               (org-transclusion-within-transclusion-p))
      (user-error "Already at the highest level (Transclusion). Use 'g m' to go down."))

    ;; ONLY scan for beacons if we are actually in an Org file
    (let ((beacon-ov
           (catch 'found-beacon
             (dolist (buf (buffer-list))
               (when (buffer-live-p buf)
                 (with-current-buffer buf
                   (when (derived-mode-p 'org-mode)
                     (dolist (ov (overlays-in (point-min) (point-max)))
                       (when (eq (overlay-get ov 'my-preview-state) 'beacon-hidden)
                         (throw 'found-beacon ov)))))))
             nil)))

      (if beacon-ov
          ;; -> BEACON DETECTED: Route to dispatcher (Kill logic handles it on landing)
          (progn
            (message "Homing beacon active! Routing to dispatcher...")
            (my/org-jump-to-beacon))

        ;; -> NORMAL BEHAVIOR: Execute your exact original math
        (if (not (org-in-src-block-p))
            
            ;; -> PROSE DETECTED: Hand over to Smart Dispatcher
            (progn
              (message "Prose detected. Handing control to smart dispatcher...")
              (my/org-jump-to-beacon))
          
          ;; -> SOURCE BLOCK DETECTED: Run exact math bubbling
          (let* ((info (org-babel-get-src-block-info 'light))
                 (block-name (nth 4 info))
                 (src-id (save-excursion (ignore-errors (org-back-to-heading t) (org-id-get))))
                 (current-col (current-column))
                 (current-line (line-number-at-pos))
                 (src-head-pos (org-babel-where-is-src-block-head))
                 (head-line (save-excursion
                              (goto-char src-head-pos)
                              (line-number-at-pos)))
                 (line-offset (- current-line head-line))
                 (current-win (selected-window))
                 (source-buf (current-buffer))
                 (raw-matches '())
                 (all-matches '())
                 (seen-keys '()))

            ;; Strategy 1: Hunt for homing beacons
            (dolist (buf (buffer-list))
              (when (and (not (eq buf source-buf))
                         (with-current-buffer buf (derived-mode-p 'org-mode)))
                (with-current-buffer buf
                  (dolist (ov (overlays-in (point-min) (point-max)))
                    (when (overlay-get ov 'my-active-link-preview)
                      (let* ((beacon-pos (overlay-start ov))
                             (beacon-text (buffer-substring-no-properties 
                                           (overlay-start ov) 
                                           (overlay-end ov))))
                        
                        (when (or (and src-id (string-match-p (regexp-quote src-id) beacon-text))
                                  (and block-name (string-match-p (regexp-quote block-name) beacon-text)))
                          
                          (let ((is-open nil))
                            (save-excursion
                              (goto-char beacon-pos)
                              (when (re-search-forward "^[ \t]*#\\+begin_src" (+ beacon-pos 500) t)
                                (when (and (fboundp 'org-transclusion-within-transclusion-p)
                                           (org-transclusion-within-transclusion-p))
                                  (setq is-open t))))
                            
                            (when is-open
                              (push (list buf beacon-pos) raw-matches))))))))))

            ;; Deduplicate raw-matches
            (dolist (match raw-matches)
              (let* ((m-buf (car match))
                 (m-pos (cadr match))
                 (m-line (with-current-buffer m-buf
                           (save-excursion
                             (goto-char m-pos)
                             (line-number-at-pos))))
                 (bucket (/ m-line 5))
                 (key (cons m-buf bucket)))
                (unless (member key seen-keys)
                  (push key seen-keys)
                  (push match all-matches))))

            ;; Strategy 2: Text Fallback
            (when (null all-matches)
              (dolist (buf (buffer-list))
                (when (and (not (eq buf source-buf))
                           (with-current-buffer buf (derived-mode-p 'org-mode)))
                  (with-current-buffer buf
                    (let ((case-fold-search t) (search-invisible t))
                      (when block-name
                        (save-excursion
                          (goto-char (point-min))
                          (while (re-search-forward (format "^[ \t]*#\\+name:[ \t]*%s" (regexp-quote block-name)) nil t)
                            (let ((pos (line-beginning-position)) (is-open nil))
                              (save-excursion
                                (goto-char pos)
                                (when (re-search-forward "^[ \t]*#\\+begin_src" (+ pos 500) t)
                                  (when (and (fboundp 'org-transclusion-within-transclusion-p)
                                             (org-transclusion-within-transclusion-p))
                                    (setq is-open t))))
                              (when is-open (push (list buf pos) all-matches))))))
                      (when src-id
                        (save-excursion
                          (goto-char (point-min))
                          (while (re-search-forward (regexp-quote src-id) nil t)
                            (let ((pos (line-beginning-position)) (is-open nil))
                              (save-excursion
                                (goto-char pos)
                                (when (re-search-forward "^[ \t]*#\\+begin_src" (+ pos 500) t)
                                  (when (and (fboundp 'org-transclusion-within-transclusion-p)
                                             (org-transclusion-within-transclusion-p))
                                    (setq is-open t))))
                              (when is-open (push (list buf pos) all-matches)))))))))))

            (unless all-matches
              (user-error "Could not find any ACTIVE transclusion clones in open buffers!"))

            (if (= (length all-matches) 1)

                ;; SINGLE MATCH: teleport directly
                (let* ((match (car all-matches))
                       (target-buf (car match))
                       (target-pos (cadr match)))
                  (evil-set-jump)
                  (set-window-buffer current-win target-buf)
                  (select-window current-win)
                  (set-buffer target-buf)
                  (goto-char target-pos)
                  
                  ;; ---> LANDING SPOT 1: KILL BEACON <---
                  (let ((landed-ov nil))
                    (dolist (ov (overlays-at target-pos))
                      (when (eq (overlay-get ov 'my-preview-state) 'beacon-hidden)
                        (setq landed-ov ov)))
                    (when landed-ov
                      (let ((inhibit-read-only t))
                        (save-excursion
                          (goto-char target-pos)
                          (end-of-line)
                          (forward-char 1)
                          (ignore-errors
                            (when (and (fboundp 'org-transclusion-within-transclusion-p)
                                       (org-transclusion-within-transclusion-p))
                              (org-transclusion-remove)))
                          (let ((was-modified (buffer-modified-p)))
                            (ignore-errors (delete-region (1- (line-beginning-position)) (line-end-position)))
                            (set-buffer-modified-p was-modified))))
                      (delete-overlay landed-ov)
                      (message "Beacon deactivated at landing site!")))
                  
                  (if (re-search-forward "^[ \t]*#\\+begin_src" nil t)
                      (progn
                        (beginning-of-line)
                        (forward-line line-offset)
                        (move-to-column current-col)
                        (recenter)
                        (message "Teleported up to Transclusion! Zero splits."))
                    (message "Switched buffer, but could not locate #+begin_src for math anchor.")))

              ;; MULTIPLE MATCHES: spawn pristine picker buffer
              (let ((picker-buf (get-buffer-create "*Org Transclusions*")))
                (with-current-buffer picker-buf
                  (let ((inhibit-read-only t))
                    (erase-buffer)

                    (dolist (match all-matches)
                      (let* ((m-buf  (car match))
                             (m-pos  (cadr match))
                             (m-file (or (buffer-file-name m-buf) (buffer-name m-buf)))
                             (m-line (with-current-buffer m-buf
                                       (save-excursion
                                         (goto-char m-pos)
                                         (line-number-at-pos))))
                             (m-text (with-current-buffer m-buf
                                       (save-excursion
                                         (goto-char m-pos)
                                         (buffer-substring-no-properties
                                          (line-beginning-position)
                                          (line-end-position))))))
                        (insert (propertize m-file 'font-lock-face 'compilation-info)
                                ":"
                                (propertize (number-to-string m-line) 'font-lock-face 'compilation-line-number)
                                ":"
                                m-text "\n")))

                    (special-mode)

                    (setq-local my/org-transclusion-jump-matches all-matches)
                    (setq-local my/org-transclusion-jump-line-offset line-offset)
                    (setq-local my/org-transclusion-jump-col current-col)
                    (setq-local my/org-transclusion-jump-source-win current-win)

                    (evil-local-set-key 'normal (kbd "RET") 'my/org-transclusion-picker-jump)
                    (evil-local-set-key 'motion (kbd "RET") 'my/org-transclusion-picker-jump)
                    (local-set-key (kbd "RET") 'my/org-transclusion-picker-jump)
                    (local-set-key (kbd "<return>") 'my/org-transclusion-picker-jump)

                    (goto-char (point-min))))

                (switch-to-buffer picker-buf)
                (delete-other-windows)
                (message "Multiple active transclusions found (%d). Press RET to teleport." (length all-matches)))))))))))

(evil-define-key 'normal 'global (kbd "g c") 'my/org-jump-surface-up)

;; =====================================================================
;; 1. THE SMART DISPATCHER (Bound to :testjmp)
;; =====================================================================
(defun my/org-jump-to-beacon ()
  "Smart jump to transclusion homing beacon.
   Automatically routes to src-block logic or prose logic based on context."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in an Org buffer!"))
  (when (and (fboundp 'org-transclusion-within-transclusion-p)
             (org-transclusion-within-transclusion-p))
    (user-error "Already at the highest level (Transclusion)."))

  ;; Check if we are inside or on a source block
  (let ((element-type (ignore-errors (car (org-element-at-point)))))
    (if (or (ignore-errors (org-babel-get-src-block-info 'light))
            (eq element-type 'src-block))
        (progn
          (message "Source block detected. Routing to src-block jumper...")
          (my/org-jump-to-beacon-src))
      (progn
        (message "Prose detected. Routing to prose jumper...")
        (my/org-jump-to-beacon-prose)))))

(evil-ex-define-cmd "testjmp" 'my/org-jump-to-beacon)


;; =====================================================================
;; 2. YOUR ORIGINAL SOURCE-BLOCK LOGIC (Renamed to -src)
;; =====================================================================
(defun my/org-jump-to-beacon-src ()
  "Jump directly to the transclusion homing beacon without math offsets."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in an Org buffer!"))
  (when (and (fboundp 'org-transclusion-within-transclusion-p)
             (org-transclusion-within-transclusion-p))
    (user-error "Already at the highest level (Transclusion)."))

  (let* ((info (ignore-errors (org-babel-get-src-block-info 'light)))
         (block-name (or (nth 4 info)
                         (ignore-errors (org-element-property :name (org-element-at-point)))))
         (src-id (or (org-id-get)
                     (save-excursion 
                       (ignore-errors (org-back-to-heading t))
                       (org-id-get))))
         (current-win (selected-window))
         (source-buf (current-buffer))
         (raw-matches '())
         (all-matches '())
         (seen-keys '()))

    (dolist (buf (buffer-list))
      (when (and (not (eq buf source-buf))
                 (with-current-buffer buf (derived-mode-p 'org-mode)))
        (with-current-buffer buf
          (dolist (ov (overlays-in (point-min) (point-max)))
            (when (overlay-get ov 'my-active-link-preview)
              (let* ((beacon-pos (overlay-start ov))
                     (beacon-text (buffer-substring-no-properties 
                                   (overlay-start ov) 
                                   (overlay-end ov))))
                
                (when (or (and src-id (string-match-p (regexp-quote src-id) beacon-text))
                          (and block-name (string-match-p (regexp-quote block-name) beacon-text)))
                  
                  (let ((is-open nil))
                    (save-excursion
                      (goto-char beacon-pos)
                      (let ((limit (min (+ beacon-pos 500) (point-max))))
                        (while (and (< (point) limit) (not is-open))
                          (if (and (fboundp 'org-transclusion-within-transclusion-p)
                                   (org-transclusion-within-transclusion-p))
                              (setq is-open t)
                            (forward-char 1)))))
                    
                    (when is-open
                      (push (list buf beacon-pos) raw-matches))))))))))

    (dolist (match raw-matches)
      (let* ((m-buf (car match))
             (m-pos (cadr match))
             (m-line (with-current-buffer m-buf
                       (save-excursion
                         (goto-char m-pos)
                         (line-number-at-pos))))
             (bucket (/ m-line 5))
             (key (cons m-buf bucket)))
        (unless (member key seen-keys)
          (push key seen-keys)
          (push match all-matches))))

    (when (null all-matches)
      (dolist (buf (buffer-list))
        (when (and (not (eq buf source-buf))
                   (with-current-buffer buf (derived-mode-p 'org-mode)))
          (with-current-buffer buf
            (let ((case-fold-search t) (search-invisible t))
              (when block-name
                (save-excursion
                  (goto-char (point-min))
                  (while (re-search-forward (format "^[ \t]*#\\+name:[ \t]*%s" (regexp-quote block-name)) nil t)
                    (let ((pos (line-beginning-position)) (is-open nil))
                      (save-excursion
                        (goto-char pos)
                        (let ((limit (min (+ pos 500) (point-max))))
                          (while (and (< (point) limit) (not is-open))
                            (if (and (fboundp 'org-transclusion-within-transclusion-p)
                                     (org-transclusion-within-transclusion-p))
                                (setq is-open t)
                              (forward-char 1)))))
                      (when is-open (push (list buf pos) all-matches))))))
              (when src-id
                (save-excursion
                  (goto-char (point-min))
                  (while (re-search-forward (regexp-quote src-id) nil t)
                    (let ((pos (line-beginning-position)) (is-open nil))
                      (save-excursion
                        (goto-char pos)
                        (let ((limit (min (+ pos 500) (point-max))))
                          (while (and (< (point) limit) (not is-open))
                            (if (and (fboundp 'org-transclusion-within-transclusion-p)
                                     (org-transclusion-within-transclusion-p))
                                (setq is-open t)
                              (forward-char 1)))))
                      (when is-open (push (list buf pos) all-matches)))))))))))

    (unless all-matches
      (user-error "Could not find any ACTIVE transclusion clones in open buffers!"))

    (if (= (length all-matches) 1)

        ;; -----------------------------------------------
        ;; SINGLE MATCH: teleport directly NO MATH!
        ;; -----------------------------------------------
        (let* ((match (car all-matches))
               (target-buf (car match))
               (target-pos (cadr match)))
          (evil-set-jump)
          (set-window-buffer current-win target-buf)
          (select-window current-win)
          (set-buffer target-buf)
          
          (goto-char target-pos)
          
          ;; ---> LANDING SPOT 2: KILL BEACON <---
          (let ((landed-ov nil))
            (dolist (ov (overlays-at target-pos))
              (when (eq (overlay-get ov 'my-preview-state) 'beacon-hidden)
                (setq landed-ov ov)))
            (when landed-ov
              (let ((inhibit-read-only t))
                (save-excursion
                  (goto-char target-pos)
                  (end-of-line)
                  (forward-char 1)
                  (ignore-errors
                    (when (and (fboundp 'org-transclusion-within-transclusion-p)
                               (org-transclusion-within-transclusion-p))
                      (org-transclusion-remove)))
                  (let ((was-modified (buffer-modified-p)))
                    (ignore-errors (delete-region (1- (line-beginning-position)) (line-end-position)))
                    (set-buffer-modified-p was-modified))))
              (delete-overlay landed-ov)
              (message "Beacon deactivated at landing site!")))
              
          (recenter)
          (message "Teleported directly to homing beacon!"))

      ;; -----------------------------------------------
      ;; MULTIPLE MATCHES: spawn pristine picker buffer
      ;; -----------------------------------------------
      (let ((picker-buf (get-buffer-create "*Org Transclusions*")))
        (with-current-buffer picker-buf
          (let ((inhibit-read-only t))
            (erase-buffer)

            (dolist (match all-matches)
              (let* ((m-buf  (car match))
                     (m-pos  (cadr match))
                     (m-file (or (buffer-file-name m-buf) (buffer-name m-buf)))
                     (m-line (with-current-buffer m-buf
                               (save-excursion
                                 (goto-char m-pos)
                                 (line-number-at-pos))))
                     (m-text (with-current-buffer m-buf
                               (save-excursion
                                 (goto-char m-pos)
                                 (buffer-substring-no-properties
                                  (line-beginning-position)
                                  (line-end-position))))))
                (insert (propertize m-file 'font-lock-face 'compilation-info)
                        ":"
                        (propertize (number-to-string m-line) 'font-lock-face 'compilation-line-number)
                        ":"
                        m-text "\n")))

            (special-mode)

            (setq-local my/org-transclusion-jump-matches all-matches)
            (setq-local my/org-transclusion-jump-source-win current-win)
            (setq-local my/org-transclusion-jump-no-math t)

            (evil-local-set-key 'normal (kbd "RET") 'my/org-transclusion-picker-jump)
            (evil-local-set-key 'motion (kbd "RET") 'my/org-transclusion-picker-jump)
            (local-set-key (kbd "RET") 'my/org-transclusion-picker-jump)
            (local-set-key (kbd "<return>") 'my/org-transclusion-picker-jump)

            (goto-char (point-min))))

        (switch-to-buffer picker-buf)
        (delete-other-windows)
        (message "Multiple active transclusions found (%d). Press RET to teleport." (length all-matches))))))

;; =====================================================================
;; 3. YOUR ORIGINAL SRC-BLOCK HELPER (Picker)
;; =====================================================================
(defun my/org-transclusion-picker-jump ()
  "Jump to the transclusion selected in the *Org Transclusions* picker."
  (interactive)
  (let* ((matches     (and (boundp 'my/org-transclusion-jump-matches) 
                           my/org-transclusion-jump-matches))
         (line-offset (if (boundp 'my/org-transclusion-jump-line-offset) 
                          my/org-transclusion-jump-line-offset 0)) 
         (col         (if (boundp 'my/org-transclusion-jump-col) 
                          my/org-transclusion-jump-col 0))         
         (source-win  (and (boundp 'my/org-transclusion-jump-source-win) 
                           my/org-transclusion-jump-source-win))
         (no-math     (and (boundp 'my/org-transclusion-jump-no-math) 
                           my/org-transclusion-jump-no-math))
         (line-num    (line-number-at-pos))
         (match       (nth (1- line-num) matches)))
    
    (unless match
      (user-error "No match on this line!"))
      
    (let ((target-buf (car match))
          (target-pos (cadr match)))
      (unless (buffer-live-p target-buf)
        (user-error "Target buffer is no longer live!"))
        
      (evil-set-jump)
      
      (let ((win (if (window-live-p source-win) source-win (selected-window))))
        (set-window-buffer win target-buf)
        (select-window win)
        (set-buffer target-buf)
        (goto-char target-pos)
        
        ;; ---> LANDING SPOT 3: KILL BEACON <---
        (let ((landed-ov nil))
          (dolist (ov (overlays-at target-pos))
            (when (eq (overlay-get ov 'my-preview-state) 'beacon-hidden)
              (setq landed-ov ov)))
          (when landed-ov
            (let ((inhibit-read-only t))
              (save-excursion
                (goto-char target-pos)
                (end-of-line)
                (forward-char 1)
                (ignore-errors
                  (when (and (fboundp 'org-transclusion-within-transclusion-p)
                             (org-transclusion-within-transclusion-p))
                    (org-transclusion-remove)))
                (let ((was-modified (buffer-modified-p)))
                  (ignore-errors (delete-region (1- (line-beginning-position)) (line-end-position)))
                  (set-buffer-modified-p was-modified))))
            (delete-overlay landed-ov)
            (message "Beacon deactivated at landing site!")))

        ;; DYNAMIC EXECUTION: Math (g c) vs No Math (:testjmp)
        (if no-math
            (progn
              (recenter)
              (delete-other-windows)
              (message "Teleported directly to homing beacon!"))
          
          ;; Legacy behavior for 'g c'
          (if (re-search-forward "^[ \t]*#\\+begin_src" nil t)
              (progn
                (beginning-of-line)
                (forward-line line-offset)
                (move-to-column col)
                (recenter)
                (delete-other-windows)
                (message "Teleported to transclusion! Zero splits."))
            (message "Switched buffer, but could not locate #+begin_src.")))))))


;; =====================================================================
;; 4. THE PROSE LOGIC
;; =====================================================================
(defun my/org-jump-to-beacon-prose ()
  "Jump directly to the transclusion homing beacon for PROSE."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in an Org buffer!"))
  (when (and (fboundp 'org-transclusion-within-transclusion-p)
             (org-transclusion-within-transclusion-p))
    (user-error "Already at the highest level (Transclusion)."))

  (let* ((block-name (ignore-errors (org-element-property :name (org-element-at-point))))
         (src-id (or (org-id-get)
                     (save-excursion 
                       (ignore-errors (org-back-to-heading t))
                       (org-id-get))))
         (heading-title (save-excursion 
                          (ignore-errors 
                            (org-back-to-heading t) 
                            (nth 4 (org-heading-components)))))
         (current-win (selected-window))
         (source-buf (current-buffer))
         (all-matches '())
         (seen-keys '()))

    (dolist (buf (buffer-list))
      (when (and (not (eq buf source-buf))
                 (with-current-buffer buf (derived-mode-p 'org-mode)))
        (with-current-buffer buf
          (dolist (ov (overlays-in (point-min) (point-max)))
            (when (overlay-get ov 'my-active-link-preview)
              (let* ((beacon-pos (overlay-start ov))
                     (beacon-text (buffer-substring-no-properties 
                                   (overlay-start ov) 
                                   (overlay-end ov))))
                
                (when (or (and src-id (string-match-p (regexp-quote src-id) beacon-text))
                          (and block-name (string-match-p (regexp-quote block-name) beacon-text))
                          (and heading-title (string-match-p (regexp-quote heading-title) beacon-text)))
                  
                  (let* ((m-line (line-number-at-pos beacon-pos))
                         (key (cons buf m-line)))
                    (unless (member key seen-keys)
                      (let ((is-open nil))
                        (save-excursion
                          (goto-char beacon-pos)
                          (let ((limit (min (+ beacon-pos 500) (point-max))))
                            (while (and (< (point) limit) (not is-open))
                              (if (and (fboundp 'org-transclusion-within-transclusion-p)
                                       (org-transclusion-within-transclusion-p))
                                  (setq is-open t)
                                (forward-char 1)))))
                        
                        (when is-open
                          (push key seen-keys)
                          (push (list buf beacon-pos) all-matches))))))))))))

    (when (null all-matches)
      (dolist (buf (buffer-list))
        (when (and (not (eq buf source-buf))
                   (with-current-buffer buf (derived-mode-p 'org-mode)))
          (with-current-buffer buf
            (let ((case-fold-search t) (search-invisible t))
              (let ((search-targets (delq nil (list block-name src-id heading-title))))
                (dolist (target search-targets)
                  (save-excursion
                    (goto-char (point-min))
                    (while (re-search-forward (regexp-quote target) nil t)
                      (let* ((pos (line-beginning-position))
                             (m-line (line-number-at-pos pos))
                             (key (cons buf m-line)))
                        (unless (member key seen-keys)
                          (let ((is-open nil))
                            (save-excursion
                              (goto-char pos)
                              (let ((limit (min (+ pos 500) (point-max))))
                                (while (and (< (point) limit) (not is-open))
                                  (if (and (fboundp 'org-transclusion-within-transclusion-p)
                                           (org-transclusion-within-transclusion-p))
                                      (setq is-open t)
                                    (forward-char 1)))))
                            
                            (when is-open
                              (push key seen-keys)
                              (push (list buf pos) all-matches))))))))))))))

    (unless all-matches
      (user-error "Could not find any ACTIVE prose transclusion clones in open buffers!"))

    (if (= (length all-matches) 1)

        ;; -----------------------------------------------
        ;; SINGLE MATCH: Teleport directly
        ;; -----------------------------------------------
        (let* ((match (car all-matches))
               (target-buf (car match))
               (target-pos (cadr match)))
          (evil-set-jump)
          (set-window-buffer current-win target-buf)
          (select-window current-win)
          (set-buffer target-buf)
          
          (goto-char target-pos)
          
          ;; ---> LANDING SPOT 4: KILL BEACON <---
          (let ((landed-ov nil))
            (dolist (ov (overlays-at target-pos))
              (when (eq (overlay-get ov 'my-preview-state) 'beacon-hidden)
                (setq landed-ov ov)))
            (when landed-ov
              (let ((inhibit-read-only t))
                (save-excursion
                  (goto-char target-pos)
                  (end-of-line)
                  (forward-char 1)
                  (ignore-errors
                    (when (and (fboundp 'org-transclusion-within-transclusion-p)
                               (org-transclusion-within-transclusion-p))
                      (org-transclusion-remove)))
                  (let ((was-modified (buffer-modified-p)))
                    (ignore-errors (delete-region (1- (line-beginning-position)) (line-end-position)))
                    (set-buffer-modified-p was-modified))))
              (delete-overlay landed-ov)
              (message "Beacon deactivated at landing site!")))
          
          (recenter)
          (message "Teleported directly to single prose transclusion!"))

      ;; MULTIPLE MATCHES: Spawn pristine prose picker
      (let ((picker-buf (get-buffer-create "*Org Transclusions Prose*")))
        (with-current-buffer picker-buf
          (let ((inhibit-read-only t))
            (erase-buffer)

            (dolist (match all-matches)
              (let* ((m-buf  (car match))
                     (m-pos  (cadr match))
                     (m-file (or (buffer-file-name m-buf) (buffer-name m-buf)))
                     (m-line (with-current-buffer m-buf
                               (save-excursion
                                 (goto-char m-pos)
                                 (line-number-at-pos))))
                     (m-text (with-current-buffer m-buf
                               (save-excursion
                                 (goto-char m-pos)
                                 (buffer-substring-no-properties
                                  (line-beginning-position)
                                  (line-end-position))))))
                (insert (propertize m-file 'font-lock-face 'compilation-info)
                        ":"
                        (propertize (number-to-string m-line) 'font-lock-face 'compilation-line-number)
                        ":"
                        m-text "\n")))

            (special-mode)

            (setq-local my/org-transclusion-prose-jump-matches all-matches)
            (setq-local my/org-transclusion-prose-jump-source-win current-win)

            (evil-local-set-key 'normal (kbd "RET") 'my/org-transclusion-picker-jump-prose)
            (evil-local-set-key 'motion (kbd "RET") 'my/org-transclusion-picker-jump-prose)
            (local-set-key (kbd "RET") 'my/org-transclusion-picker-jump-prose)
            (local-set-key (kbd "<return>") 'my/org-transclusion-picker-jump-prose)

            (goto-char (point-min))))

        (switch-to-buffer picker-buf)
        (delete-other-windows)
        (message "Multiple active prose transclusions found (%d). Press RET to teleport." (length all-matches))))))

;; =====================================================================
;; 5. THE PROSE HELPER (Picker)
;; =====================================================================
(defun my/org-transclusion-picker-jump-prose ()
  "Jump to the prose transclusion selected in the picker."
  (interactive)
  (let* ((matches    (and (boundp 'my/org-transclusion-prose-jump-matches) 
                          my/org-transclusion-prose-jump-matches))
         (source-win (and (boundp 'my/org-transclusion-prose-jump-source-win) 
                          my/org-transclusion-prose-jump-source-win))
         (line-num   (line-number-at-pos))
         (match      (nth (1- line-num) matches)))
    
    (unless match
      (user-error "No match on this line!"))
      
    (let ((target-buf (car match))
          (target-pos (cadr match)))
      (unless (buffer-live-p target-buf)
        (user-error "Target buffer is no longer live!"))
        
      (evil-set-jump)
      
      (let ((win (if (window-live-p source-win) source-win (selected-window))))
        (set-window-buffer win target-buf)
        (select-window win)
        (set-buffer target-buf)
        (goto-char target-pos)
        
        ;; ---> LANDING SPOT 5: KILL BEACON <---
        (let ((landed-ov nil))
          (dolist (ov (overlays-at target-pos))
            (when (eq (overlay-get ov 'my-preview-state) 'beacon-hidden)
              (setq landed-ov ov)))
          (when landed-ov
            (let ((inhibit-read-only t))
              (save-excursion
                (goto-char target-pos)
                (end-of-line)
                (forward-char 1)
                (ignore-errors
                  (when (and (fboundp 'org-transclusion-within-transclusion-p)
                             (org-transclusion-within-transclusion-p))
                    (org-transclusion-remove)))
                (let ((was-modified (buffer-modified-p)))
                  (ignore-errors (delete-region (1- (line-beginning-position)) (line-end-position)))
                  (set-buffer-modified-p was-modified))))
            (delete-overlay landed-ov)
            (message "Beacon deactivated at landing site!")))
            
        (recenter)
        (delete-other-windows)
        (message "Teleported directly to prose transclusion!")))))

;; ==========================================
;; FULLSCREEN TAKEOVER JUMP LOGIC
;; ==========================================

(defvar-local my/org-references-current-id nil
  "Buffer-local variable storing the ID being searched in the references buffer.")

(defun my/org-goto-link-column (&optional exact-id)
  "Position cursor on the whitespace just before the link or transclude keyword.
If EXACT-ID is provided, searches for that specific ID on the current line."
  (let ((limit (line-end-position))
        (found nil))
    (if exact-id
        (when (search-forward exact-id limit t)
          (goto-char (match-beginning 0))
          ;; Step back to the beginning of the transclude keyword or link syntax
          (when (re-search-backward "\\(#\\+transclude:\\|\\[\\[id:\\|id:\\)" (line-beginning-position) t)
            (goto-char (match-beginning 1)))
          (setq found t))
      ;; Fallback generic search if exact-id is unknown
      (when (re-search-forward "\\(#\\+transclude:\\|\\[\\[id:\\|id:\\)" limit t)
        (goto-char (match-beginning 1))
        (setq found t)))
    
    (when found
      ;; If the previous character is a space or tab, step back onto it
      (when (and (> (point) (line-beginning-position))
                 (memq (char-before) '(?\s ?\t)))
        (backward-char)))))

(defun my/org-references-jump-replace ()
  "Replace the window with target file, and kill list buffer."
  (interactive)
  (let ((list-buf (current-buffer))
        (line-str (thing-at-point 'line t))
        (roam-dir (expand-file-name org-roam-directory))
        (search-id my/org-references-current-id) ;; Grab the ID we saved earlier
        target-file target-line)
    
    (when (and line-str (string-match "^\\(.*?\\):\\([0-9]+\\):" line-str))
      (setq target-file (expand-file-name (match-string 1 line-str) roam-dir)
            target-line (string-to-number (match-string 2 line-str))))
    
    (if (not target-file)
        (message "No reference found on this line.")
      (find-file target-file)
      (goto-char (point-min))
      (forward-line (1- target-line))
      
      ;; ---> NEW: Adjust the column! <---
      (my/org-goto-link-column search-id)
      
      (recenter)
      (ignore-errors (kill-buffer list-buf))
      (message "Teleported successfully."))))

(defun my/org-transclusion-backlinks ()
  "Show notes transcluding this ID. 
Instantly jumps if exactly 1. Spawns a PRISTINE fullscreen list if 2+."
  (interactive)
  (let ((id (org-id-get)))
    (if (not id)
        (message "No :ID: property found in this file")
      (let* ((search-str (concat "id:" id))
             (roam-dir (expand-file-name org-roam-directory))
             (grep-cmd (format "cd %s && grep -rnH --include='*.org' %s ."
                               (shell-quote-argument roam-dir)
                               (shell-quote-argument search-str)))
             (output (shell-command-to-string grep-cmd))
             (lines (split-string output "\n" t)))
        (cond
         ((null lines)
          (message "No back-references found for ID: %s" id))
         
         ((= (length lines) 1)
          (if (string-match "^\\(.*?\\):\\([0-9]+\\):" (car lines))
              (let ((file (expand-file-name (match-string 1 (car lines)) roam-dir))
                    (line (string-to-number (match-string 2 (car lines)))))
                (find-file file)
                (goto-char (point-min))
                (forward-line (1- line))
                
                ;; Adjust the column for the single match
                (my/org-goto-link-column id)
                
                (delete-other-windows)
                (message "Jumped to the single reference."))
            (message "Could not parse output: %s" (car lines))))
         
         (t
          (require 'compile)
          (let ((buf (get-buffer-create "*Org References*")))
            (with-current-buffer buf
              (let ((inhibit-read-only t))
                (erase-buffer)
                (setq default-directory (file-name-as-directory roam-dir))
                
                (dolist (line lines)
                  (let ((clean-line (if (string-prefix-p "./" line)
                                        (substring line 2)
                                      line)))
                    (if (string-match "^\\(.*?\\):\\([0-9]+\\):\\(.*\\)$" clean-line)
                        (let ((f-name (match-string 1 clean-line))
                              (l-num  (match-string 2 clean-line))
                              (text   (match-string 3 clean-line)))
                          (insert (propertize f-name 'font-lock-face 'compilation-info)
                                  ":"
                                  (propertize l-num 'font-lock-face 'compilation-line-number)
                                  ":"
                                  text "\n"))
                      (insert clean-line "\n"))))
                
                ;; Initialize mode FIRST
                (special-mode)
                
                ;; ---> FIX: Store the ID locally AFTER special-mode clears local variables <---
                (setq-local my/org-references-current-id id)
                
                (evil-local-set-key 'normal (kbd "RET") 'my/org-references-jump-replace)
                (evil-local-set-key 'motion (kbd "RET") 'my/org-references-jump-replace)
                (local-set-key (kbd "RET") 'my/org-references-jump-replace)
                (local-set-key (kbd "<return>") 'my/org-references-jump-replace)
                
                (goto-char (point-min))))
            
            (switch-to-buffer buf)
            (delete-other-windows)
            (message "Showing %d references. Press RET to teleport." (length lines)))))))))

;; UPDATED: Strict Exact-Link Jumping
(defun my/org-transclusion-open-source-at-point ()
  "Jump to source file from inside a transclusion, or exactly on an ID link."
  (interactive)
  (let* ((context (org-element-context))
         (type (car context)))
    (cond
     ;; 1. Inside an active expanded transclusion block
     ((org-transclusion-within-transclusion-p)
      (org-transclusion-open-source))
      
     ;; 2. Cursor is EXACTLY on an ID link (no more guessing)
     ((and (eq type 'link) (string= (org-element-property :type context) "id"))
      (let ((id (org-element-property :path context)))
        (org-id-goto id)
        (message "Opened source: %s" id)))
        
     ;; 3. Scan the line if it has a `#+transclude:` keyword ANYWHERE
     ((save-excursion
        (beginning-of-line)
        (re-search-forward "#\\+transclude:" (line-end-position) t))
      (save-excursion
        (beginning-of-line)
        (if (re-search-forward "id:\\([0-9a-fA-F-]+\\)" (line-end-position) t)
            (let ((id (match-string 1)))
              (org-id-goto id)
              (message "Opened transclude source: %s" id))
          (message "No ID link found on this transclude line."))))
          
     ;; 4. Otherwise, do strictly nothing.
     (t
      (message "No ID link exactly under cursor. Move cursor onto the link!")))))

(defun my/org-transclusion-remove-at-point ()
  "Remove the transclusion — works whether
   cursor is inline OR inside the expanded content."
  (interactive)
  (if (org-transclusion-within-transclusion-p)
      (org-transclusion-remove)
    (when (save-excursion
            (beginning-of-line)
            (re-search-forward "#\\+transclude:" (line-end-position) t))
      (save-excursion
        (beginning-of-line)
        (re-search-forward "#\\+transclude:[ \t]*" (line-end-position) t)
        (org-transclusion-remove))
      (message "Transclusion removed"))))

(use-package org-download
  :straight (:host github :repo "abo-abo/org-download")
  :hook ((dired-mode . org-download-enable)
         (org-mode . org-download-enable))
  :custom
  (org-download-image-dir (concat org-roam-directory "/images")))

(use-package org-capture
  :straight nil
  :custom
  (org-default-notes-file (concat org-roam-directory "/inbox.org"))
  (org-capture-templates
   '(("i" "Inbox / Fleeting Note" entry (file org-default-notes-file)
      "* %?\n%U\n%i" :empty-lines 1)))
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n c") 'org-capture))

(use-package org-appear
  :straight (:host github :repo "awth13/org-appear")
  :hook (org-mode . org-appear-mode)
  :custom
  (org-hide-emphasis-markers t)
  (org-appear-autoemphasis t)
  (org-appear-autolinks nil)      ;; <-- TURNED OFF AUTO-UNFOLDING
  (org-appear-autosubmarkers t))

(use-package org-id
  :straight nil ; built into Emacs
  :custom
  (org-id-track-globally t)
  (org-id-link-to-org-use-id 'create-if-interactive-and-no-custom-alist)
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n u") 'org-id-get-create)) ; 'u' for Unique ID

  ;; ==========================================
  ;; LAZY ORG-ID UPDATER
  ;; ==========================================
  (defun my/lazy-org-id-update (orig-fn id &rest args)
    "Philosophy: Only update broken links when I actually try to jump to them."
    (condition-case nil ;; <-- 'err' changed to 'nil'
        ;; Step 1: Try to jump normally. If it works, great.
        (apply orig-fn id args)
      
      ;; Step 2: Catch the error if the link is broken (file moved)
      (error
       (if (y-or-n-p (format "Link broken (ID: %s)! Scan a directory to find it? " id))
           (let ((scan-dir (read-directory-name "Folder to scan: " "~/rnd/")))
             (message "Scanning %s for missing IDs..." scan-dir)
             
             ;; Step 3: Find all .org files and update the Emacs phone book
             (org-id-update-id-locations (directory-files-recursively scan-dir "\\.org$"))
             
             ;; Step 4: Automatically retry the jump
             (condition-case nil
                 (apply orig-fn id args)
               (error (message "Still couldn't find the ID. Are you sure it's in there?"))))
         (message "Jump cancelled.")))))

  ;; Apply our lazy-loader to the core ID jump function
  (advice-add 'org-id-goto :around #'my/lazy-org-id-update) ;; <-- THE MISSING PARENTHESIS IS HERE!

;; Enable C/C++ execution in Org Babel
(require 'ob-C)

;; Get lua
(use-package lua-mode
  :straight (:host github :repo "immerrr/lua-mode")
  :ensure t
  :mode "\\.lua\\'"
  :custom
  (lua-indent-level 2)) ; Change to 4 if you prefer wider indents

;; Get nix
(use-package nix-mode
  :straight (:host github :repo "NixOS/nix-mode")
  :mode "\\.nix\\'")

;; ==========================================
;; SPC n p now ALWAYS inserts [[id:UUID][title]] 
;; (strips the ::diag-matrix crap completely)
;; ==========================================
(defun my/org-insert-link-clean ()
  "Insert link as [[id:UUID][title]] — completely removes any ::search part."
  (interactive)
  (if (null org-stored-links)
      (message "No stored link! Do SPC n y first.")
    (let* ((link-info (car org-stored-links))
           (raw-link (car link-info))
           (desc (or (cadr link-info) "Link")))
      ;; Strip everything after :: (removes ::diag-matrix or any target)
      (when (string-match "\\(id:[^:]+\\)::" raw-link)
        (setq raw-link (match-string 1 raw-link)))
      (insert (format "[[%s][%s]]" raw-link desc)))))

;; ==========================================
;; Smart SPC n y on headings → stores clean [[id:UUID][Heading Name]]
;; ==========================================
(defun my/org-store-link-smart ()
  "Store link as [[id:UUID][Heading Text]] when cursor is on a heading."
  (interactive)
  (org-store-link nil t))

;;(evil-define-key 'normal 'global
  ;;(kbd "<leader> n y") #'my/org-store-link-smart   ; 'y' for Yank link
  ;;(kbd "<leader> n p") #'my/org-insert-link-clean)

;; ==========================================
;; 6. Setup Eshell & Eat 
;; ==========================================

(defun my/eshell-in-dir (target-dir)
  "Helper function to open Eshell in TARGET-DIR, or cd into it if already running."
  (let ((default-directory target-dir))
    (eshell))
  (when (and (eq major-mode 'eshell-mode)
             (not (string= (file-name-as-directory (expand-file-name default-directory))
                           (file-name-as-directory (expand-file-name target-dir)))))
    (goto-char (point-max))
    (insert (format "cd '%s'" target-dir))
    (eshell-send-input)))

(defun my/eshell-workspace ()
  "Open Eshell. If a workspace is locked via my-speed-dial, open it there."
  (interactive)
  (let ((target-dir (if (and (boundp 'my/current-workspace-root)
                             my/current-workspace-root)
                        my/current-workspace-root
                      default-directory)))
    (my/eshell-in-dir target-dir)))

(defun my/eshell-current-file-dir ()
  "Open Eshell in the directory of the currently visited file/buffer."
  (interactive)
  (my/eshell-in-dir default-directory))

(use-package eat
  :straight (:host codeberg :repo "akib/emacs-eat")
  :hook ((eshell-load . eat-eshell-visual-command-mode)
         (eshell-load . eat-eshell-mode))

  :init
  (with-eval-after-load 'evil
    (evil-define-key 'normal 'global
      (kbd "<leader> e w") 'my/eshell-workspace
      (kbd "<leader> e f") 'my/eshell-current-file-dir))
  :config
  (evil-set-initial-state 'eat-mode 'emacs))

(defun eshell/vi (&rest files)
  "Alias the vi command to `find-file' in Eshell. Opens files directly in Emacs."
  (if files
      (mapc #'find-file files)
    (message "Usage: vi <filename>")))

(defun my/eshell-clear-buffer ()
  "Instantly clear the Eshell buffer, like `clear' in bash."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (eshell-send-input)))

(add-hook 'eshell-mode-hook
          (lambda ()
            (local-set-key (kbd "C-l") 'my/eshell-clear-buffer)))

;; Bind Alt-j and Alt-k to navigate history in Eshell's insert mode
(with-eval-after-load 'esh-mode
  (with-eval-after-load 'evil
    (evil-define-key 'insert eshell-mode-map
      (kbd "M-k") 'eshell-previous-matching-input-from-input
      (kbd "M-j") 'eshell-next-matching-input-from-input)))

;; ==========================================
;; The Ultimate Zsh-like Completion Fix for Eshell + Corfu
;; ==========================================
(with-eval-after-load 'pcomplete
  (defun my/pcomplete-capf-fix-dir-space (orig-fn &rest args)
    "Ensure that `pcomplete' does not append a space after a directory."
    (let ((res (apply orig-fn args)))
      ;; Check if pcomplete returned a valid completion list
      (when (and res (listp res))
        (let ((exit-fn (plist-get (nthcdr 3 res) :exit-function)))
          (when exit-fn
            ;; Override the exit function
            (plist-put (nthcdr 3 res) :exit-function
                       (lambda (str status)
                         ;; If the string ends in a slash, it's a directory! Bind the 
                         ;; termination string to "" (no space). Otherwise, let it be a space.
                         (let ((pcomplete-termination-string
                                (if (and (stringp str) (string-suffix-p "/" str))
                                    ""
                                  (if (boundp 'pcomplete-termination-string)
                                      pcomplete-termination-string
                                    " "))))
                           (funcall exit-fn str status)))))))
      res))
  
  ;; Apply the wrapper to Eshell's completion engine
  (advice-add 'pcomplete-completions-at-point :around #'my/pcomplete-capf-fix-dir-space))

;; ---------------------------------------------------
;; Make Corfu popups work in Terminal (emacs -nw)
;; ---------------------------------------------------
(use-package corfu-terminal
  :straight (:host codeberg :repo "akib/emacs-corfu-terminal")
  ;; Only load this if we are running in a terminal
  :unless (display-graphic-p)
  :config
  (corfu-terminal-mode +1))

;; ==========================================
;; 7. Setup Standard Bookmarks
;; ==========================================

(require 'bookmark)

(setq bookmark-save-flag nil)
(add-hook 'kill-emacs-hook #'bookmark-save)

(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "<leader> b l") 'bookmark-bmenu-list)
  (evil-define-key 'normal 'global (kbd "<leader> b s") 'bookmark-set)
  (evil-define-key 'normal 'global (kbd "<leader> b j") 'bookmark-jump))

(with-eval-after-load 'evil
  (evil-set-initial-state 'bookmark-bmenu-mode 'emacs))

(add-hook 'bookmark-bmenu-mode-hook
          (lambda ()
            (define-key bookmark-bmenu-mode-map (kbd "j") 'next-line)
            (define-key bookmark-bmenu-mode-map (kbd "k") 'previous-line)
            (define-key bookmark-bmenu-mode-map (kbd "<escape>") 'quit-window)))

;; ==========================================
;; 8. Install and Setup ef-themes
;; ==========================================

(use-package ef-themes
  :straight (:host github :repo "protesilaos/ef-themes")
  :config
  ;; Load our local theme file
  (let ((theme-file (expand-file-name "local-theme.el" user-emacs-directory)))
    (if (file-exists-p theme-file)
        (load theme-file)
      ;; Ultimate fallback just in case the file gets deleted somehow
      (load-theme 'ef-orange t)))

  ;; 1. Define custom completion specifically for ef-themes
  (evil-ex-define-argument-type ef-theme-name
    "Completion for ef-themes."
    :collection (lambda (string predicate action)
                  (let ((themes (mapcan (lambda (sym)
                                          (let ((name (symbol-name sym)))
                                            (if (string-prefix-p "ef-" name)
                                                (list name))))
                                        (custom-available-themes))))
                    (complete-with-action action themes string predicate))))

  ;; 2. Properly define the Evil command
  (evil-define-command evil-ef-theme-select (theme)
    "Select an ef-theme with Evil Ex command."
    (interactive "<a>")
    (let ((clean-theme (when theme (string-trim theme))))
      (if (and clean-theme (not (string-empty-p clean-theme)))
          (progn
            ;; Disable current themes to prevent color bleeding
            (mapc #'disable-theme custom-enabled-themes)
            ;; Load the requested theme cleanly
            (load-theme (intern clean-theme) t))
        ;; Fallback: if you just type `:colo` and hit Enter
        (call-interactively 'ef-themes-select))))

  ;; 3. Tell Evil Ex to use our custom completion list for this command
  (evil-set-command-property 'evil-ef-theme-select :ex-arg 'ef-theme-name)

  ;; 4. Bind the command to Vim's standard :colo and :colorscheme
  (evil-ex-define-cmd "colo" 'evil-ef-theme-select)
  (evil-ex-define-cmd "colorscheme" 'evil-ef-theme-select)

  ;; 5. Toggle keybind
  (evil-define-key 'normal 'global
    (kbd "<leader> t t") 'ef-themes-toggle))

;; ==========================================
;; 9. Elfeed & Elfeed-Org
;; ==========================================

(use-package elfeed
  :straight (:host github :repo "skeeto/elfeed")
  :custom
  (elfeed-use-curl t)
  (elfeed-search-filter "@6-months-ago ")
  
  :config
  ;; ----------------------------------------------------
  ;; 🎬 THE "PLAY YOUTUBE IN MPV" FUNCTION
  ;; (Kept this here so you can still press 'v' to watch videos!)
  ;; ----------------------------------------------------
  (defun my/elfeed-play-with-mpv ()
    "Play the current Elfeed entry's video link in mpv."
    (interactive)
    (let ((link (if (derived-mode-p 'elfeed-search-mode)
                    (elfeed-entry-link (elfeed-search-selected :ignore-region))
                  (elfeed-entry-link elfeed-show-entry))))
      (if link
          (progn
            (message "🚀 Launching mpv for: %s" link)
            (start-process "elfeed-mpv" nil "mpv" link))
        (message "❌ No link found!"))))

  (with-eval-after-load 'evil
    (evil-define-key 'normal elfeed-search-mode-map (kbd "v") 'my/elfeed-play-with-mpv)
    (evil-define-key 'normal elfeed-show-mode-map (kbd "v") 'my/elfeed-play-with-mpv)))

;; Install and setup elfeed-org
(use-package elfeed-org
  :straight (:host github :repo "remyhonig/elfeed-org")
  :after elfeed
  :config
  ;; Initialize elfeed-org
  (elfeed-org)
  ;; Tell it where to find your "folders" file (we will create this in Step 2)
  (setq rmh-elfeed-org-files (list (expand-file-name "elfeed.org" user-emacs-directory))))

;; ==========================================
;; 10. PDF Tools (The ultimate PDF viewer)
;; ==========================================

;; Tell Emacs not to warn us about large files unless they are over 50MB
(setq large-file-warning-threshold (* 80 1024 1024))

(use-package pdf-tools
  :straight (:host github :repo "vedang/pdf-tools")
  :mode ("\\.pdf\\'" . pdf-view-mode) 
  :hook ((pdf-view-mode . pdf-view-midnight-minor-mode)
         ;; FIX 1: Move this here! Now it registers before pdf-tools even loads.
         ;; Emacs will safely disable line numbers before the display engine crashes.
         (pdf-view-mode . (lambda () (display-line-numbers-mode -1))))
  :config
  
  ;; FIX 2: Add 't' (no-query). This prevents Emacs from deadlocking if it
  ;; needs to compile or start the epdfinfo server in the background.
  (pdf-tools-install t)
  
  ;; Turn on Emacs' built-in memory for where your cursor was
  (save-place-mode 1)
  
  ;; ==========================================
  ;; FIX: Dynamic PDF Colors on Theme Change
  ;; ==========================================
  (defun my/pdf-update-colors-on-theme-change (&rest _)
    "Update PDF midnight colors and refresh all open PDFs when theme changes."
    ;; We use a tiny timer because Emacs needs a split-second to actually 
    ;; apply the new theme's faces to the frame before we can read them.
    (run-with-timer 0.1 nil
      (lambda ()
        ;; 1. Update midnight colors to the newly loaded theme's default faces
        (setq pdf-view-midnight-colors (cons (face-foreground 'default)
                                             (face-background 'default)))
        ;; 2. Look through all open buffers for PDFs
        (dolist (buffer (buffer-list))
          (with-current-buffer buffer
            (when (eq major-mode 'pdf-view-mode)
              ;; Clear out the old cached images
              (when (fboundp 'pdf-info-invalidate-image-caches)
                (pdf-info-invalidate-image-caches))
              ;; Toggle midnight mode off and on to force a re-render
              (when pdf-view-midnight-minor-mode
                (pdf-view-midnight-minor-mode -1)
                (pdf-view-midnight-minor-mode 1))))))))

  ;; Attach our function to Emacs' load-theme command
  (advice-add 'load-theme :after #'my/pdf-update-colors-on-theme-change))

  ;; ==========================================
  ;; Show Full PDF Chapter Hierarchy (On-Demand)
  ;; ==========================================

(defun my/pdf-show-full-path ()
  "Show the full chapter hierarchy for the current PDF page.
Displays the calculated breadcrumb path in the echo area."
  (interactive)
    (if (not (and (eq major-mode 'pdf-view-mode)
                  (pdf-info-running-p)))
        (message "PDF server is not ready or not in a PDF buffer.")
      (let ((current-page (pdf-view-current-page))
            (outline (pdf-info-outline))
            (path (make-vector 20 nil))
            (best-path-list nil))
        (if (not outline)
            (message "No outline (table of contents) found for this PDF.")
          (dolist (node outline)
            (let* ((node-page (alist-get 'page node))
                   (node-depth (alist-get 'depth node))
                   (raw-title (alist-get 'title node))
                   (node-title (if (stringp raw-title)
                                   (replace-regexp-in-string "[ \t\n\r]+" " " raw-title)
                                 "")))
              (when (and (numberp node-page) 
                         (<= node-page current-page)
                         (numberp node-depth)
                         (> node-depth 0))
                (when (>= node-depth (length path))
                  (setq path (vconcat path (make-vector node-depth nil))))
                (aset path (1- node-depth) node-title)
                (let ((i node-depth))
                  (while (< i (length path))
                    (aset path i nil)
                    (setq i (1+ i))))
                (setq best-path-list (append path nil)))))
          
          (let ((best-title (when best-path-list
                              (mapconcat #'identity 
                                         (delq nil (mapcar (lambda (x) (and (stringp x) (not (string-empty-p x)) x)) 
                                                           best-path-list)) 
                                         " ➔ "))))
            (if (or (null best-title) (string-empty-p best-title))
                (message "Page %d is not inside any chapter." current-page)
              ;; Display in echo area (will expand multi-line automatically if long)
              (message best-title)))))))

;; Bind "O" to Outline and "P" to show the Full Path
(with-eval-after-load 'pdf-tools
  (with-eval-after-load 'evil
    (evil-define-key 'normal pdf-view-mode-map (kbd "O") #'pdf-outline)
    (evil-define-key 'normal pdf-view-mode-map (kbd "P") #'my/pdf-show-full-path)))

(use-package saveplace-pdf-view
  :straight (:host github :repo "nicolaisingh/saveplace-pdf-view")
  :after pdf-tools)

;; ==========================================
;; Allow Evil Leader (Spacebar) to work in PDFs
;; ==========================================
(with-eval-after-load 'pdf-tools
  ;; 1. Unbind Emacs' default scroll-down behavior for Spacebar
  (define-key pdf-view-mode-map (kbd "SPC") nil)
  
  (with-eval-after-load 'evil
    ;; 2. Explicitly tell Evil to let the global leader pass through in PDF mode
    (evil-define-key 'normal pdf-view-mode-map (kbd "SPC") nil)))

;; ==========================================
;; 11. Global LSP & Autocompletion (C/C++, Python, Bash)
;; ==========================================

;; Add this before your Corfu and Eglot configs
(use-package yasnippet
  :straight (:host github :repo "joaotavora/yasnippet")
  :config
  (yas-global-mode 1))

;; Tell Emacs that .cppm files are C++ files so they get colors and LSP
(add-to-list 'auto-mode-alist '("\\.cppm\\'" . c++-mode))

;; 1. Setup Corfu for modern, lightweight auto-completion popups
(use-package corfu
  :straight (:host github :repo "minad/corfu")
  :custom
  (corfu-auto nil)              ;; NO automatic popup while typing
  (corfu-cycle t)               ;; Allow cycling from bottom back to top
  (corfu-quit-no-match t)
  (corfu-preselect 'first)      ;; Always highlight the first option automatically
  (corfu-preview-current nil)   ;; DO NOT inject or change text while cycling
  :init
  (global-corfu-mode)
  :config
  ;; ========================================================
  ;; THE "ENTER CYCLES DOWN" FIX
  ;; ========================================================
  ;; Emacs forcefully translates C-j to Enter. So we just make Enter cycle down!
  ;; Note: Because C-m IS physically Enter in a terminal, it will also cycle down.
  (define-key corfu-map (kbd "RET") #'corfu-next)
  (define-key corfu-map (kbd "<return>") #'corfu-next)
  (define-key corfu-map (kbd "C-j") #'corfu-next)
  (define-key corfu-map (kbd "C-m") #'corfu-next)

  ;; Cycle UP with C-k
  (define-key corfu-map (kbd "C-k") #'corfu-previous)
  (define-key corfu-map (kbd "<C-k>") #'corfu-previous)

  ;; ========================================================
  ;; THE NEW ACCEPT KEYS
  ;; ========================================================
  ;; Since Enter/C-m now cycles, we use TAB or C-l to accept the completion!
  (define-key corfu-map (kbd "TAB") #'corfu-insert)
  (define-key corfu-map (kbd "<tab>") #'corfu-insert)
  (define-key corfu-map (kbd "C-l") #'corfu-insert)

  ;; Cancel popup with C-[ or Escape without changing anything
  (define-key corfu-map (kbd "C-[") #'corfu-quit)
  (define-key corfu-map (kbd "<escape>") #'corfu-quit)

  ;; Trigger manual completion with C-n in Evil Insert Mode
  (with-eval-after-load 'evil
    (define-key evil-insert-state-map (kbd "C-n") #'completion-at-point)))

;; 2. Setup Eglot (The built-in LSP client)
(use-package eglot
  :straight nil
  ;; 👇 BASH ADDED HERE 👇
  :hook ((c-mode c++-mode python-mode sh-mode bash-ts-mode) . eglot-ensure)
  :custom
  ;; Ignore BOTH auto-formatting on type and inlay hints
  (eglot-ignored-server-capabilities '(:documentOnTypeFormattingProvider :inlayHintProvider))
  :config
  ;; Tell Eglot to completely ignore Flymake (turns off annoying linting)
  (add-to-list 'eglot-stay-out-of 'flymake)

  (setq eglot-events-buffer-config '(:size 0 :format short))
  (with-eval-after-load 'jsonrpc
    (fset #'jsonrpc--log-event #'ignore))

  ;; C/C++: Tell Clangd to enable C++ modules AND inject our Linux formatting rules directly!
  (add-to-list 'eglot-server-programs
               '((c++-mode c-mode)
                 . ("clangd"
                    "--experimental-modules-support"
                    "--fallback-style=BasedOnStyle: LLVM, IndentWidth: 8, TabWidth: 8, UseTab: Always, BreakBeforeBraces: Linux, IndentCaseLabels: false, BinPackArguments: false, BinPackParameters: false")))

  ;; PYTHON: Tell Eglot to use basedpyright
  (add-to-list 'eglot-server-programs
               '(python-mode . ("basedpyright-langserver" "--stdio")))

  (with-eval-after-load 'evil
    (evil-define-key 'normal eglot-mode-map
      (kbd "<leader> c r") 'eglot-rename
      (kbd "<leader> c a") 'eglot-code-actions
      (kbd "<leader> c f") 'eglot-format-buffer
      (kbd "g D") 'xref-find-references)))

;; ==========================================
;; C/C++ Indentation & Formatting (Linux Style)
;; ==========================================

;; Tell the byte-compiler this variable exists to silence the warning
(defvar c-basic-offset)

;; Define a function to set C/C++ specific indentation
(defun my/c-c++-hook ()
  "Custom settings for C and C++ modes (Linus Torvalds style)."
  ;; Apply the built-in Linux kernel formatting style for Emacs typing
  (c-set-style "linux")
  
  ;; Linus mandates 8-column wide indents
  (setq c-basic-offset 8)
  (setq tab-width 8)
  
  ;; Linus strictly uses real tabs, not spaces
  (setq indent-tabs-mode t) 
  
  ;; Stop Emacs from fighting your manual line breaks
  (electric-indent-local-mode -1))

;; Add this function to the hooks for C and C++ modes
(add-hook 'c-mode-hook #'my/c-c++-hook)
(add-hook 'c++-mode-hook #'my/c-c++-hook)

;; ==========================================
;; Python Indentation & Formatting
;; ==========================================

;; Tell the byte-compiler this variable exists to silence the warning
(defvar python-indent-offset)

;; Define a function to set Python specific indentation (Spaces, no Tabs!)
(defun my/python-hook ()
  "Custom settings for Python mode."
  ;; Python strictly requires 4 spaces
  (setq python-indent-offset 4)
  (setq tab-width 4)
  
  ;; Force Emacs to use SPACES instead of tabs for Python!
  (setq indent-tabs-mode nil) 
  
  ;; Stop Emacs from fighting your manual line breaks
  (electric-indent-local-mode -1))

;; Add this function to the hook for Python mode
(add-hook 'python-mode-hook #'my/python-hook)

;; ==========================================
;; 12. Vim-like Scrolling and End-of-Buffer
;; ==========================================

;; 1. Stop Emacs from jumping half-a-page when hitting the bottom of the screen.
;; Setting this above 100 forces Emacs to only scroll 1 line at a time.
(setq scroll-conservatively 101)
(setq scroll-preserve-screen-position t)

;; 2. Show Vim-like markers in the left fringe for the "void" past the end of the file.
;; (In Vim this is the ~ character, in Emacs it's a graphical line).
(setq-default indicate-empty-lines t)

;; 3. Redefine 'G' to ignore the empty POSIX newline at the end of the file
(with-eval-after-load 'evil
  (evil-define-motion my/evil-goto-line-vim-behavior (count)
    "Go to the last non-empty line, Vim style."
    :type line
    :jump t
    (let ((col (current-column))
          (tgc temporary-goal-column))
      (if count
          (evil-goto-line count)
        (evil-goto-line))
      ;; If we landed in the empty void at the end, step back one line
      (when (and (eobp) (bolp) (not (bobp)))
        (forward-line -1)
        ;; Instead of snapping to the first letter, perfectly preserve the visual column!
        (move-to-column col)
        (setq temporary-goal-column tgc))))

  ;; Bind our new 'G' in Evil's motion state (so dG, yG, etc., all still work perfectly)
  (evil-define-key 'motion 'global (kbd "G") 'my/evil-goto-line-vim-behavior))
;; ==========================================
;; Stop 'j' from stepping into the EOF void
;; ==========================================

;; 1. Never add new lines automatically when holding 'j' at the bottom
(setq next-line-add-newlines nil)

;; 2. Tell Evil to bounce back if it steps onto the empty POSIX newline
(defun my/evil-avoid-eof-newline (orig-fun &rest args)
  "Prevent `j' from stepping into the empty POSIX newline at buffer end."
  (let ((tgc temporary-goal-column)
        (col (current-column)))
    (apply orig-fun args)
    (when (and (eobp) (bolp) (not (bobp)))
      ;; We stepped into the void! Undo it with raw Lisp so Evil doesn't corrupt the column
      (forward-line -1)
      ;; Warp back to the exact column you were on
      (move-to-column col)
      ;; Secretly restore the goal column so pressing 'k' remembers your original long line
      (setq temporary-goal-column tgc)
      (message "End of file"))))

;; Apply this rule to both standard 'j' and visual-line 'j'
(advice-add 'evil-next-line :around #'my/evil-avoid-eof-newline)
(advice-add 'evil-next-visual-line :around #'my/evil-avoid-eof-newline)
;; ==========================================
;; Rescue the cursor from the EOF void globally
;; ==========================================

(defun my/evil-rescue-from-eof-void ()
  "Rescue cursor if dropped into EOF void by commands like `dd' or `p'."
  (when (and (evil-normal-state-p)
             (eobp)
             (bolp)
             (not (bobp)))
    ;; Step back up to the actual text
    (forward-line -1)
    ;; Vim's default behavior when deleting the last line is to snap the 
    ;; cursor to the first non-blank character. This perfectly replicates it!
    (back-to-indentation)))

(add-hook 'post-command-hook #'my/evil-rescue-from-eof-void)

;; ==========================================
;; Rescue Visual State from the EOF void
;; ==========================================

(defun my/evil-visual-rescue-from-eof-void ()
  "Prevent visual selection from dragging into the empty EOF newline."
  (when (and (evil-visual-state-p)
             (eobp)            ;; We are at the absolute end of the buffer
             (bolp)            ;; We are at the beginning of a line
             (not (bobp)))     ;; We aren't in an entirely empty file
    
    ;; We stepped into the void newline during a visual selection.
    ;; 1. Step backward one character to get back onto the last real line
    (backward-char 1)
    
    ;; 2. Tell Evil to update the visual selection region to end here,
    ;; preventing the highlight from spilling into the void.
    (evil-visual-refresh)))

;; Attach it to the global command hook so it checks after every movement
(add-hook 'post-command-hook #'my/evil-visual-rescue-from-eof-void)

;; ==========================================
;; Close PDF Outline windows with ESC / C-[
;; ==========================================

(with-eval-after-load 'pdf-outline
  ;; When in the PDF Outline buffer, make Escape and Ctrl-[ close the window
  (evil-define-key 'normal pdf-outline-buffer-mode-map
    (kbd "<escape>") 'quit-window
    (kbd "C-[") 'quit-window))

;; ==========================================
;; Disable Vim jumping motions inside PDFs (Bulletproof)
;; ==========================================

(with-eval-after-load 'pdf-tools
  ;; 1. Disable gg and G on the mode map level
  (evil-define-key '(normal motion) pdf-view-mode-map
    (kbd "G")   'ignore
    (kbd "gg")  'ignore)
  
  ;; 2. C-o is stubborn and often hijacked by Evil's global jump list 
  ;; or evil-collection. We must forcefully disable it at the absolute 
  ;; local buffer level the moment the PDF opens.
  (add-hook 'pdf-view-mode-hook
            (lambda ()
              (evil-local-set-key 'normal (kbd "C-o") 'ignore)
              (evil-local-set-key 'motion (kbd "C-o") 'ignore))))

;; ==========================================
;; Make Emacs Auto-Saves act EXACTLY like Vim Swap Files
;; ==========================================

(require 'cl-lib)

;; ==========================================
;; 1. NUKE THE 1-SECOND PAUSE
;; ==========================================
(defun my/fast-after-find-file (orig-fn &rest args)
  "Bypass the hardcoded 1-second pause when opening files."
  (cl-letf (((symbol-function 'sit-for) #'ignore))
    (apply orig-fn args)))

(advice-add 'after-find-file :around #'my/fast-after-find-file)

;; ==========================================
;; 2. THE VIM-BALANCED AUTO-SAVE ENGINE & CURSOR TRACKER
;; ==========================================

;; 1. Match Vim's Exact Aggressiveness (Using Emacs' optimized C engine)
;; We throw away the custom timers. Emacs does this natively and much faster.
(setq auto-save-timeout 4)    ;; Vim's `updatetime` (4 seconds of idle time)
(setq auto-save-interval 200) ;; Vim's `updatecount` (200 keystrokes)

;; 2. Instant Vim Swap Creation on the First Keystroke
(defun my/instant-vim-swap-on-first-keystroke ()
  (when (and buffer-file-name (not buffer-read-only))
    (let ((inhibit-message t))
      (do-auto-save t t))))

(add-hook 'first-change-hook #'my/instant-vim-swap-on-first-keystroke)

;; 3. FIX: The Bulletproof Cursor Tracker (The Sidecar)
(defun my/save-point-during-auto-save (&rest _)
  "Save cursor position to a side-car file whenever Emacs auto-saves."
  (when (and buffer-file-name buffer-auto-save-file-name)
    (ignore-errors
      (write-region (number-to-string (point)) nil 
                    (concat buffer-auto-save-file-name ".point") nil 'silent))))

(add-hook 'auto-save-hook #'my/save-point-during-auto-save)
(advice-add 'do-auto-save :after #'my/save-point-during-auto-save)

;; 4. Ensure manual autosaves (like our first-change-hook) also track the cursor
(advice-add 'do-auto-save :after #'my/save-point-during-auto-save)

;; ==========================================
;; 3. QUIET VIM-STYLE RECOVERY (RESTORING TEXT & CRASH CURSOR)
;; ==========================================
(defun my/vim-style-quiet-recovery-prompt ()
  "Prompt for recovery in the minibuffer only, and restore exact crash cursor."
  (when (and buffer-file-name
             buffer-auto-save-file-name
             (file-exists-p buffer-auto-save-file-name)
             (file-newer-than-file-p buffer-auto-save-file-name buffer-file-name))
    (run-with-idle-timer 0.1 nil
                         (lambda (buf)
                           (when (buffer-live-p buf)
                             (with-current-buffer buf
                               (if (y-or-n-p "Recover from auto-save file? ")
                                   (let ((fallback-point (point))
                                         (point-file (concat buffer-auto-save-file-name ".point"))
                                         (crash-point nil))
                                     
                                     ;; 1. Try to read the exact cursor position from the side-car file
                                     (when (file-exists-p point-file)
                                       (with-temp-buffer
                                         (insert-file-contents point-file)
                                         (setq crash-point (string-to-number (buffer-string)))))
                                     
                                     ;; 2. Recover the text seamlessly
                                     (insert-file-contents buffer-auto-save-file-name nil nil nil t)
                                     
                                     ;; 3. Put the cursor EXACTLY where it was during the crash
                                     (if (and crash-point (> crash-point 0) (<= crash-point (point-max)))
                                         (goto-char crash-point)
                                       (goto-char fallback-point))
                                     
                                     (set-buffer-modified-p t)
                                     (message "Recovered successfully."))
                                 
                                 ;; If 'n' is pressed, trash the auto-save AND the side-car cursor file
                                 (when (y-or-n-p "Delete the orphaned auto-save file? ")
                                   (delete-file buffer-auto-save-file-name)
                                   (when (file-exists-p (concat buffer-auto-save-file-name ".point"))
                                     (delete-file (concat buffer-auto-save-file-name ".point")))
                                   (message "Auto-save file deleted."))))))
                         (current-buffer))))

(add-hook 'find-file-hook #'my/vim-style-quiet-recovery-prompt)

;; ==========================================
;; 4. UNBYPASSABLE CLEANUP & VIM :q / :q! GUARDRAILS
;; ==========================================
(defun my/assassinate-autosave ()
  "Deletes the auto-save file, the point file, and unlinks them."
  (when buffer-auto-save-file-name
    (when (file-exists-p buffer-auto-save-file-name)
      (ignore-errors (delete-file buffer-auto-save-file-name)))
    (when (file-exists-p (concat buffer-auto-save-file-name ".point"))
      (ignore-errors (delete-file (concat buffer-auto-save-file-name ".point"))))
    ;; CRUCIAL: Give Emacs amnesia
    (setq buffer-auto-save-file-name nil)))

;; Intercept Evil's :q and :q! directly
(defun my/evil-quit-cleanup (orig-fn &optional force)
  "Mimic Vim's :q and :q! by refusing to exit or prompt if files are unsaved."
  (let* ((windows-left (length (window-list)))
         (is-last-window (<= windows-left 1))
         ;; Find any modified files that are NOT the current buffer
         (other-modified-buffers
          (cl-remove-if-not
           (lambda (buf)
             (and (buffer-modified-p buf)
                  (buffer-file-name buf)
                  (not (eq buf (current-buffer)))))
           (buffer-list))))
    
    (if force
        ;; =====================
        ;; HANDLE :q! (FORCE QUIT)
        ;; =====================
        (progn
          ;; 1. VIM GUARDRAIL: Refuse to exit entirely if OTHER files have unsaved changes
          (when (and is-last-window other-modified-buffers)
            (let ((first-other (buffer-name (car other-modified-buffers))))
              (user-error "E162: No write since last change for buffer \"%s\". Use :qa! to discard all." first-other)))
          
          ;; 2. Safe to proceed: nuke the CURRENT buffer's autosave
          (my/assassinate-autosave)
          ;; 3. Trick Emacs into thinking this buffer is saved so it discards changes
          (set-buffer-modified-p nil)
          
          ;; 4. Execute the quit command silently (ignore background processes)
          (let ((confirm-kill-processes nil))
            (funcall orig-fn force)))
      
      ;; =====================
      ;; HANDLE :q (NORMAL QUIT)
      ;; =====================
      (progn
        ;; 1. If the CURRENT buffer is modified, instantly block :q (NO PROMPTS!)
        (when (and (buffer-modified-p) (buffer-file-name))
          (user-error "E37: No write since last change (add ! to override)"))
        
        ;; 2. If it's the last window and OTHER buffers are modified, block :q
        (when (and is-last-window other-modified-buffers)
          (let ((first-other (buffer-name (car other-modified-buffers))))
            (user-error "E162: No write since last change for buffer \"%s\"" first-other)))
        
        ;; 3. Safe to proceed! Execute quit with NO interactive conversations.
        ;; Everything is guaranteed saved at this point. We also squelch process warnings.
        (let ((confirm-kill-processes nil))
          (funcall orig-fn force))))))

(advice-add 'evil-quit :around #'my/evil-quit-cleanup)

;; General hooks for standard buffer kills
(defun my/unbypassable-buffer-cleanup (&optional buffer-or-name &rest _)
  (let ((buf (get-buffer (or buffer-or-name (current-buffer)))))
    (when (and buf (buffer-live-p buf))
      (with-current-buffer buf (my/assassinate-autosave)))))

(advice-add 'kill-buffer :before #'my/unbypassable-buffer-cleanup)

;; Catch-all for :qa! or normal exits
(advice-add 'kill-emacs :before (lambda (&rest _) 
                                  (dolist (buf (buffer-list))
                                    (with-current-buffer buf (my/assassinate-autosave)))))

;; ==========================================
;; 5. CENTRALIZED HOUSEKEEPING (NEOVIM STYLE)
;; ==========================================

;; Define the centralized directory (similar to ~/.local/state/nvim/swap/)
(defvar my/emacs-recovery-dir (expand-file-name "~/.local/state/emacs/recovery/"))

;; Create the directory if it doesn't exist
(unless (file-exists-p my/emacs-recovery-dir)
  (make-directory my/emacs-recovery-dir t))

;; 1. ROUTE BACKUP FILES (~) TO THE CENTRAL DIRECTORY
;; We keep backups enabled for safety, but out of sight!
(setq make-backup-files t
      vc-make-backup-files t) ; Even make backups for files in Git
(setq backup-directory-alist `(("." . ,my/emacs-recovery-dir)))

;; 2. ROUTE AUTO-SAVE FILES (#) TO THE CENTRAL DIRECTORY
;; The 't' at the end tells Emacs to flatten the path (turn / into !) 
;; so files with the same name from different projects don't overwrite each other.
(setq auto-save-file-name-transforms `((".*" ,my/emacs-recovery-dir t)))

;; 3. ROUTE LOCKFILES (.#) TO THE CENTRAL DIRECTORY (Emacs 28+)
;; Lockfiles prevent two Emacs instances from editing the same file simultaneously.
(setq create-lockfiles t)
(when (boundp 'lock-file-name-transforms)
  (setq lock-file-name-transforms `((".*" ,my/emacs-recovery-dir t))))

;; 4. CLEAN UP SIDECARS ON NORMAL SAVE (:w)
;; Because buffer-auto-save-file-name now points to ~/.local/state/emacs/recovery/...,
;; your .point files are ALREADY being created in the central directory automatically!
;; We still want to sweep them up so the recovery folder doesn't get massive over time.
(defun my/cleanup-sidecar-on-normal-save ()
  "Delete the .point side-car file when the buffer is properly saved."
  (when buffer-auto-save-file-name
    (let ((point-file (concat buffer-auto-save-file-name ".point")))
      (when (file-exists-p point-file)
        (ignore-errors (delete-file point-file))))))

(add-hook 'after-save-hook #'my/cleanup-sidecar-on-normal-save)

;; 5. CLEAN UP ON KILL-BUFFER (Just in case)
(defun my/cleanup-sidecar-on-kill ()
  (unless (buffer-modified-p)
    (my/cleanup-sidecar-on-normal-save)))

(add-hook 'kill-buffer-hook #'my/cleanup-sidecar-on-kill)

;; Force TRAMP to use the local centralized auto-save directory
(setq tramp-auto-save-directory my/emacs-recovery-dir)

;; ==========================================
;; 6. VSCode-Style Function/Symbol Outline
;; ==========================================

(use-package imenu-list
  :straight (:host github :repo "bmag/imenu-list")
  :custom
  ;; Put the side-pane on the right (like VSCode) instead of the left
  (imenu-list-position 'right)
  ;; How wide the side pane should be
  (imenu-list-size 40)
  ;; Automatically focus the side-pane when you open it
  (imenu-list-focus-after-activation t)
  :config
  ;; Bind it to Leader + c + o (Code Outline)
  (with-eval-after-load 'evil
    (evil-define-key 'normal 'global (kbd "<leader> c o") 'imenu-list-smart-toggle)
    
    ;; Make Vim keys work smoothly inside the outline pane
    (evil-define-key 'normal imenu-list-major-mode-map
      (kbd "RET") 'imenu-list-ret-dwim
      (kbd "SPC") 'imenu-list-display-dwim
      (kbd "<escape>") 'imenu-list-quit-window
      (kbd "q") 'imenu-list-quit-window)))

;; =========================================
;; Avy: Jump to any place on the screen
;; =========================================
(use-package avy
  :straight (:host github :repo "abo-abo/avy")
  :ensure t
  :custom
  (avy-timeout-seconds 0.1)
  (avy-keys '(?a ?s ?d ?f ?j ?k ?l ?\;))
  
  :config
  (with-eval-after-load 'evil
    ;; 1. Global bindings for standard files
    (define-key evil-motion-state-map (kbd "g k") #'evil-avy-goto-char-timer)
    (define-key evil-normal-state-map (kbd "g k") #'evil-avy-goto-char-timer)
    
    ;; 2. Create a reusable "bulletproof" function
    (defun my/force-avy-gk ()
      "Force \"g k\" to trigger avy, bypassing stubborn major modes."
      (evil-local-set-key 'normal (kbd "g k") #'evil-avy-goto-char-timer)
      (evil-local-set-key 'motion (kbd "g k") #'evil-avy-goto-char-timer))
    
    ;; 3. Apply it to any stubborn modes (add more here in the future if needed)
    (add-hook 'org-mode-hook #'my/force-avy-gk)
    (add-hook 'grep-mode-hook #'my/force-avy-gk)
    (add-hook 'compilation-mode-hook #'my/force-avy-gk)
    
    ))

;; =========================================
;; make copy pasting xclip compliant
;; =========================================
(use-package xclip
  :straight (:host github :repo "emacsmirror/xclip")
  :ensure t
  :config
  (xclip-mode 1))


;; =========================================
;; Global Dape Settings (Language Agnostic)
;; =========================================

(use-package dape
  :straight (:host github :repo "svaante/dape")
  :ensure t
  :hook
  (kill-emacs . dape-breakpoint-save)
  (after-init . dape-breakpoint-load)
  (dape-quit-hook . dape-kill-buffers)

  :config
  (dape-breakpoint-global-mode)
  
  ;; 1. Stop Dape from automatically arranging a giant layout
  (setq dape-buffer-window-arrangement nil)
  
  ;; 2. Stop Dape from automatically popping open windows when debugging starts
  (remove-hook 'dape-start-hook 'dape-info)
  (remove-hook 'dape-start-hook 'dape-repl))

;; Auto-close compilation window on success
(add-hook 'compilation-finish-functions
          (lambda (buf str)
            (when (string-match "finished" str)
              (let ((win (get-buffer-window buf)))
                (when win
                  (delete-window win))))))

;; =========================================
;; Dape Modal Popup Helpers
;; =========================================

(defun my-dape--pop-info (buf-name mode-fn)
  "Safely open a Dape info buffer,
   forcing initialization so it's
   never a dummy file."
  (save-window-excursion (ignore-errors (dape-info)))
  (let ((buf (get-buffer-create buf-name)))
    (with-current-buffer buf
      ;; Force the buffer into the correct Dape UI mode so it's never a blank text file
      (unless (derived-mode-p mode-fn)
        (funcall mode-fn)))
    (pop-to-buffer-same-window buf)))

(defun my-dape-open-repl ()
  "Switch to the live Dape REPL perfectly in the same window."
  (interactive)
  ;; Intercept Dape's internal window splitting logic.
  ;; When dape-repl tries to pop open *dape-repl*, this catches it
  ;; and forces it into the current full window instead.
  (let ((display-buffer-alist '(("\\*dape-repl\\*" (display-buffer-same-window)))))
    (dape-repl)))

(defun my-dape-open-stack ()
  "Switch to ONLY the Stack Trace window."
  (interactive)
  (my-dape--pop-info "*dape-info Stack*" 'dape-info-stack-mode))

(defun my-dape-open-locals ()
  "Switch to ONLY the Locals window to inspect variables."
  (interactive)
  (if (get-buffer "*dape-info Locals*")
      (my-dape--pop-info "*dape-info Locals*" 'dape-info-scope-mode)
    (my-dape--pop-info "*dape-info Scope*" 'dape-info-scope-mode)))

(defun my-dape-open-breakpoints ()
  "Switch to ONLY the Breakpoints window."
  (interactive)
  (my-dape--pop-info "*dape-info Breakpoints*" 'dape-info-breakpoints-mode))

(defun my-dape-open-threads ()
  "Switch to ONLY the Threads window."
  (interactive)
  (my-dape--pop-info "*dape-info Threads*" 'dape-info-threads-mode))

(defun my-dape-open-watch ()
  "Switch to ONLY the Watch window."
  (interactive)
  (my-dape--pop-info "*dape-info Watch*" 'dape-info-watch-mode))

(defun my-dape-goto-stopped-line ()
  "Jump perfectly back to the active debugger line (where the arrow is).
Reads Emacs' native fringe arrow markers directly, completely avoiding 
Dape's internal API to prevent runtime crashes and compiler warnings."
  (interactive)
  (let ((target-buf nil)
        (target-pos nil))
    (catch 'found
      
      ;; METHOD 1: Check standard Emacs fringe arrows
      ;; Dape pushes its execution marker here so Emacs can draw the visual arrow.
      (dolist (var overlay-arrow-variable-list)
        (when (and (boundp var)
                   (markerp (symbol-value var))
                   (marker-buffer (symbol-value var)))
          (let ((m (symbol-value var)))
            ;; Ignore markers in weird popup buffers, only target real files
            (when (buffer-file-name (marker-buffer m))
              (setq target-buf (marker-buffer m)
                    target-pos (marker-position m))
              (throw 'found t)))))
      
      ;; METHOD 2: Visually scan for Dape overlays (Fallback)
      (dolist (buf (buffer-list))
        (when (buffer-file-name buf)
          (with-current-buffer buf
            (dolist (ov (overlays-in (point-min) (point-max)))
              (let ((cat  (overlay-get ov 'category))
                    (face (overlay-get ov 'face)))
                (when (or (and cat  (string-match-p "dape" (symbol-name cat)))
                          (and face (string-match-p "dape" (symbol-name face))))
                  (setq target-buf buf
                        target-pos (overlay-start ov))
                  (throw 'found t))))))))
    
    ;; EXECUTE JUMP
    (if target-buf
        (progn
          (switch-to-buffer target-buf)
          (goto-char target-pos)
          (recenter))
      (message "Dape: Could not locate the active debugging arrow marker."))))

(defun my-dape-quit-window ()
  "Bulletproof exit: return perfectly to the code.
Skips over multiple Dape modal hops to land directly on the source."
  (interactive)
  (let ((source-buf nil))
    ;; 1. Look through Emacs' history of recently used buffers
    (catch 'found
      (dolist (buf (buffer-list))
        (let ((name (buffer-name buf)))
          ;; Ignore hidden buffers (start with space) and ALL Dape buffers
          (unless (or (string-prefix-p " " name)
                      (string-prefix-p "*dape-" name))
            (setq source-buf buf)
            (throw 'found t)))))
    
    ;; 2. Push the current Dape buffer to the bottom of the list
    (bury-buffer)
    
    ;; 3. Instantly switch straight back to the source code buffer
    (when source-buf
      (switch-to-buffer source-buf))))

;; =========================================
;; Dape Global Debug Keybindings
;; =========================================

(with-eval-after-load 'evil
  (with-eval-after-load 'dape
    (require 'hydra)
    
    ;; FIX: Read-only buffers start in 'motion' state, not 'normal'.
    ;; This hook forces highest-priority local keys for BOTH states,
    ;; ensuring SPC d is never ignored or swallowed by Emacs scrolling.
    ;; (Using functions inside a hook also prevents all byte-compiler warnings)
    (defun my-dape-setup-modal-keys ()
      "Force `q' and `SPC d' strictly into the local buffer map."
      (evil-local-set-key 'normal (kbd "q") 'my-dape-quit-window)
      (evil-local-set-key 'normal (kbd "SPC d") 'hydra-dape/body)
      (evil-local-set-key 'normal (kbd "SPC a") 'hydra-speed-dial/body) ;; <-- Added

      (evil-local-set-key 'motion (kbd "q") 'my-dape-quit-window)
      (evil-local-set-key 'motion (kbd "SPC d") 'hydra-dape/body)
      (evil-local-set-key 'motion (kbd "SPC a") 'hydra-speed-dial/body)) ;; <-- Added

    (add-hook 'dape-info-stack-mode-hook 'my-dape-setup-modal-keys)
    (add-hook 'dape-info-scope-mode-hook 'my-dape-setup-modal-keys)
    (add-hook 'dape-info-breakpoints-mode-hook 'my-dape-setup-modal-keys)
    (add-hook 'dape-info-threads-mode-hook 'my-dape-setup-modal-keys)
    (add-hook 'dape-info-watch-mode-hook 'my-dape-setup-modal-keys)

    ;; 🚨 REPL TERMINAL FIX 🚨
    (add-hook 'dape-repl-mode-hook
              (lambda ()
                (evil-local-set-key 'normal (kbd "q") 'my-dape-quit-window)
                (evil-local-set-key 'normal (kbd "SPC d") 'hydra-dape/body)
                (evil-local-set-key 'normal (kbd "SPC a") 'hydra-speed-dial/body) ;; <-- Added

                (evil-local-set-key 'motion (kbd "SPC d") 'hydra-dape/body)
                (evil-local-set-key 'motion (kbd "SPC a") 'hydra-speed-dial/body))) ;; <-- Added

    ;; -----------------------------------------
    ;; THE DAPE HYDRA
    ;; -----------------------------------------
    (defhydra hydra-dape (:color pink :hint nil)
      "
^EXECUTION^        ^STEPPING^         ^BREAKPOINTS^        ^MODAL POPUPS^
^^^^^^^^----------------------------------------------------------------------
_d_: Start         _n_: Next          _b_: Toggle BP       _e_: REPL
_r_: Restart       _i_: Step In       _D_: Clear All       _l_: Locals
_c_: Continue      _o_: Step Out      _B_: BP List         _w_: Watch
_q_: Stop/Quit     _a_: Go to Arrow   ^ ^                  _s_: Stack
^ ^                ^ ^                ^ ^                  _t_: Threads
"
      ;; Execution
      ("d" my-dape-start-dispatch :color blue)
      ("q" dape-quit :color blue)
      
      ;; Stepping & Flow
      ("r" dape-restart)
      ("c" dape-continue)
      ("n" dape-next)
      ("i" dape-step-in)
      ("o" dape-step-out)
      ("a" my-dape-goto-stopped-line :color blue)

      ;; Breakpoints
      ("b" dape-breakpoint-toggle)
      ("D" dape-breakpoint-remove-all)

      ;; Modal Popups (Maps strictly to your functions, closes hydra on trigger)
      ("e" my-dape-open-repl :color blue)
      ("s" my-dape-open-stack :color blue)
      ("l" my-dape-open-locals :color blue)
      ("B" my-dape-open-breakpoints :color blue)
      ("t" my-dape-open-threads :color blue)
      ("w" my-dape-open-watch :color blue)

      ;; Cancel
      ("<escape>" nil "cancel" :color blue))

    ;; Bind SPC d to open the Hydra globally for normal code buffers
    (evil-define-key 'normal 'global (kbd "SPC d") 'hydra-dape/body)))

;; =========================================
;; Universal Dape Dispatcher System
;; =========================================

(defvar my-dape-dispatch-alist nil
  "An alist mapping major modes to specific Dape startup functions.
Format: \\='((mode1 mode2) . custom-start-function)")

(defun my-dape-start-dispatch ()
  "Silently route the debugger to the correct function based on language."
  (interactive)
  (let ((dispatcher nil))
    ;; Search the alist for the current major mode
    (catch 'found
      (dolist (entry my-dape-dispatch-alist)
        (when (memq major-mode (car entry))
          (setq dispatcher (cdr entry))
          (throw 'found t))))
    
    ;; Execute the specific logic, or fallback to standard Dape prompt
    (if dispatcher
        (funcall dispatcher)
      (call-interactively 'dape))))

;; =========================================
;; Load Dape Language Modules
;; =========================================
;; Add the dape folder to the load path
(add-to-list 'load-path (expand-file-name "lisp/dape" user-emacs-directory))

;; Load the specific language debuggers
(require 'cpp)
(require 'bash)

(easy-menu-define my-custom-jump-menu global-map
  "My custom menu for jump commands."
  '("Jump"  
    ["menu-mode" my/speed-dial-menu-mode t]
    ["menu" my-force-menu t]  ;; <--- Now calls your new trick function
    ["command-mode" my/speed-dial-command-mode t]))

(defun my-force-menu ()
  "First run menu-mode, then open the speed dial hydra."
  (interactive) ;; <--- This makes it usable in menus/keybindings
  (my/speed-dial-menu-mode)
  (hydra-speed-dial/body))

;; =========================================================
;; GLOBAL BINDINGS (Active when Evil Mode is OFF)
;; =========================================================

;; --- 1. The "Smart" CUA Layer (VS Style) ---
;; This single line natively enables smart C-x / C-c / C-v 
;; WITHOUT breaking the C-x prefix!
(cua-mode 1)

;; --- 2. Standard Global Keys ---
(global-set-key (kbd "C-s") 'save-buffer)
(global-set-key (kbd "C-q") 'save-buffers-kill-terminal)
(global-set-key (kbd "C-z") 'undo)
(global-set-key (kbd "C-f") 'isearch-forward)
(global-set-key (kbd "C-a") 'mark-whole-buffer)

;; --- 3. Custom Speed-Dial Functions ---
(global-set-key (kbd "C-n") 'my/speed-dial-menu-mode)
(global-set-key (kbd "C-t") 'my-force-menu)
(global-set-key (kbd "C-p") 'my/speed-dial-command-mode)

;; Notice it is "<escape>", not "ESC". 
;; <escape> represents the physical key in GUI environments.
;(define-key key-translation-map (kbd "<escape>") (kbd "C-g"))

;(defun my-smart-gui-escape (prompt)
;  "Translate <escape> to C-g only when evil-mode is OFF."
;  (if (bound-and-true-p evil-local-mode)
;      nil           ;; Evil is ON: Do nothing, let Evil use <escape> normally
;    (kbd "C-g")))   ;; Evil is OFF: Translate <escape> to C-g

;(define-key key-translation-map (kbd "<escape>") 'my-smart-gui-escape)

;; ==========================================
;; M-x vim : Toggle Evil & Tmux Escape
;; ==========================================

(defun vim ()
  "Toggles `evil-mode` and adjusts Tmux Escape behavior automatically.
When Evil is ON, Tmux leaves Escape alone so Vim works normally.
When Evil is OFF, Tmux binds Escape to send C-g for standard Emacs usage."
  (interactive)
  
  ;; Safely toggle evil-mode on or off
  (if evil-mode
      (evil-mode -1)
    (evil-mode 1))
  
  ;; Check if we are running inside Tmux
  (if (not (getenv "TMUX"))
      ;; If not in Tmux, just print the Evil mode state
      (message "Vim mode is now %s (Not in Tmux)" (if evil-mode "ON" "OFF"))
    
    ;; If we ARE in Tmux, adjust the Tmux Escape binding
    (if evil-mode
        ;; IF EVIL IS ON:
        ;; Unbind Escape in Tmux so it passes straight through to Evil
        (progn
          (call-process "tmux" nil nil nil "unbind-key" "-n" "Escape")
          (message "VIM MODE ON: Emacs Escape Restored"))
      
      ;; IF EVIL IS OFF:
      ;; Bind Escape to send C-g for standard Emacs behavior
      (progn
        (call-process "tmux" nil nil nil "bind-key" "-n" "Escape" "send-keys" "C-g")
        (message "VIM MODE OFF: Escape sends C-g")))))

;; ------------------------------------------
;; STARTUP SAFETY SYNC
;; ------------------------------------------
;; When Emacs starts, force Tmux to match our initial mode.
;; Since Emacs starts with Evil disabled, this forces Escape to send C-g.
(when (getenv "TMUX")
  (if (bound-and-true-p evil-mode)
      (call-process "tmux" nil nil nil "unbind-key" "-n" "Escape")
    (call-process "tmux" nil nil nil "bind-key" "-n" "Escape" "send-keys" "C-g")))
