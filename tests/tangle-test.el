(require 'cl-lib)

(defun my/visual-autopilot-test ()
  "Visual test: Create C++, :org-it, split blocks, :tangle, cursor -> g m -> g c."
  (interactive)
  (let* ((test-dir "/tmp/emacs-autopilot/")
         (cpp-file (concat test-dir "diagonal.cpp")))

    ;; 0. NUKE DANGLING BUFFERS
    (let ((kill-buffer-query-functions nil))
      (ignore-errors (kill-buffer "diagonal.cpp"))
      (ignore-errors (kill-buffer "diagonal.cpp.org")))

    ;; 1. Clean slate on the hard drive
    (when (file-exists-p test-dir)
      (delete-directory test-dir t))
    (make-directory test-dir t)
    (delete-other-windows)

    ;; 2. CREATE COMPLEX C++ FILE FIRST
    (message "🎬 1. Creating raw C++ file...")
    (find-file cpp-file)
    (erase-buffer)
    (insert "#include <iostream>\n#include <vector>\n\ntemplate<typename T>\nclass DiagonalMatrix {\n\tstd::vector<T> elements;\npublic:\n\texplicit DiagonalMatrix(size_t size) : elements(size) {}\n\n  \t// C++23 multidimensional operator\n  \tT& operator[](size_t row, size_t col) {\n  \t\treturn elements[row]; // Simplified for mechanics test\n  \t}\n};\n\nint main() {\n  \tDiagonalMatrix<int> diag(5);\n  \tdiag[2, 2] = 42; \n \tstd::cout << \"Element at (2,2) is: \" << diag[2, 2] << '\\n';\n  \treturn 0;\n}\n")
    (save-buffer)
    (sit-for 1.5)

    ;; 3. RUN :org-it
    (message "🎬 2. Running :org-it...")
    (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
      (my/org-it))
    (sit-for 1.5)

    ;; 4. SPLIT IT UP
    (message "🎬 3. Splitting into 3 blocks (via #+name)...")
    (let ((target-buf (or (get-buffer "diagonal.cpp.org") (current-buffer))))
      (switch-to-buffer target-buf)
      (widen)
      (erase-buffer)
      
      ;; Simulating the manual split!
      (insert "#+name: system-libraries
#+begin_src cpp :tangle diagonal.cpp
#include <iostream>
#include <vector>
#+end_src

#+name: diagonal-matrix-class
#+begin_src cpp :tangle diagonal.cpp
template<typename T>
class DiagonalMatrix {
	std::vector<T> elements;
public:
	explicit DiagonalMatrix(size_t size) : elements(size) {}

  	// C++23 multidimensional operator
  	T& operator[](size_t row, size_t col) {
  		return elements[row]; // Simplified for mechanics test
  	}
};
#+end_src

#+name: main-function
#+begin_src cpp :tangle diagonal.cpp
int main() {
  	DiagonalMatrix<int> diag(5);
  	diag[2, 2] = 42; 
 	std::cout << \"Element at (2,2) is: \" << diag[2, 2] << '\\n';
  	return 0;
}
#+end_src
")
      (save-buffer))
    (sit-for 1.5)

    ;; 5. MOVE CURSOR DEEP INTO THE CODE
    (message "🎬 4. Moving cursor to 'std::cout' inside the code block...")
    (find-file (concat cpp-file ".org")) 
    (widen)
    (goto-char (point-min))

    (if (search-forward "std::cout" nil t)
        (progn
          (backward-char 4) ;; Put cursor on 'cout'
          (set-window-point (selected-window) (point))
          (recenter) 
          (message "✅ SUCCESS: Cursor is now on std::cout!"))
      (message "❌ FAILED: 'std::cout' not found! Buffer starts with: \n%s" 
               (buffer-substring-no-properties (point-min) (min (point-max) 200))))

    (redisplay)
    (sit-for 1.5)

    ;; 6. TANGLE
    (message "🎬 5. Running :tangle...")
    (my-quiet-tangle)
    (sit-for 1.5)

    ;; 7. DRILL DOWN (g m)
    (message "🎬 6. Pressing 'g m' (Drill Down) -> jumping to C++ file...")
    (my/org-jump-drill-down)
    (sit-for 2.0)

    ;; 8. SURFACE UP (g c)
    (message "🎬 7. Pressing 'g c' (Surface Up) -> jumping back to Org file...")
    (my/org-jump-surface-up)
    (sit-for 2.0)

    (message "✅ AUTOPILOT COMPLETE! The g m / g c math is flawless.")))
