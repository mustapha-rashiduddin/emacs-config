;;; cpp.el --- C/C++ Debugging logic for Dape -*- lexical-binding: t; -*-

;; =========================================
;; Universal Interactive Target Selector (C++)
;; =========================================
(defun my-dape-prompt-target (cwd)
  "Prompt user to select between prog, all, or specific tests."
  (let* ((options '())
         (has-app (file-exists-p (expand-file-name "main.cpp" cwd)))
         (test-files (ignore-errors (directory-files cwd nil "^test_.*\\.cpp$")))
         (current-base (when-let ((file (buffer-file-name))) (file-name-base file))))
    
    (when has-app (push "prog" options))
    (when test-files
      (push "all" options)
      (dolist (f test-files)
        (let ((base (file-name-base f)))
          (when (string-prefix-p "test_" base)
            (push (substring base 5) options)))))
            
    (setq options (nreverse options))
    (unless options
      (error "🚨 FATAL: No main.cpp or test_*.cpp files found in project!"))
      
    (let ((default-choice
           (cond
            ((string= current-base "main") "prog")
            ((and current-base (string-prefix-p "test_" current-base))
             (substring current-base 5))
            ((and current-base (member current-base options)) current-base)
            ((member "all" options) "all")
            (t (car options)))))
      (completing-read "Select Debug Target: " options nil t nil nil default-choice))))

;; =========================================
;; Dape Startup Logic (C++)
;; =========================================
(defun my-dape-start-cpp ()
  "Start GDB with Xmake for C/C++."
  (let* ((cwd (dape-cwd))
         (choice (my-dape-prompt-target cwd))
         (is-app (string= choice "prog"))
         (target-name (if is-app "prog" "test"))
         (bin-path (expand-file-name (format "bin/%s" target-name) cwd))
         (catch2-tag (cond
                      (is-app nil)
                      ((string= choice "all") nil)
                      (t (format "[%s]" choice))))
         (dape-args (if catch2-tag (vector catch2-tag) []))
         (compile-cmd (format "NO_COLOR=1 xmake f -m debug && xmake build %s" target-name)))
    
    (dape (list 'command "gdb"
                'command-args '("--interpreter=dap")
                :request "launch"
                :cwd cwd
                :args dape-args 
                :program bin-path
                'compile compile-cmd))))

;; Register to the global dispatcher!
(add-to-list 'my-dape-dispatch-alist
             '((c-mode c-ts-mode c++-mode c++-ts-mode) . my-dape-start-cpp))

;; =========================================
;; Xmake Project Deployer
;; =========================================
(defun eshell/xmake_deploy ()
  "Instantly deploy the master xmake.lua template to the current directory."
  (let* ((template-file (expand-file-name "xmake-template.lua" user-emacs-directory))
         (target-file   (expand-file-name "xmake.lua" default-directory)))
    (unless (file-exists-p template-file)
      (error "🚨 Template not found! Please save your xmake.lua to %s" template-file))
    (if (file-exists-p target-file)
        (message "⚠️ xmake.lua already exists here! Aborting to prevent overwrite.")
      (copy-file template-file target-file)
      (let ((default-directory default-directory))
        (call-process "xmake" nil nil nil "f" "-m" "debug"))
      (message "✅ Successfully deployed xmake.lua and initialized project!"))))

;; ==========================================
;; Eshell Autocompletion for XMake & Catch2 Tags
;; ==========================================
(require 'pcomplete)
(require 'subr-x)

(defun my/xmake-get-physical-binaries ()
  "Gather ONLY physical binaries that exist in ./build or ./bin."
  (let ((candidates '())
        (search-dirs '("build" "bin")))
    (dolist (dir search-dirs)
      (let ((full-dir (expand-file-name dir default-directory)))
        (when (file-directory-p full-dir)
          (ignore-errors
            (dolist (file (directory-files-recursively full-dir ".*"))
              (when (and (file-executable-p file)
                         (not (file-directory-p file)))
                (push (file-name-nondirectory file) candidates)))))))
    (delete-dups candidates)))

(defun my/xmake-get-catch2-tags ()
  "Scan for test_*.cpp files and generate Catch2 tag arguments."
  (let ((candidates '()))
    (ignore-errors
      (dolist (file (directory-files default-directory nil "^test_.*\\.cpp$"))
        (let ((base (file-name-base file)))
          (when (string-prefix-p "test_" base)
            ;; test_node.cpp -> ["node"], test_list.cpp -> ["list"]
            (push (format "[\"%s\"]" (substring base 5)) candidates)))))
    (delete-dups candidates)))

(with-eval-after-load 'pcomplete
  (defun pcomplete/xmake ()
    "Custom completion for the `xmake` command in Eshell."
    (pcomplete-here '("build" "b" "run" "r" "test" "config" "f" "clean" "show" "project" "require"))
    
    (let ((subcmd (pcomplete-arg 1)))
      (cond
       ;; If running/testing: xmake run <target> <args>
       ((member subcmd '("run" "r" "test"))
        (pcomplete-here (or (my/xmake-get-physical-binaries) (pcomplete-entries)))
        
        ;; Complete Catch2 tags if the chosen binary starts with "test"
        (let ((target (pcomplete-arg 1)))
          (when (and target (string-match-p "test" target))
            (while (pcomplete-here (my/xmake-get-catch2-tags))))))
       
       ;; If config: xmake f <flags>
       ((member subcmd '("config" "f"))
        (while (pcomplete-here '("-m" "debug" "release" "asan" "tsan" "lsan" "ubsan" "-c" "--help"))))
       
       ;; Fallback for anything else
       (t
        (while (pcomplete-here (pcomplete-entries))))))))

;; ==========================================
;; Stop Backslash-Escaping Catch2 Tags (Raw Output)
;; ==========================================
(defun my/xmake-suppress-quotes (orig-fn string &rest args)
  "Prevent Emacs from backslash-escaping or single-quoting Catch2 tags.
Outputs the raw [\"tag\"] exactly as requested."
  (if (and (stringp string)
           (string-prefix-p "[\"" string)
           (string-match-p "\"\\]\\s-*$" string))
      ;; Return the absolute raw string, no quotes, no backslashes
      (string-trim string)
    (apply orig-fn string args)))

;; Apply globally to completely blanket Eshell, Corfu, Cape, and Company quoting paths
(advice-add 'eshell-quote-argument :around #'my/xmake-suppress-quotes)
(advice-add 'pcomplete-quote-argument :around #'my/xmake-suppress-quotes)
(advice-add 'comint-quote-filename :around #'my/xmake-suppress-quotes)

(provide 'cpp)
