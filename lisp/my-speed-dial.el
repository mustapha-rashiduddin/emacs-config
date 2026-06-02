;;; my-speed-dial.el --- Custom workspace speed dial (SQLite Edition) -*- lexical-binding: t; byte-compile-warnings: (not docstrings redefine) -*-
(require 'bookmark)
(require 'cl-lib)
(require 'sqlite)
(require 'pcomplete)

;; Let the compiler know about use-package
(eval-when-compile
  (require 'use-package))

;; Ensure required packages are loaded for macros
(use-package evil :ensure t)
(use-package hydra :ensure t)

;; Tell the byte-compiler about functions generated later
(declare-function hydra-speed-dial/body "my-speed-dial")
(declare-function my/refresh-speed-dial-hud "my-speed-dial")

;; ==========================================
;; 1. SQLITE DATABASE INITIALIZATION
;; ==========================================

(unless (fboundp 'sqlite-open)
  (error "Your Emacs was compiled without SQLite support! Emacs 29+ requires SQLite for this speed-dial."))

(defvar my/sd-db-file (expand-file-name "speed-dial.sqlite" "~/emacs-speed-dial/")
  "Path to the SQLite database storing speed dial slots.")

(defvar my/sd-db nil
  "The active SQLite database connection.")

(defun my/sd-init-db ()
  "Initialize the SQLite database and create schemas if they don't exist."
  (unless my/sd-db
    ;; Create the target directory if it doesn't exist yet
    (make-directory (file-name-directory my/sd-db-file) t)
    
    (setq my/sd-db (sqlite-open my/sd-db-file))
    (sqlite-execute my/sd-db "
      CREATE TABLE IF NOT EXISTS speed_dial (
        workspace TEXT,
        tag TEXT,
        slot INTEGER,
        name TEXT,
        record TEXT,
        PRIMARY KEY (workspace, tag, slot)
      )")
    (sqlite-execute my/sd-db "
      CREATE TABLE IF NOT EXISTS state (
        key TEXT PRIMARY KEY,
        value TEXT
      )")))

;; Initialize immediately upon load
(my/sd-init-db)

;; ==========================================
;; 2. GLOBAL STATE & VARIABLES
;; ==========================================

(defvar my/current-workspace-root nil
  "The manually selected workspace directory.")

(defvar my/current-speed-dial-tag nil 
  "The currently active dynamic tag (Right Hand).")

(defvar my/speed-dial-mode 'normal 
  "Can be `normal', `pick', `drop', `tag', or `untag'.")

(defvar my/pending-move-src nil
  "Cons cell (tag . slot) representing the slot being moved.")

(defvar my/pending-tag-target nil 
  "A file selected in the background waiting to be assigned a slot.")


;; ==========================================
;; 3. CORE HELPERS & UTILITIES
;; ==========================================

(defun my/get-workspace ()
  "Return the active workspace, or throw an error if none is set."
  (unless my/current-workspace-root
    (error "No workspace locked! Use <leader> a p to select your target workspace"))
  my/current-workspace-root)

(defun my/sd-get-absolute-path (record-str)
  "Extract the absolute path safely from a serialized bookmark record."
  (condition-case nil
      (let* ((data (read record-str))
             (file-path (alist-get 'filename data)))
        (when file-path (expand-file-name file-path)))
    (error nil)))

(defun my/shortest-unique-path (target-path all-paths)
  "Return the shortest suffix of TARGET-PATH that is unique among ALL-PATHS.
Perfectly steps backwards through parent directories to disambiguate names."
  (if (not target-path)
      "?"
    (let* ((exp-target (expand-file-name target-path))
           (exp-others (remove exp-target (mapcar #'expand-file-name all-paths)))
           (components (reverse (split-string exp-target "/" t)))
           (current-suffix (car components))
           (remaining-components (cdr components)))
      (while (and exp-others
                  (cl-some (lambda (other)
                             (string-suffix-p (concat "/" current-suffix) other))
                           exp-others)
                  remaining-components)
        (setq current-suffix (concat (car remaining-components) "/" current-suffix))
        (setq remaining-components (cdr remaining-components)))
      current-suffix)))

(defun my/shared-prefix-len (s1 s2)
  "Returns the length of the shared directory prefix between two paths.
Used to rank directories by 'closeness' to the current workspace."
  (let ((tc (try-completion "" (list s1 s2))))
    (cond
     ((eq tc t) (length s1))
     ((stringp tc) (length tc))
     (t 0))))

(defun my/sd-name (side num)
  "Fetch the name of the bookmark for a given side and slot number, disambiguating duplicates."
  (let ((val "-"))
    (when my/current-workspace-root
      (let* ((root my/current-workspace-root)
             (tag (if (eq side 'left) "global" my/current-speed-dial-tag)))
        (when tag
          (let ((row (sqlite-select my/sd-db 
                                    "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                    (list root tag num))))
            (when row
              (let* ((raw-name (nth 0 (car row)))
                     (record-str (nth 1 (car row)))
                     (target-path (my/sd-get-absolute-path record-str)))
                (if target-path
                    ;; ONLY fetch records for currently active tags (global + current right hand)
                    (let* ((active-tags (if my/current-speed-dial-tag
                                            (list "global" my/current-speed-dial-tag)
                                          (list "global")))
                           (placeholders (mapconcat (lambda (_) "?") active-tags ","))
                           (query (format "SELECT record FROM speed_dial WHERE workspace=? AND tag IN (%s)" placeholders))
                           (args (append (list root) active-tags))
                           (all-rows (sqlite-select my/sd-db query args))
                           (all-paths (delq nil (mapcar (lambda (r) (my/sd-get-absolute-path (car r))) all-rows))))
                      (setq val (my/shortest-unique-path target-path all-paths)))
                  (setq val raw-name))))))))
    (truncate-string-to-width val 35 0 ?\s "…")))

;; --- STATE PERSISTENCE HELPERS ---

(defun my/get-saved-workspace-tag (root)
  (let ((row (sqlite-select my/sd-db "SELECT value FROM state WHERE key=?" 
                            (list (concat "workspace_tag|" root)))))
    (when row (caar row))))

(defun my/save-workspace-tag (root tag)
  (if tag
      (sqlite-execute my/sd-db "INSERT OR REPLACE INTO state (key, value) VALUES (?, ?)" 
                      (list (concat "workspace_tag|" root) tag))
    (sqlite-execute my/sd-db "DELETE FROM state WHERE key=?" 
                    (list (concat "workspace_tag|" root)))))

(defun my/save-global-workspace-state (root)
  (sqlite-execute my/sd-db "INSERT OR REPLACE INTO state (key, value) VALUES ('global_workspace', ?)" 
                  (list root)))

(defun my/load-global-workspace-state ()
  (let ((row (sqlite-select my/sd-db "SELECT value FROM state WHERE key='global_workspace'")))
    (when row
      (let ((root (caar row)))
        (when (and root (file-exists-p root))
          (setq my/current-workspace-root root)
          (setq my/current-speed-dial-tag (my/get-saved-workspace-tag root)))))))

;; ==========================================
;; 4. WORKSPACE & TAGGING LOGIC
;; ==========================================

(defun my/lock-workspace-to-dir (dir)
  "Core logic to lock the workspace to a specific directory."
  (let* ((root (expand-file-name (file-name-as-directory dir)))
         (saved-tag (my/get-saved-workspace-tag root)))
    (setq my/current-workspace-root root)
    (setq my/current-speed-dial-tag saved-tag)
    (my/save-global-workspace-state root)
    (my/refresh-speed-dial-hud)
    (if saved-tag
        (message "Workspace locked to: %s (Restored tag: [%s])" root saved-tag)
      (message "Workspace locked to: %s" root))))

(defun my/set-workspace ()
  "Interactively select and lock a workspace via minibuffer."
  (interactive)
  (my/lock-workspace-to-dir (read-directory-name "Select workspace directory: ")))

(defun eshell/plant (&optional dir)
  "Eshell command: Lock the speed-dial workspace.
Usage: plant ~/my/project
If no directory is provided, locks to the current Eshell directory."
  (my/lock-workspace-to-dir (or dir default-directory))
  "")

(defun eshell/anchor (&optional dir)
  "Eshell command: Switch speed-dial workspace to a known database directory.
Use TAB to autocomplete, sorted by proximity to your current location."
  (if (not dir)
      (message "Usage: anchor <workspace-path> (Use TAB to autocomplete)")
    (my/lock-workspace-to-dir dir))
  "")

;; Tell the byte-compiler this is a dynamic variable used by Eshell/Pcomplete
;; This prevents the "Unused lexical variable" warning in your compilation log!
(defvar pcomplete-sort-function)

(defun pcomplete/anchor ()
  "Programmable completion for the `anchor` Eshell command.
Fetches workspaces from SQLite and sorts them by closest path proximity."
  (let* ((curr (or my/current-workspace-root default-directory))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT workspace FROM speed_dial"))
         (workspaces (mapcar #'car rows))
         ;; Sort descending by length of shared directory path
         (sorted (sort workspaces
                       (lambda (a b)
                         (let ((len-a (my/shared-prefix-len curr a))
                               (len-b (my/shared-prefix-len curr b)))
                           (if (= len-a len-b)
                               (string< a b)
                             (> len-a len-b)))))))
    ;; Disable Eshell's internal alphabetical sorting
    (let ((pcomplete-sort-function nil))
      (pcomplete-here sorted))))

(defun my/find-anchor ()
  "Find the nearest parent directory that is a registered workspace and anchor to it."
  (interactive)
  (let* ((start-dir (if buffer-file-name
                        (file-name-directory (buffer-file-name))
                      default-directory))
         ;; Ensure the path has a trailing slash for consistent matching
         (current (expand-file-name (file-name-as-directory start-dir)))
         ;; Grab all unique workspaces currently in the database
         (known-workspaces (mapcar (lambda (row) 
                                     (expand-file-name (file-name-as-directory (car row))))
                                   (sqlite-select my/sd-db "SELECT DISTINCT workspace FROM speed_dial")))
         (found nil))
    
    ;; Walk up the directory tree
    (while (and current (not found))
      (if (member current known-workspaces)
          (setq found current)
        ;; Move up one directory level
        (let ((parent (file-name-directory (directory-file-name current))))
          (if (string= current parent)
              (setq current nil) ;; Stop if we hit the file system root ("/")
            (setq current parent)))))
            
    (if found
        (progn
          (my/lock-workspace-to-dir found)
          (message "Anchored to or nearest parent workspace: %s" found))
      (message "No known workspace found in the parent directories!"))))

;; --- THE CORFU / CAPF SORTING SHIELD ---
(defun my/sd-pcomplete-sort-override (orig-fn &rest args)
  "Force Corfu/Capf to respect proximity sorting for the `anchor` Eshell command."
  (let ((res (apply orig-fn args)))
    (when (and res (listp res))
      (let* ((start (nth 0 res))
             ;; Get the text just before the completion started
             (line-prefix (buffer-substring-no-properties (line-beginning-position) start)))
        ;; If the command being completed is 'anchor'
        (when (string-match-p "\\banchor\\s-+$" line-prefix)
          (let ((table (nth 2 res)))
            ;; Wrap the completion table to inject metadata that stops Corfu from sorting
            (setcar (nthcdr 2 res)
                    (lambda (string pred action)
                      (if (eq action 'metadata)
                          '(metadata (display-sort-function . identity)
                                     (cycle-sort-function . identity))
                        (complete-with-action action table string pred))))))))
    res))

(with-eval-after-load 'pcomplete
  (advice-add 'pcomplete-completions-at-point :around #'my/sd-pcomplete-sort-override))

(defun my/set-speed-dial-tag ()
  (interactive)
  (let* ((root (my/get-workspace))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT tag FROM speed_dial WHERE workspace=? AND tag != 'global'" (list root)))
         (all-tags (mapcar #'car rows))
         (other-tags (remove my/current-speed-dial-tag all-tags)))
    (if (not other-tags)
        (if all-tags
            (message "You are already on the only tag [%s]! Press 'C' to create a new one." my/current-speed-dial-tag)
          (message "No custom tags found! Press 'C' to create one."))
      (setq my/current-speed-dial-tag (completing-read "Select tag for RIGHT hand: " other-tags))
      (my/save-workspace-tag root my/current-speed-dial-tag)
      (message "Locked right hand to tag:[%s]" my/current-speed-dial-tag)
      (my/refresh-speed-dial-hud))))

(defun my/project-bookmark-jump ()
  "Jump to any bookmark inside your manually locked workspace."
  (interactive)
  (if-let ((root my/current-workspace-root))
      (let* ((all-rows (sqlite-select my/sd-db "SELECT record FROM speed_dial WHERE workspace=?" (list root)))
             (all-paths (delq nil (mapcar (lambda (r) (my/sd-get-absolute-path (car r))) all-rows)))
             (rows (sqlite-select my/sd-db "SELECT name, tag, slot, record FROM speed_dial WHERE workspace=?" (list root)))
             (choices (mapcar (lambda (row)
                                (let* ((name (nth 0 row))
                                       (tag (nth 1 row)) 
                                       (slot (nth 2 row))
                                       (record-str (nth 3 row))
                                       (target-path (my/sd-get-absolute-path record-str))
                                       (display-name (if target-path 
                                                         (my/shortest-unique-path target-path all-paths) 
                                                       name)))
                                  (cons (format "[%s-%d] %s" tag slot display-name) row)))
                              rows)))
        (if choices
            (let* ((choice (completing-read "Workspace Bookmarks: " choices))
                   (row-data (cdr (assoc choice choices)))
                   (bm-name (nth 0 row-data))
                   (raw-data (read (nth 3 row-data))))
              (bookmark-jump (cons bm-name raw-data)))
          (message "No bookmarks found in locked workspace: %s" root)))
    (message "No workspace locked! Press '<leader> a p' to select one first.")))

(defun my/bookmark-set-absolute ()
  (interactive)
  (call-interactively 'bookmark-set))

(defun my/bookmark-tag-current-file ()
  (interactive)
  (let* ((root (my/get-workspace))
         (tag (read-string (format "Assign to tag (default %s): " (or my/current-speed-dial-tag "main")) 
                           nil nil (or my/current-speed-dial-tag "main")))
         (record (bookmark-make-record))
         (name (if buffer-file-name (file-name-nondirectory buffer-file-name) (car record)))
         (data-str (prin1-to-string (cdr record)))
         (target-path (if buffer-file-name (expand-file-name buffer-file-name) nil)))
    
    (let ((existing-slots (sqlite-select my/sd-db "SELECT slot, record FROM speed_dial WHERE workspace=? AND tag=?" (list root tag))))
      (dolist (es existing-slots)
        (let* ((s (nth 0 es))
               (p (my/sd-get-absolute-path (nth 1 es))))
          (when (and target-path p (string= target-path p))
            (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" (list root tag s))))))
    
    (let* ((used-slots (mapcar #'car (sqlite-select my/sd-db "SELECT slot FROM speed_dial WHERE workspace=? AND tag=?" (list root tag))))
           (free-slot (cl-find-if-not (lambda (s) (member s used-slots)) '(1 2 3 4 5 6 7 8))))
      (if (not free-slot)
          (message "Tag[%s] is full! All 8 slots are used." tag)
        (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                        (list root tag free-slot name data-str))
        (message "Pinned to Slot %d on[%s]" free-slot tag)
        (my/refresh-speed-dial-hud)))))

;; ==========================================
;; 5. CORE SPEED DIAL LOGIC
;; ==========================================

(defun my/sd-generate-record-for (target)
  (if target
      (with-current-buffer (find-file-noselect target)
        (bookmark-make-record))
    (bookmark-make-record)))

(defun my/speed-dial-jump (tag num)
  (when (and (not tag) (or (eq my/speed-dial-mode 'tag) (eq my/speed-dial-mode 'drop)))
    (let ((root (my/get-workspace)))
      (setq tag "main")
      (setq my/current-speed-dial-tag "main")
      (my/save-workspace-tag root "main")
      (my/refresh-speed-dial-hud)
      (message "Auto-created default dynamic tag:[main]")))

  (if (not tag)
      (progn
        (message "No dynamic tag set for the right hand! Press 't' to lock one.")
        (when (not (eq my/speed-dial-mode 'normal))
          (hydra-speed-dial/body)))

    (let* ((root (my/get-workspace))
           (row (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                               (list root tag num))))

      (cond
       ;; --- NORMAL MODE ---
       ((eq my/speed-dial-mode 'normal)
        (if row
            (let* ((name (nth 0 (car row)))
                   (data (read (nth 1 (car row))))
                   (file-path (alist-get 'filename data))
                   (exp-path (when file-path (expand-file-name file-path))))
              (cond
               ((and exp-path (not (file-exists-p exp-path)))
                (message "Path '%s' no longer exists! Auto-cleaning slot..." exp-path)
                (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" (list root tag num))
                (my/refresh-speed-dial-hud)
                (hydra-speed-dial/body))
               ((and exp-path (not (file-directory-p exp-path)))
                (let ((buf (find-buffer-visiting exp-path)))
                  (if buf (switch-to-buffer buf) (find-file exp-path)))
                (my/refresh-speed-dial-hud)) 
               (t 
                (bookmark-jump (cons name data))
                (my/refresh-speed-dial-hud))))
          (message "Empty slot")))

       ;; --- TAG MODE ---
       ((eq my/speed-dial-mode 'tag)
        (let* ((record (my/sd-generate-record-for my/pending-tag-target))
               (moving-name (if my/pending-tag-target (file-name-nondirectory my/pending-tag-target) (car record)))
               (moving-data (prin1-to-string (cdr record)))
               (target-path (if my/pending-tag-target (expand-file-name my/pending-tag-target) nil)))
          
          (let ((existing-slots (sqlite-select my/sd-db "SELECT slot, record FROM speed_dial WHERE workspace=? AND tag=?" (list root tag))))
            (dolist (es existing-slots)
              (let* ((s (nth 0 es))
                     (p (my/sd-get-absolute-path (nth 1 es))))
                (when (and target-path p (string= target-path p))
                  (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" (list root tag s))))))
          
          (let ((current-name moving-name)
                (current-data moving-data))
            (cl-loop for s from num to 8 do
                     (let ((occupant (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                                    (list root tag s))))
                       (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                       (list root tag s current-name current-data))
                       (if occupant
                           (setq current-name (nth 0 (car occupant))
                                 current-data (nth 1 (car occupant)))
                         (cl-return)))))

          (setq my/speed-dial-mode 'normal
                my/pending-tag-target nil)
          (my/refresh-speed-dial-hud)
          (message "Tagged to slot %d on [%s]!" num tag)
          (hydra-speed-dial/body)))

       ;; --- PICK MODE ---
       ((eq my/speed-dial-mode 'pick)
        (if (not row)
            (message "That slot is empty! Press a key with an active bookmark.")
          (setq my/pending-move-src (cons tag num))
          (setq my/speed-dial-mode 'drop))
        (hydra-speed-dial/body))

       ;; --- DROP MODE ---
       ((eq my/speed-dial-mode 'drop)
        (let* ((old-tag (car my/pending-move-src))
               (old-slot (cdr my/pending-move-src))
               (old-row (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                       (list root old-tag old-slot))))
          (when old-row
            (let ((moving-name (nth 0 (car old-row)))
                  (moving-data (nth 1 (car old-row))))
              
              (if (string= old-tag tag)
                  (unless (= old-slot num)
                    (let ((target-occupant (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                                          (list root tag num))))
                      (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                      (list root tag num moving-name moving-data))
                      (if target-occupant
                          (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                          (list root old-tag old-slot (nth 0 (car target-occupant)) (nth 1 (car target-occupant))))
                        (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                        (list root old-tag old-slot)))
                      (message "Swapped slot %d!" num)))

                (progn
                  (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                  (list root old-tag old-slot))
                  
                  (let ((target-path (my/sd-get-absolute-path moving-data))
                        (existing-slots (sqlite-select my/sd-db "SELECT slot, record FROM speed_dial WHERE workspace=? AND tag=?" (list root tag))))
                    (dolist (es existing-slots)
                      (let* ((s (nth 0 es))
                             (p (my/sd-get-absolute-path (nth 1 es))))
                        (when (and target-path p (string= target-path p))
                          (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" (list root tag s))))))
                  
                  (let ((current-name moving-name)
                        (current-data moving-data))
                    (cl-loop for s from num to 8 do
                             (let ((occupant (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                                            (list root tag s))))
                               (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                               (list root tag s current-name current-data))
                               (if occupant
                                   (setq current-name (nth 0 (car occupant))
                                         current-data (nth 1 (car occupant)))
                                 (cl-return)))))
                  (message "Moved across sides to slot %d (shifted others down)!" num)))))
          
          (setq my/speed-dial-mode 'normal
                my/pending-move-src nil)
          (my/refresh-speed-dial-hud)
          (hydra-speed-dial/body)))

       ;; --- UNTAG MODE ---
       ((eq my/speed-dial-mode 'untag)
        (if (not row)
            (message "That slot is already empty!")
          (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" (list root tag num))
          (message "Untagged slot %d from [%s]" num tag))
        (setq my/speed-dial-mode 'normal)
        (my/refresh-speed-dial-hud)
        (hydra-speed-dial/body))))))

;; ==========================================
;; 6. HYDRA HELPER FUNCTIONS
;; ==========================================

(defun my/hydra-consolidate-slots ()
  (interactive)
  (let* ((root (my/get-workspace))
         (tags (list "global" my/current-speed-dial-tag))
         (total-moved 0))
    
    (dolist (tag tags)
      (when tag
        (let ((rows (sqlite-select my/sd-db "SELECT slot, name, record FROM speed_dial WHERE workspace=? AND tag=? ORDER BY slot ASC" (list root tag))))
          (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=?" (list root tag))
          (let ((new-slot 1))
            (dolist (row rows)
              (let ((name (nth 1 row))
                    (record (nth 2 row)))
                (sqlite-execute my/sd-db "INSERT INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                (list root tag new-slot name record))
                (cl-incf new-slot)
                (cl-incf total-moved)))))))
    
    (my/refresh-speed-dial-hud)
    (message "Workspace organized! Shifted %d bookmarks to close all gaps." total-moved))
  (hydra-speed-dial/body))

(defun my/hydra-find-and-tag ()
  (interactive)
  (setq my/speed-dial-mode 'tag)
  (setq my/pending-tag-target nil)
  (let* ((original-dir default-directory)
         (show-hud (eq my/speed-dial-display-mode 'menu))
         (buf (when show-hud (get-buffer-create " *Speed-Dial HUD*")))
         (win nil)
         (selected-file nil)
         (hud-text (when show-hud
                     (format "
  WORKSPACE: %s
  TAG (R)  : %s

  >>>[TAG MODE] SEARCHING FOR FILE... PRESS A SLOT KEY AFTERWARDS <<<

  GLOBAL (Left Hand)                        DYNAMIC (Right Hand)
  [a]: %-22s  [j]: %-22s
  [s]: %-22s  [k]: %-22s
  [d]: %-22s  [l]: %-22s
  [f]: %-22s  [;]: %-22s
  [z]: %-22s  [m]: %-22s
  [x]: %-22s  [,]: %-22s                      
  [c]: %-22s  [.]: %-22s
  [v]: %-22s  [/]: %-22s
"
                             (or my/current-workspace-root "[None Locked]")
                             (or my/current-speed-dial-tag "[No Tag Selected]")
                             (my/sd-name 'left 1) (my/sd-name 'right 1)
                             (my/sd-name 'left 2) (my/sd-name 'right 2)
                             (my/sd-name 'left 3) (my/sd-name 'right 3)
                             (my/sd-name 'left 4) (my/sd-name 'right 4)
                             (my/sd-name 'left 5) (my/sd-name 'right 5)
                             (my/sd-name 'left 6) (my/sd-name 'right 6)
                             (my/sd-name 'left 7) (my/sd-name 'right 7)
                             (my/sd-name 'left 8) (my/sd-name 'right 8)))))

    (when show-hud
      (with-current-buffer buf
        (erase-buffer) (insert (propertize hud-text 'face 'bold))
        (goto-char (point-min))
        (setq-local mode-line-format nil header-line-format nil cursor-type nil window-size-fixed t))
      (setq win (display-buffer buf '((display-buffer-in-side-window) (side . top) (window-height . fit-window-to-buffer))))
      (set-window-dedicated-p win t))
    
    (condition-case nil
        (unwind-protect
            (let ((default-directory original-dir))
              (setq selected-file (read-file-name "Select file to pin: ")))
          (when show-hud 
            (when (window-live-p win) (delete-window win))
            (kill-buffer buf)))
      (quit (setq my/speed-dial-mode 'normal) (message "Cancelled Find & Tag")))
      
    (when selected-file
      (setq my/pending-tag-target (expand-file-name selected-file)))
    (hydra-speed-dial/body)))

(defun my/hydra-start-tag ()   (interactive) (setq my/pending-tag-target nil my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'tag 'normal)) (hydra-speed-dial/body))
(defun my/hydra-start-move ()  (interactive) (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'pick 'normal)) (hydra-speed-dial/body))
(defun my/hydra-start-untag () (interactive) (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'untag 'normal)) (hydra-speed-dial/body))

(defun my/hydra-quit () 
  (interactive) 
  (setq my/speed-dial-mode 'normal 
        my/pending-move-src nil 
        my/pending-tag-target nil))

(defun my/hydra-create-tag ()
  (interactive)
  (let ((new-tag (read-string "Create new tag: ")))
    (if (string= "" new-tag)
        (message "Cancelled: Tag name cannot be empty.")
      (setq my/current-speed-dial-tag new-tag)
      (my/save-workspace-tag (my/get-workspace) new-tag)
      (my/refresh-speed-dial-hud)
      (message "Created and locked new tag: [%s]" new-tag)))
  (hydra-speed-dial/body))

(defun my/hydra-wipe-tag ()
  (interactive)
  (let* ((root (my/get-workspace))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT tag FROM speed_dial WHERE workspace=? AND tag != 'global'" (list root)))
         (clean-tags (mapcar #'car rows)))
    (if (not clean-tags)
        (message "No custom tags exist in this workspace!")
      (let ((tag-to-nuke (completing-read "Wipe tag completely: " clean-tags nil t)))
        (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=?" (list root tag-to-nuke))
        (when (string= my/current-speed-dial-tag tag-to-nuke) 
          (setq my/current-speed-dial-tag nil)
          (my/save-workspace-tag root nil))
        (my/refresh-speed-dial-hud)
        (message "Wiped tag '%s'." tag-to-nuke))))
  (hydra-speed-dial/body))

(defun my/hydra-wipe-workspace ()
  (interactive)
  (let* ((root (my/get-workspace))
         (count (caar (sqlite-select my/sd-db "SELECT COUNT(*) FROM speed_dial WHERE workspace=?" (list root)))))
    (if (= count 0)
        (message "Workspace is already empty! No bookmarks to remove.")
      (when (y-or-n-p (format "DANGER: Wipe all contents of workspace '%s' (%d slots)? " 
                              (file-name-nondirectory (directory-file-name root)) count))
        (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=?" (list root))
        (my/save-workspace-tag root nil)
        (setq my/current-speed-dial-tag nil)
        (my/refresh-speed-dial-hud)
        (message "Workspace contents wiped successfully!"))))
  (hydra-speed-dial/body))

(defun my/set-workspace-and-resume () (interactive) (call-interactively 'my/set-workspace) (hydra-speed-dial/body))
(defun my/set-tag-and-resume ()       (interactive) (call-interactively 'my/set-speed-dial-tag) (hydra-speed-dial/body))

(defun my/hydra-anchor-workspace ()
  "Quickly switch to a previously used workspace stored in the database.
UI Completion is sorted by closest proximity to your current location."
  (interactive)
  (let* ((rows (sqlite-select my/sd-db "SELECT DISTINCT workspace FROM speed_dial"))
         (workspaces (mapcar #'car rows)))
    (if (not workspaces)
        (message "No saved workspaces found in the database! Use 'p' to lock a new one.")
      (let* ((curr (or my/current-workspace-root default-directory))
             (sorted-workspaces (sort workspaces
                                      (lambda (a b)
                                        (let ((len-a (my/shared-prefix-len curr a))
                                              (len-b (my/shared-prefix-len curr b)))
                                          (if (= len-a len-b)
                                              (string< a b)
                                            (> len-a len-b))))))
             
             ;; OVERRIDE EMACS COMPLETION SORTING: Wrap in metadata to block Vertico/Ivy/Helm
             (completion-table (lambda (string pred action)
                                 (if (eq action 'metadata)
                                     '(metadata (display-sort-function . identity)
                                                (cycle-sort-function . identity))
                                   (complete-with-action action sorted-workspaces string pred))))
             
             (choice (completing-read "Anchor to known workspace: " completion-table nil t))
             (root (expand-file-name choice)))
        (my/lock-workspace-to-dir root))))
  (hydra-speed-dial/body))

(defun my/sd-find-ancestor-with-globals (root)
  "Walk up the directory tree from ROOT to find an ancestor with 'global' slots."
  (let* ((current (directory-file-name (expand-file-name root)))
         (parent (file-name-directory current))
         (found nil))
    (while (and parent
                (not (string= parent current))
                (not found))
      (let* ((parent-dir (expand-file-name (file-name-as-directory parent)))
             (count (caar (sqlite-select my/sd-db "SELECT count(*) FROM speed_dial WHERE workspace=? AND tag='global'" (list parent-dir)))))
        (if (> count 0)
            (setq found parent-dir)
          (setq current (directory-file-name parent)
                parent (file-name-directory current)))))
    found))

(defun my/hydra-inherit-global ()
  "Inherit 'global' slots from the nearest ancestor workspace.
Cascades dynamically if the current workspace already has items in those slots."
  (interactive)
  (unless my/current-workspace-root
    (error "No workspace locked! Press 'p' to lock one first."))
  
  (let* ((target-root (expand-file-name (file-name-as-directory my/current-workspace-root)))
         (global-count (caar (sqlite-select my/sd-db "SELECT COUNT(*) FROM speed_dial WHERE workspace=? AND tag='global'" (list target-root))))
         (ancestor (my/sd-find-ancestor-with-globals target-root)))
    
    (if (not ancestor)
        (message "No ancestor workspace with global slots found in the database!")
      
      (when (or (= global-count 0)
                (y-or-n-p (format "Workspace already has %d global slots. Merge and cascade inherited slots? " global-count)))
        
        (let ((rows (sqlite-select my/sd-db "SELECT slot, name, record FROM speed_dial WHERE workspace=? AND tag='global'" (list ancestor))))
          (dolist (row rows)
            (let* ((target-slot (nth 0 row))
                   (moving-name (nth 1 row))
                   (moving-data (nth 2 row))
                   (target-path (my/sd-get-absolute-path moving-data)))
              
              (let ((existing-slots (sqlite-select my/sd-db "SELECT slot, record FROM speed_dial WHERE workspace=? AND tag='global'" (list target-root))))
                (dolist (es existing-slots)
                  (let* ((s (nth 0 es))
                         (p (my/sd-get-absolute-path (nth 1 es))))
                    (when (and target-path p (string= target-path p))
                      (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag='global' AND slot=?" (list target-root s))))))
              
              (let ((current-name moving-name)
                    (current-data moving-data))
                (cl-loop for s from target-slot to 8 do
                         (let ((occupant (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag='global' AND slot=?" 
                                                        (list target-root s))))
                           (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, 'global', ?, ?, ?)"
                                           (list target-root s current-name current-data))
                           (if occupant
                               (setq current-name (nth 0 (car occupant))
                                     current-data (nth 1 (car occupant)))
                             (cl-return)))))))
          
          (my/refresh-speed-dial-hud)
          (message "Inherited %d global slots from '%s'!" (length rows) (file-name-nondirectory (directory-file-name ancestor)))))))
  (hydra-speed-dial/body))

(defun my/hydra-rename-tag ()
  (interactive)
  (let* ((root (my/get-workspace))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT tag FROM speed_dial WHERE workspace=? AND tag != 'global'" (list root)))
         (clean-tags (mapcar #'car rows)))
    (if (not clean-tags)
        (message "No tags exist to rename!")
      (let* ((old-tag (completing-read "Rename tag: " clean-tags nil t))
             (new-tag (read-string (format "Rename[%s] to: " old-tag))))
        (if (or (string= "" new-tag) (member new-tag clean-tags))
            (message "Cancelled: Tag name cannot be empty or already exist.")
          (sqlite-execute my/sd-db "UPDATE OR REPLACE speed_dial SET tag=? WHERE workspace=? AND tag=?" 
                          (list new-tag root old-tag))
          (when (string= my/current-speed-dial-tag old-tag)
            (setq my/current-speed-dial-tag new-tag)
            (my/save-workspace-tag root new-tag))
          (my/refresh-speed-dial-hud)
          (message "Renamed tag [%s] to[%s]!" old-tag new-tag)))))
  (hydra-speed-dial/body))

(defun my/hydra-copy-tag ()
  (interactive)
  (let* ((root (my/get-workspace))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT tag FROM speed_dial WHERE workspace=? AND tag != 'global'" (list root)))
         (clean-tags (mapcar #'car rows)))
    (if (not clean-tags)
        (message "No tags exist to copy!")
      (let* ((old-tag (completing-read "Copy tag: " clean-tags nil t))
             (new-tag (read-string (format "Copy [%s] to new tag: " old-tag))))
        (if (or (string= "" new-tag) (member new-tag clean-tags))
            (message "Cancelled: Tag name cannot be empty or already exist.")
          (let ((slots (sqlite-select my/sd-db "SELECT slot, name, record FROM speed_dial WHERE workspace=? AND tag=?" 
                                      (list root old-tag))))
            (dolist (slot-row slots)
              (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                              (list root new-tag (nth 0 slot-row) (nth 1 slot-row) (nth 2 slot-row))))
            (my/refresh-speed-dial-hud)
            (message "Copied layout of [%s] into[%s]!" old-tag new-tag))))))
  (hydra-speed-dial/body))

(defun my/hydra-clone-workspace ()
  (interactive)
  (unless my/current-workspace-root
    (error "No workspace locked! Press 'p' to lock into your blank target workspace first."))
    
  (let* ((target-root (expand-file-name (file-name-as-directory my/current-workspace-root)))
         (all-rows (sqlite-select my/sd-db "SELECT DISTINCT workspace FROM speed_dial"))
         (all-workspaces (mapcar #'car all-rows))
         (source-workspaces (remove target-root all-workspaces)))
         
    (unless source-workspaces
      (error "No other workspaces found to clone from!"))
      
    (let* ((source-root (completing-read "Source workspace to clone from: " source-workspaces nil t))
           (source-root-exp (expand-file-name (file-name-as-directory source-root)))
           (target-count (caar (sqlite-select my/sd-db "SELECT COUNT(*) FROM speed_dial WHERE workspace=?" (list target-root)))))

      (when (> target-count 0)
        (error "Current workspace already contains bookmarks! Please nuke it first (X) before cloning."))

      (let ((rows (sqlite-select my/sd-db "SELECT tag, slot, name, record FROM speed_dial WHERE workspace=?" (list source-root-exp))))
        
        (let ((missing-files nil))
          (dolist (row rows)
            (let* ((data (read (nth 3 row)))
                   (raw-path (alist-get 'filename data))
                   (old-path (when raw-path (expand-file-name raw-path))))
              (when (and old-path (string-prefix-p source-root-exp old-path))
                (let ((new-path (concat target-root (substring old-path (length source-root-exp)))))
                  (unless (file-exists-p new-path)
                    (push new-path missing-files))))))
          (when missing-files
            (error "Abort: Target directory is missing %d required files." (length missing-files))))

        (dolist (row rows)
          (let* ((tag (nth 0 row))
                 (slot (nth 1 row))
                 (name (nth 2 row))
                 (data (read (nth 3 row)))
                 (raw-path (alist-get 'filename data))
                 (old-path (when raw-path (expand-file-name raw-path))))
            
            (when (and old-path (string-prefix-p source-root-exp old-path))
              (setf (alist-get 'filename data) 
                    (abbreviate-file-name (concat target-root (substring old-path (length source-root-exp))))))
            
            (let ((new-name name))
              (when (and name (file-name-absolute-p name))
                (let ((exp-name (expand-file-name name)))
                  (when (string-prefix-p source-root-exp exp-name)
                    (setq new-name (abbreviate-file-name (concat target-root (substring exp-name (length source-root-exp))))))))
              
              (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                              (list target-root tag slot new-name (prin1-to-string data))))))
        
        (let ((source-tag (my/get-saved-workspace-tag source-root-exp)))
          (when source-tag
            (my/save-workspace-tag target-root source-tag)
            (setq my/current-speed-dial-tag source-tag)))

        (my/refresh-speed-dial-hud)
        (message "Successfully pulled %d slots from '%s' into current workspace!" 
                 (length rows) (file-name-nondirectory (directory-file-name source-root-exp))))))
  (hydra-speed-dial/body))

;; ==========================================
;; 7. HYDRA HUD MANAGER
;; ==========================================

(defhydra hydra-speed-dial (:color blue :hint nil)
  "
^WORKSPACE^: %s(or my/current-workspace-root \"[None Locked - Press 'p']\")
^TAG    ^  : %s(or my/current-speed-dial-tag \"[No Tag Selected - Press 't']\")%s(cond
  ((eq my/speed-dial-mode 'pick)
   \"\n\n  >>>[MOVE MODE] PRESS BOOKMARK KEY TO PICK UP <<<\")
  ((eq my/speed-dial-mode 'drop)
   (let* ((tag (car my/pending-move-src))
          (slot (cdr my/pending-move-src))
          (row (sqlite-select my/sd-db \"SELECT name FROM speed_dial WHERE workspace=? AND tag=? AND slot=?\" (list (my/get-workspace) tag slot))))
     (format \"\n\n  >>>[MOVE MODE] CARRYING:[%s] ... PRESS TARGET KEY TO DROP! <<<\"
             (if row (file-name-nondirectory (caar row)) \"Unknown\"))))
  ((eq my/speed-dial-mode 'untag)
   \"\n\n  >>>[UNTAG MODE] PRESS SLOT KEY TO UNTAG <<<\")
  ((eq my/speed-dial-mode 'tag)
   (if my/pending-tag-target
       (format \"\n\n  >>>[TAG MODE] READY TO PIN: [%s] ... PRESS A SLOT KEY <<<\"
               (file-name-nondirectory my/pending-tag-target))
     \"\n\n  >>>[TAG MODE] PRESS SLOT KEY TO TAG CURRENT FILE <<<\"))
  (t \"\"))
-----------------------------------------------------------------------------------------------------
_a_: %s(my/sd-name 'left 1)  _j_: %s(my/sd-name 'right 1)  _T_: Tag File     _C_: Create Tag
_s_: %s(my/sd-name 'left 2)  _k_: %s(my/sd-name 'right 2)  _F_: Find & Tag   _R_: Rename Tag
_d_: %s(my/sd-name 'left 3)  _l_: %s(my/sd-name 'right 3)  _U_: Untag Slot   _Y_: Copy Tag
_f_: %s(my/sd-name 'left 4)  _;_: %s(my/sd-name 'right 4)  _M_: Toggle Move  _W_: Wipe Tag
_z_: %s(my/sd-name 'left 5)  _m_: %s(my/sd-name 'right 5)  _O_: Organize HUD _X_: Nuke Workspace
_x_: %s(my/sd-name 'left 6)  _,_: %s(my/sd-name 'right 6)  _A_: Anchor Known _P_: Clone Workspc
_c_: %s(my/sd-name 'left 7)  _._: %s(my/sd-name 'right 7)  _p_: Lock New Dir _t_: Lock Tag
_v_: %s(my/sd-name 'left 8)  _/_: %s(my/sd-name 'right 8)  _q_: Quit HUD     _I_: Inherit Global
  "
  ("a" (my/speed-dial-jump "global" 1)) ("s" (my/speed-dial-jump "global" 2))
  ("d" (my/speed-dial-jump "global" 3)) ("f" (my/speed-dial-jump "global" 4))
  ("z" (my/speed-dial-jump "global" 5)) ("x" (my/speed-dial-jump "global" 6))
  ("c" (my/speed-dial-jump "global" 7)) ("v" (my/speed-dial-jump "global" 8))

  ("j" (my/speed-dial-jump my/current-speed-dial-tag 1))
  ("k" (my/speed-dial-jump my/current-speed-dial-tag 2))
  ("l" (my/speed-dial-jump my/current-speed-dial-tag 3))
  (";" (my/speed-dial-jump my/current-speed-dial-tag 4))
  ("m" (my/speed-dial-jump my/current-speed-dial-tag 5))
  ("," (my/speed-dial-jump my/current-speed-dial-tag 6))
  ("." (my/speed-dial-jump my/current-speed-dial-tag 7))
  ("/" (my/speed-dial-jump my/current-speed-dial-tag 8))

  ("T" my/hydra-start-tag) ("F" my/hydra-find-and-tag) ("U" my/hydra-start-untag)
  ("M" my/hydra-start-move) ("O" my/hydra-consolidate-slots) 
  ("C" my/hydra-create-tag) ("W" my/hydra-wipe-tag) ("R" my/hydra-rename-tag) 
  ("Y" my/hydra-copy-tag) ("X" my/hydra-wipe-workspace) 
  ("p" my/set-workspace-and-resume) ("P" my/hydra-clone-workspace) 
  ("A" my/hydra-anchor-workspace) ("t" my/set-tag-and-resume) 
  ("I" my/hydra-inherit-global)
  ("q" my/hydra-quit) ("<escape>" my/hydra-quit) ("C-g" my/hydra-quit))

;; ==========================================
;; 8. Auto-load Last Workspace
;; ==========================================
(my/load-global-workspace-state)

;; Ensure subr-x is loaded for string trimming
(require 'subr-x)

;; ==========================================
;; 8.5 PERSISTENT TMUX-STYLE HUD (TOP & BOTTOM)
;; ==========================================

(defvar my/speed-dial-hud-buffer-name " *Speed-Dial-HUD*")
(defvar my/speed-dial-global-hud-buffer-name " *Speed-Dial-Global-HUD*")

;; ==========================================
;; NEW ADDITION: Safe Mouse Click Handler
;; ==========================================
(defun my/sd-hud-handle-click (event)
  "Handle mouse clicks on the speed dial HUD safely.
Swallows double/triple clicks to prevent Emacs native crashes."
  (interactive "e")
  (ignore-errors
    ;; Only trigger the jump on a standard single-click release ('mouse-1).
    ;; All other rapid/double/drag clicks are safely swallowed and do nothing.
    (when (eq (car-safe event) 'mouse-1)
      (let* ((start (event-start event))
             (pos (posn-point start)))
        (when (number-or-marker-p pos)
          (let* ((window (posn-window start))
                 (buffer (window-buffer window))
                 (tag (with-current-buffer buffer (get-text-property pos 'sd-tag)))
                 (slot (with-current-buffer buffer (get-text-property pos 'sd-slot))))
            (when (and tag slot)
              (let ((target-win (get-mru-window nil nil 'nomini)))
                (when target-win
                  (select-window target-win)
                  (my/speed-dial-jump tag slot))))))))))

;; ==========================================
;; REPLACEMENT 1: Text Generator (PERFECT KEYBOARD REPLICA)
;; ==========================================
(defun my/sd-generate-hud-string (keys side active-buf active-file)
  (let* ((items (cl-loop for i from 1 to 8
                         for k in keys
                         for row = (sqlite-select my/sd-db "SELECT record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?"
                                                  (list my/current-workspace-root (if (eq side 'left) "global" my/current-speed-dial-tag) i))
                         for record-str = (if row (caar row) nil)
                         for target-path = (if record-str (my/sd-get-absolute-path record-str) nil)
                         for ui-name = (my/sd-name side i)
                         for clean-name = (string-trim (substring-no-properties ui-name))
                         unless (string= clean-name "-")
                         collect 
                         (let* ((a-path (and active-file (expand-file-name (substring-no-properties active-file))))
                                (is-active (if (and target-path a-path)
                                               (string= target-path a-path)
                                             (let ((b-name (and active-buf (substring-no-properties active-buf))))
                                               (and b-name (string= clean-name b-name)))))
                                (sep (if is-active "→" ")"))
                                (key-face '(:weight bold :underline (:style wave)))
                                (text-face (if is-active '(:weight bold :inverse-video t) nil))
                                (formatted-text (format "%s%s %s"
                                                        (propertize k 'face key-face)
                                                        (propertize sep 'face key-face)
                                                        (if text-face (propertize clean-name 'face text-face) clean-name)))
                                (tag (if (eq side 'left) "global" my/current-speed-dial-tag))
                                (slot i)
                                (click-map (make-sparse-keymap)))
                           
                           ;; 1. Absorb the press down
                           (define-key click-map [down-mouse-1] #'ignore)
                           
                           ;; 2. On Release: Shift to main window, then execute the jump
                           (define-key click-map [mouse-1]
                             `(lambda (event)
                                (interactive "e")
                                
                                ;; A: Steal focus back to the main editing window using YOUR exact logic
                                (let ((best-win nil)
                                      (best-time -1))
                                  (walk-windows (lambda (w)
                                                  (unless (member (buffer-name (window-buffer w))
                                                                  (list my/speed-dial-hud-buffer-name
                                                                        my/speed-dial-global-hud-buffer-name))
                                                    (let ((time (window-use-time w)))
                                                      (when (> time best-time)
                                                        (setq best-time time
                                                              best-win w)))))
                                                'nomini)
                                  (if best-win
                                      (select-window best-win)
                                    (other-window 1)))

                                ;; B: Now that we are safely in the main window, execute the EXACT 
                                ;; logic that pressing the j/k/l keys triggers!
                                (my/speed-dial-jump ,tag ,slot)))
                           
                           (propertize formatted-text
                                       'mouse-face 'highlight
                                       'pointer 'hand
                                       'help-echo (format "Click to jump to %s" clean-name)
                                       'keymap click-map))))
         (max-width (- (frame-width) 0))
         (current-len 0)
         (body ""))

    (unless items
      (setq items (list (propertize "[No files tagged]" 'face 'shadow))))

    (dolist (item items)
      (let ((padded-item (concat item " ")))
        (if (> (+ current-len (length padded-item)) max-width)
            (setq body (concat body "\n" padded-item)
                  current-len (length padded-item))
          (setq body (concat body padded-item)
                current-len (+ current-len (length padded-item))))))

    (string-trim-right body)))

(defun my/speed-dial-hud-content (&optional active-buf active-file)
  (my/sd-generate-hud-string '("j" "k" "l" ";" "m" "," "." "/") 'right active-buf active-file))

(defun my/speed-dial-global-hud-content (&optional active-buf active-file)
  (my/sd-generate-hud-string '("a" "s" "d" "f" "z" "x" "c" "v") 'left active-buf active-file))

;; ==========================================
;; REPLACEMENT 2: Window Setup (Clean Background)
;; ==========================================
(defun my/setup-hud-window (buf-name content-string window-side)
  (with-current-buffer (get-buffer-create buf-name)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert content-string)
      (goto-char (point-min)))

    (read-only-mode 1)
    (setq cursor-type nil mode-line-format nil header-line-format nil)
    (setq-local truncate-lines t word-wrap nil mode-require-final-newline nil require-final-newline nil)
    
    (setq left-fringe-width 0 right-fringe-width 0
          left-margin-width 0 right-margin-width 0
          indicate-empty-lines nil indicate-buffer-boundaries nil)
    
    (when (bound-and-true-p display-line-numbers-mode)
      (display-line-numbers-mode -1))
    (setq display-line-numbers nil)

    ;; Only background/empty-space clicks hit this map.
    ;; Text clicks will be intercepted by the text properties above!
    (let ((map (make-sparse-keymap)))
      (define-key map [mouse-1] #'ignore)
      (define-key map [down-mouse-1] #'ignore)
      (define-key map [drag-mouse-1] #'ignore)
      (use-local-map map)))
    
  (let ((window-resize-pixelwise t) 
        (window-size-fixed nil))
    (let ((win (display-buffer buf-name
                               `((display-buffer-in-side-window)
                                 (side . ,window-side)
                                 (window-height . fit-window-to-buffer) 
                                 (window-parameters . ((no-other-window . t)
                                                       (no-delete-other-windows . t)
                                                       (mode-line-format . none)
                                                       (header-line-format . none)))))))
      (when win
        (set-window-dedicated-p win t)
        (let ((window-min-height 1))
          (fit-window-to-buffer win nil 1))))))

(defun my/hide-speed-dial-huds ()
  (let ((win-top (get-buffer-window my/speed-dial-hud-buffer-name))
        (win-bot (get-buffer-window my/speed-dial-global-hud-buffer-name)))
    (when win-top (delete-window win-top))
    (when win-bot (delete-window win-bot))))

(defun my/show-speed-dial-huds ()
  (my/hide-speed-dial-huds)
  (let ((active-buf (buffer-name))
        (active-file (buffer-file-name)))
    (my/setup-hud-window my/speed-dial-hud-buffer-name 
                         (my/speed-dial-hud-content active-buf active-file) 
                         'top)
    (my/setup-hud-window my/speed-dial-global-hud-buffer-name 
                         (my/speed-dial-global-hud-content active-buf active-file) 
                         'bottom)))

(defun my/refresh-speed-dial-hud ()
  (let ((win-top (get-buffer-window my/speed-dial-hud-buffer-name))
        (win-bot (get-buffer-window my/speed-dial-global-hud-buffer-name))
        (active-buf (buffer-name))
        (active-file (buffer-file-name)))
    
    (when win-top
      (with-current-buffer my/speed-dial-hud-buffer-name
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (my/speed-dial-hud-content active-buf active-file))
          (goto-char (point-min))))
      (let ((window-resize-pixelwise t) (window-size-fixed nil) (window-min-height 1))
        (fit-window-to-buffer win-top nil 1)))
        
    (when win-bot
      (with-current-buffer my/speed-dial-global-hud-buffer-name
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (my/speed-dial-global-hud-content active-buf active-file))
          (goto-char (point-min))))
      (let ((window-resize-pixelwise t) (window-size-fixed nil) (window-min-height 1))
        (fit-window-to-buffer win-bot nil 1)))))

;; ==========================================
;; 8.6 HUD AUTO-UPDATE HOOKS & PROTECTIONS
;; ==========================================

(defun my/speed-dial-auto-refresh (&rest _)
  (let ((bname (buffer-name)))
    (when (and (or (get-buffer-window my/speed-dial-hud-buffer-name)
                   (get-buffer-window my/speed-dial-global-hud-buffer-name))
               (not (string= bname my/speed-dial-hud-buffer-name))
               (not (string= bname my/speed-dial-global-hud-buffer-name)))
      (my/refresh-speed-dial-hud))))

(defun my/speed-dial-prevent-focus (&rest _)
  (let ((win (selected-window)))
    (when (and (window-live-p win)
               (member (buffer-name (window-buffer win))
                       (list my/speed-dial-hud-buffer-name
                             my/speed-dial-global-hud-buffer-name)))
      (let ((best-win nil)
            (best-time -1))
        (walk-windows (lambda (w)
                        (unless (member (buffer-name (window-buffer w))
                                        (list my/speed-dial-hud-buffer-name
                                              my/speed-dial-global-hud-buffer-name))
                          (let ((time (window-use-time w)))
                            (when (> time best-time)
                              (setq best-time time
                                    best-win w)))))
                      'nomini)
        (if best-win
            (select-window best-win)
          (other-window 1))))))

(add-hook 'window-selection-change-functions #'my/speed-dial-auto-refresh)
(add-hook 'window-buffer-change-functions #'my/speed-dial-auto-refresh)
(add-hook 'window-selection-change-functions #'my/speed-dial-prevent-focus)

;; ==========================================
;; 8.7 MODE TOGGLES & HYDRA OVERRIDES
;; ==========================================

(defvar my/speed-dial-display-mode 'menu)

(defun my/speed-dial-command-mode ()
  (interactive)
  (setq my/speed-dial-display-mode 'command)
  (my/show-speed-dial-huds)
  (message "Speed Dial: COMMAND mode active."))

(defun my/speed-dial-menu-mode ()
  (interactive)
  (setq my/speed-dial-display-mode 'menu)
  (my/hide-speed-dial-huds)
  (message "Speed Dial: MENU mode active."))

(defun my/toggle-speed-dial-hud ()
  (interactive)
  (if (eq my/speed-dial-display-mode 'menu)
      (my/speed-dial-command-mode)
    (my/speed-dial-menu-mode)))

(defun my/speed-dial-hydra-display-override (orig-fun &rest args)
  (let ((hydra-is-helpful (eq my/speed-dial-display-mode 'menu)))
    (apply orig-fun args)))

(advice-add 'hydra-speed-dial/body :around #'my/speed-dial-hydra-display-override)

;; ==========================================
;; 9. KEYBINDINGS
;; ==========================================

;(evil-define-key 'normal 'global (kbd "<leader> a") 'hydra-speed-dial/body)
(with-eval-after-load 'evil
  (evil-global-set-key 'normal (kbd "SPC a") 'hydra-speed-dial/body))
(evil-define-key 'normal 'global (kbd "<leader> b p") 'my/project-bookmark-jump)
(evil-define-key 'normal 'global (kbd "<leader> b m") 'my/bookmark-set-absolute)
(evil-define-key 'normal 'global (kbd "<leader> b t") 'my/bookmark-tag-current-file)

(evil-ex-define-cmd "command" 'my/speed-dial-command-mode)
(evil-ex-define-cmd "menu" 'my/speed-dial-menu-mode)
(evil-ex-define-cmd "find-anchor" 'my/find-anchor)

(defun my/jump-to-inline-mark (char)
  (interactive "c")
  (let ((search-str (format "mark:%c" char))
        (orig-point (point)))
    (evil-set-jump)
    (goto-char (point-min))
    (let ((case-fold-search nil))
      (if (search-forward search-str nil t)
          (progn
            (goto-char (match-beginning 0))
            (recenter)
            (message "Jumped to %s" search-str))
        (goto-char orig-point)
        (message "Marker '%s' not found in this file" search-str)))))

(evil-define-key 'normal 'global (kbd "<leader> s") 'my/jump-to-inline-mark)

(provide 'my-speed-dial)
