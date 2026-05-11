;;; bash.el --- Bash Debugging logic for Dape -*- lexical-binding: t; -*-
(defun my-dape-start-bash ()
  "Start bash-debug-adapter for the current script."
  (interactive)
  (let* ((cwd (dape-cwd))
         (script-file (buffer-file-name)))
    
    (unless script-file
      (error "🚨 FATAL: You must be visiting an actual script file to debug it!"))
    
    (let* ((arg-str (read-string (format "Args for %s (blank for none): " (file-name-nondirectory script-file))))
           (dape-args (if (string-empty-p arg-str) 
                          [] 
                        (vconcat (split-string arg-str " "))))
           
           ;; 1. Find bashdb in your PATH (this is the symlink)
           (bashdb-symlink (executable-find "bashdb"))
           
           ;; 2. Follow the symlink to the pure /nix/store/.../bin/bashdb path
           (bashdb-real (when bashdb-symlink 
                          (file-truename bashdb-symlink)))
           
           ;; 3. Calculate the library path using the REAL Nix store directory
           (bashdb-lib (when bashdb-real 
                         (expand-file-name "../share/bashdb" (file-name-directory bashdb-real)))))
      
      (dape (list 'command "bash-debug-adapter"
                  :type "bashdb"
                  :request "launch"
                  :cwd cwd
                  :program script-file
                  :args dape-args
                  :env '(:DAPE_BASH_WORKAROUND "1")
                  
                  :pathBashdb (or bashdb-symlink "bashdb")
                  
                  ;; THE FIX: Pass the absolute /nix/store/.../share/bashdb path
                  :pathBashdbLib (or bashdb-lib "")
                  
                  :pathBash   (or (executable-find "bash") "bash")
                  :pathCat    (or (executable-find "cat") "cat")
                  :pathMkfifo (or (executable-find "mkfifo") "mkfifo")
                  :pathPkill  (or (executable-find "pkill") "pkill")))))) ;; Register to the global dispatcher
(add-to-list 'my-dape-dispatch-alist
             '((sh-mode bash-ts-mode) . my-dape-start-bash))

(provide 'bash)
;;; bash.el ends here
