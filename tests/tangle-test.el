(require 'cl-lib)

(defun my/visual-autopilot-test ()
  "Visual test: Create C++, :org-it, :tangle, cursor inside code -> g m -> g c."
  (interactive)
  (let* ((test-dir "/tmp/emacs-autopilot/")
         (cpp-file (concat test-dir "diagonal.cpp")))

    ;; 0. NUKE DANGLING BUFFERS
    ;; (kill-buffer-query-functions nil ensures Emacs doesn't ask to save modified buffers)
    (let ((kill-buffer-query-functions nil))
      (ignore-errors (kill-buffer "diagonal.cpp"))
      (ignore-errors (kill-buffer "diagonal.cpp.org")))

    ;; 1. Clean slate on the hard drive
    (when (file-exists-p test-dir)
      (delete-directory test-dir t))
    (make-directory test-dir t)
    (delete-other-windows)

    ;; 2. CREATE C++ FILE FIRST
    (message "🎬 1. Creating raw C++ file...")
    (find-file cpp-file)
    (erase-buffer)
    (insert "#include <iostream>\n\nint main() {\n    std::cout << \"Hello!\\n\";\n    return 0;\n}\n")
    (save-buffer)
    (sit-for 1.5)

    ;; 3. RUN :org-it (With Autopilot "Yes" Override)
    (message "🎬 2. Running :org-it...")
    (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
      (my/org-it))
    (sit-for 1.5)

    ;; 5. MOVE CURSOR DEEP INTO THE CODE
    (message "🎬 4. Moving cursor to 'std::cout' inside the code block...")
    
    ;; 1. FORCE the generated org file to take over the screen
    (find-file (concat cpp-file ".org")) 

    ;; 2. Clear any narrowing so we can search the whole file
    (widen)
    (goto-char (point-min))

    ;; 3. Search 
    (if (search-forward "std::cout" nil t)
        (progn
          (backward-char 4) ;; Put cursor on 'cout'
          
          ;; 4. FORCE the visual screen cursor to match the background buffer cursor
          (set-window-point (selected-window) (point))
          
          ;; 5. Center the screen on the cursor so it's impossible to miss
          (recenter) 
          
          (message "✅ SUCCESS: Cursor is now on std::cout!"))
      
      ;; If it fails, print the start of the buffer so we can see WHY it failed
      (message "❌ FAILED: 'std::cout' not found! Buffer starts with: \n%s" 
               (buffer-substring-no-properties (point-min) (min (point-max) 200))))

    ;; Redraw the screen immediately before sleeping
    (redisplay)
    (sit-for 1.5)

    ;; 4. TANGLE
    (message "🎬 3. Running :tangle...")
    (my-quiet-tangle)
    (sit-for 1.5)

    ;; 7. DRILL DOWN (g m)
    (message "🎬 5. Pressing 'g m' (Drill Down) -> jumping to C++ file...")
    (my/org-jump-drill-down)
    (sit-for 2.0)

    ;; 7. SURFACE UP (g c)
    (message "🎬 6. Pressing 'g c' (Surface Up) -> jumping back to Org file...")
    (my/org-jump-surface-up)
    (sit-for 2.0)

    (message "✅ AUTOPILOT COMPLETE! The g m / g c math is flawless.")))
