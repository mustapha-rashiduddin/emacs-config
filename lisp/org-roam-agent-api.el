;;; org-roam-agent-api.el --- REST API bridge for autonomous AI agents -*- lexical-binding: t -*-

(require 'json)
(require 'subr-x)
(require 'org)
(require 'org-element)
(require 'org-id)
(require 'org-capture)
(require 'org-roam)
(require 'simple-httpd)

;; ==========================================
;; CONFIGURATION
;; ==========================================

(defvar my/agent-api-port 8080)
(defvar my/agent-api-token "CHANGE-ME-BEFORE-EXPOSING-THIS-ANYWHERE")
(defvar my/agent-api-anchor-id nil)
(defvar my/agent-api-backup-dir (expand-file-name "agent-backups/" user-emacs-directory))

;; ==========================================
;; PHASE 0: INFRASTRUCTURE
;; ==========================================

(defun my/agent-api--header (request name)
  (let* ((headers (if (listp request) request nil))
         (entry (assoc-string name headers t))
         (raw (cdr entry)))
    (cond
     ((null raw)    nil)
     ((stringp raw) raw)
     ((listp raw)
      (mapconcat (lambda (x)
                   (cond ((stringp x) x)
                         ((symbolp x) (symbol-name x))
                         (t (format "%s" x))))
                 raw " "))
     (t (format "%s" raw)))))

(defun my/agent-api--authorized-p (request)
  (let ((auth (my/agent-api--header request "Authorization")))
    (and (stringp auth)
         (string-equal auth (concat "Bearer " my/agent-api-token)))))

(defun my/agent-api--json (data)
  (json-encode (append '((status . "success")) data)))

(defun my/agent-api--json-error (code message)
  (json-encode `((status . "error") (code . ,code) (message . ,message))))

(defun my/agent-api--read-body (proc)
  "Read raw HTTP request body from simple-httpd PROC buffer."
  (with-current-buffer (process-buffer proc)
    (save-excursion
      (goto-char (point-min))
      (cond
       ;; CRLF header separator: Windows/HTTP style
       ((search-forward "\r\n\r\n" nil t)
        (buffer-substring-no-properties (point) (point-max)))

       ;; LF-only header separator
       ((search-forward "\n\n" nil t)
        (buffer-substring-no-properties (point) (point-max)))

       ;; Nothing found
       (t
        "")))))

(defun my/agent-api--parse-json-body (proc)
  "Parse JSON body from simple-httpd PROC buffer."
  (let ((raw (my/agent-api--read-body proc)))
    (message "AGENT API RAW BODY: %S" raw)
    (condition-case err
        (let ((json-object-type 'alist)
              (json-key-type 'symbol)
              (json-array-type 'list))
          (json-read-from-string raw))
      (error
       (message "AGENT API JSON PARSE ERROR: %S" err)
       nil))))

(defun my/agent-api--backup-file (file)
  (when (file-exists-p file)
    (unless (file-exists-p my/agent-api-backup-dir)
      (make-directory my/agent-api-backup-dir t))
    (let* ((stamp (format-time-string "%Y%m%dT%H%M%S"))
           (name (format "%s.%s.bak" (file-name-nondirectory file) stamp)))
      (copy-file file (expand-file-name name my/agent-api-backup-dir) t))))

(defun my/agent-api--query-param (query name)
  "Pull NAME from simple-httpd's QUERY alist. Coerces the result to a
string regardless of whether simple-httpd stored it as a symbol or string."
  (let* ((sname (if (symbolp name) (symbol-name name) name))
         (sym   (intern sname))
         (val   (or (cdr (assoc sym query))
                    (cdr (assoc sname query))
                    (cdr (assoc name query)))))
    (cond
     ((null val)    nil)
     ((stringp val) val)
     ((symbolp val) (symbol-name val))
     (t             (format "%s" val)))))

(defmacro my/defservlet (name mime-type args &rest body)
  (let ((fn-name (intern (format "httpd/%s" name)))
        (mime-str (if (symbolp mime-type) (symbol-name mime-type) mime-type)))
    `(defun ,fn-name (proc path query request)
       (if (not (my/agent-api--authorized-p request))
           (with-httpd-buffer proc ,mime-str
             (insert (my/agent-api--json-error
                      "UNAUTHORIZED" "Missing or invalid bearer token")))
         (let ,(mapcar (lambda (arg)
                         `(,arg (my/agent-api--query-param query ',arg)))
                       args)
           (with-httpd-buffer proc ,mime-str
             ,@body))))))

(defmacro my/defservlet-write (name &rest body)
  (let ((fn-name (intern (format "httpd/%s" name))))
    `(defun ,fn-name (proc path query request)
       (if (not (my/agent-api--authorized-p request))
           (with-httpd-buffer proc "application/json"
             (insert (my/agent-api--json-error "UNAUTHORIZED" "Missing or invalid bearer token")))
         (let ((data (my/agent-api--parse-json-body proc)))
           (with-httpd-buffer proc "application/json"
             ,@body))))))

(defservlet* api/ping application/json ()
  (insert (my/agent-api--json '((message . "Emacs daemon is alive and ready.")))))

;; ==========================================
;; PHASE 1: TIER 1 READS
;; ==========================================

(my/defservlet api/node application/json (id)
  (let ((node (and id (ignore-errors (org-roam-node-from-id id)))))
    (if (not node)
        (insert (my/agent-api--json-error "NODE_NOT_FOUND" (format "No node with id: %s" id)))
      (let* ((file (org-roam-node-file node))
             (content (with-temp-buffer
                        (insert-file-contents file)
                        (buffer-string))))
        (insert (my/agent-api--json
                 `((id . ,id)
                   (title . ,(org-roam-node-title node))
                   (file . ,file)
                   (tags . ,(vconcat (org-roam-node-tags node)))
                   (content . ,content))))))))

(my/defservlet api/backlinks application/json (id)
  (if (not id)
      (insert (my/agent-api--json-error "MISSING_PARAM" "id is required"))
    (let* ((rows (org-roam-db-query [:select [source] :from links :where (= dest $s1)] id))
           (ids (mapcar #'car rows)))
      (insert (my/agent-api--json `((target_id . ,id) (backlinks . ,(vconcat ids))))))))

(my/defservlet api/search application/json (q)
  (if (not q)
      (insert (my/agent-api--json-error "MISSING_PARAM" "q is required"))
    (let* ((pattern (concat "%" q "%"))
           (rows (org-roam-db-query
                  [:select [id title] :from nodes :where (like title $s1)]
                  pattern))
           (results (mapcar (lambda (row) `((id . ,(nth 0 row)) (title . ,(nth 1 row)))) rows)))
      (insert (my/agent-api--json `((query . ,q) (results . ,(vconcat results))))))))

;; ==========================================
;; PHASE 2: ANCHOR
;; ==========================================

(my/defservlet api/context application/json ()
  (if (not my/agent-api-anchor-id)
      (insert (my/agent-api--json-error "NO_ANCHOR_SET" "my/agent-api-anchor-id is unset."))
    (let ((node (ignore-errors (org-roam-node-from-id my/agent-api-anchor-id))))
      (if (not node)
          (insert (my/agent-api--json-error "ANCHOR_NODE_MISSING" "anchor id doesn't resolve."))
        (let* ((file (org-roam-node-file node))
               (content (with-temp-buffer
                          (insert-file-contents file)
                          (buffer-string))))
          (insert (my/agent-api--json
                   `((id . ,my/agent-api-anchor-id)
                     (title . ,(org-roam-node-title node))
                     (content . ,content)))))))))

;; ==========================================
;; PHASE 3: TIER 1 WRITES
;; ==========================================

(my/defservlet-write api/inbox
  (let ((content (cdr (assoc 'content data))))
    (if (not content)
        (insert (my/agent-api--json-error "MISSING_PARAM" "content is required"))
      (my/agent-api--backup-file org-default-notes-file)
      (with-current-buffer (find-file-noselect org-default-notes-file)
        (goto-char (point-max))
        (unless (or (bobp) (bolp)) (insert "\n"))
        (insert (format "* %s\n%s\n\n" content (format-time-string "[%Y-%m-%d %a %H:%M]")))
        (save-buffer))
      (org-roam-db-update-file org-default-notes-file)
      (insert (my/agent-api--json '((message . "Fleeting note captured.")))))))

;; simple-httpd routes by PATH ONLY, not by HTTP method — a GET handler
;; and a write handler at the same path name collide, and whichever loads
;; last silently wins. This used to be api/node, colliding with the GET
;; node-read endpoint above. Renamed to disambiguate.
(my/defservlet-write api/node/create
  (let ((title (cdr (assoc 'title data)))
        (content (cdr (assoc 'content data))))
    (if (not title)
        (insert (my/agent-api--json-error "MISSING_PARAM" "title is required"))
      (let* ((id (org-id-new))
             (slug (org-roam-node-slug (org-roam-node-create :title title)))
             (filename (format "%s-%s.org" (format-time-string "%Y%m%d%H%M%S") slug))
             (filepath (expand-file-name filename org-roam-directory)))
        (with-current-buffer (find-file-noselect filepath)
          (insert (format ":PROPERTIES:\n:ID:       %s\n:END:\n#+title: %s\n\n%s\n"
                           id title (or content "")))
          (save-buffer))
        (org-roam-db-update-file filepath)
        (insert (my/agent-api--json `((id . ,id) (file . ,filepath) (message . "Node created."))))))))

(my/defservlet-write api/link
  (let* ((source-id (cdr (assoc 'source_id data)))
         (dest-id (cdr (assoc 'dest_id data)))
         (source-node (when source-id (ignore-errors (org-roam-node-from-id source-id))))
         (dest-node (when dest-id (ignore-errors (org-roam-node-from-id dest-id)))))
    (if (or (not source-id) (not dest-id))
        (insert (my/agent-api--json-error "MISSING_PARAM" "source_id and dest_id are required"))
      (if (not source-node)
          (insert (my/agent-api--json-error "NODE_NOT_FOUND" (format "source_id not found: %s" source-id)))
        (if (not dest-node)
            (insert (my/agent-api--json-error "NODE_NOT_FOUND" (format "dest_id not found: %s" dest-id)))
          (let ((file (org-roam-node-file source-node))
                (dest-title (org-roam-node-title dest-node)))
            (my/agent-api--backup-file file)
            (with-current-buffer (find-file-noselect file)
              (goto-char (point-min))
              (if (re-search-forward "^\\* Links[ \t]*$" nil t)
                  (progn (end-of-line) (insert "\n"))
                (goto-char (point-max))
                (unless (bolp) (insert "\n"))
                (insert "\n* Links\n"))
              (insert (format "- [[id:%s][%s]]\n" dest-id dest-title))
              (save-buffer))
            (org-roam-db-update-file file)
            (insert (my/agent-api--json `((message . "Link created.")
                                           (source_id . ,source-id)
                                           (dest_id . ,dest-id))))))))))

;; ==========================================
;; SHARED: locating a "* heading" and the src-block under it
;; ==========================================

(defun my/agent-api--find-block (heading-name)
  "Search CURRENT BUFFER for the src-block under HEADING-NAME."
  (let* ((tree (org-element-parse-buffer))
         (target nil)
         (find-fn (lambda (src)
                    (let ((hl (car (org-element-lineage src '(headline)))))
                      (when (and hl
                                 (not target)
                                 (string-equal (downcase (org-element-property :raw-value hl))
                                               (downcase heading-name)))
                        (setq target (cons hl src)))))))
    (org-element-map tree 'src-block find-fn)
    (when target
      (let* ((hl (car target))
             (src (cdr target))
             (prose-beg (org-element-property :contents-begin hl))
             (prose-end (org-element-property :begin src))
             (title (org-element-property :raw-value hl))
             (id (org-element-property :ID hl))
             (lang (org-element-property :language src))
             (code-beg (org-element-property :contents-begin src))
             (code-end (org-element-property :contents-end src))
             (code (or (org-element-property :value src) ""))
             (prose (if (and prose-beg prose-end (< prose-beg prose-end))
                        (string-trim (buffer-substring-no-properties prose-beg prose-end))
                      "")))
        (list :title title
              :id id
              :language lang
              :prose prose
              :prose-beg prose-beg
              :prose-end prose-end
              :code-beg code-beg
              :code-end code-end
              :code code)))))

;; ==========================================
;; PHASE 4: TIER 2 READS
;; ==========================================

(my/defservlet api/blocks application/json (node_id)
  (let ((node (and node_id (ignore-errors (org-roam-node-from-id node_id)))))
    (if (not node)
        (insert (my/agent-api--json-error "NODE_NOT_FOUND" (format "No node with id: %s" node_id)))
      (let* ((file (org-roam-node-file node))
             (blocks (with-temp-buffer
                       (insert-file-contents file)
                       (org-mode)
                       (let ((tree (org-element-parse-buffer))
                             (res nil))
                         (org-element-map tree 'src-block
                           (lambda (src)
                             (let ((hl (car (org-element-lineage src '(headline)))))
                               (when hl
                                 (push (list (cons 'heading (org-element-property :raw-value hl))
                                             (cons 'id (or (org-element-property :ID hl) ""))
                                             (cons 'language (or (org-element-property :language src) "")))
                                       res)))))
                         (nreverse res)))))
        (insert (my/agent-api--json `((node_id . ,node_id) (blocks . ,(vconcat blocks)))))))))

(my/defservlet api/block/prose application/json (node_id name)
  (let ((node (and node_id (ignore-errors (org-roam-node-from-id node_id)))))
    (if (not node)
        (insert (my/agent-api--json-error "NODE_NOT_FOUND" (format "No node with id: %s" node_id)))
      (if (not name)
          (insert (my/agent-api--json-error "MISSING_PARAM" "name is required"))
        (let* ((file (org-roam-node-file node))
               (block (with-temp-buffer
                        (insert-file-contents file)
                        (org-mode)
                        (my/agent-api--find-block name))))
          (if (not block)
              (insert (my/agent-api--json-error "BLOCK_NOT_FOUND" (format "No block under heading: %s" name)))
            (insert (my/agent-api--json `((node_id . ,node_id)
                                          (heading . ,(plist-get block :title))
                                          (prose . ,(plist-get block :prose)))))))))))

(my/defservlet api/block/code application/json (node_id name)
  (let ((node (and node_id (ignore-errors (org-roam-node-from-id node_id)))))
    (if (not node)
        (insert (my/agent-api--json-error "NODE_NOT_FOUND" (format "No node with id: %s" node_id)))
      (if (not name)
          (insert (my/agent-api--json-error "MISSING_PARAM" "name is required"))
        (let* ((file (org-roam-node-file node))
               (block (with-temp-buffer
                        (insert-file-contents file)
                        (org-mode)
                        (my/agent-api--find-block name))))
          (if (not block)
              (insert (my/agent-api--json-error "BLOCK_NOT_FOUND" (format "No block under heading: %s" name)))
            (insert (my/agent-api--json `((node_id . ,node_id)
                                          (heading . ,(plist-get block :title))
                                          (language . ,(plist-get block :language))
                                          (code . ,(plist-get block :code)))))))))))

;; ==========================================
;; PHASE 5: TIER 2 WRITES
;; ==========================================

;; renamed from api/block/code (PUT) — collided with the GET read route above
(my/defservlet-write api/block/code/update
  (let* ((node-id (cdr (assoc 'node_id data)))
         (name (cdr (assoc 'name data)))
         (new-code (cdr (assoc 'code data)))
         (node (when node-id (ignore-errors (org-roam-node-from-id node-id)))))
    (if (or (not node-id) (not name) (not new-code))
        (insert (my/agent-api--json-error "MISSING_PARAM" "node_id, name, and code are required"))
      (if (not node)
          (insert (my/agent-api--json-error "NODE_NOT_FOUND" (format "No node with id: %s" node-id)))
        (let* ((file (org-roam-node-file node))
               (_ (my/agent-api--backup-file file))
               (result (with-current-buffer (find-file-noselect file)
                         (let ((loc (my/agent-api--find-block name)))
                           (if (not loc)
                               'not-found
                             (progn
                               (goto-char (plist-get loc :code-beg))
                               (delete-region (plist-get loc :code-beg) (plist-get loc :code-end))
                               (insert new-code)
                               (unless (string-suffix-p "\n" new-code) (insert "\n"))
                               (save-buffer)
                               'ok))))))
          (if (eq result 'not-found)
              (insert (my/agent-api--json-error "BLOCK_NOT_FOUND" (format "No block under heading: %s" name)))
            (org-roam-db-update-file file)
            (insert (my/agent-api--json `((message . "Block updated.") (node_id . ,node-id) (heading . ,name))))))))))

;; renamed from api/block/prose (PUT) — collided with the GET read route above
(my/defservlet-write api/block/prose/update
  (let* ((node-id (cdr (assoc 'node_id data)))
         (name (cdr (assoc 'name data)))
         (new-prose (cdr (assoc 'prose data)))
         (node (when node-id (ignore-errors (org-roam-node-from-id node-id)))))
    (if (or (not node-id) (not name) (not new-prose))
        (insert (my/agent-api--json-error "MISSING_PARAM" "node_id, name, and prose are required"))
      (if (not node)
          (insert (my/agent-api--json-error "NODE_NOT_FOUND" (format "No node with id: %s" node-id)))
        (let* ((file (org-roam-node-file node))
               (_ (my/agent-api--backup-file file))
               (result (with-current-buffer (find-file-noselect file)
                         (let ((loc (my/agent-api--find-block name)))
                           (if (not loc)
                               'not-found
                             (progn
                               (goto-char (plist-get loc :prose-beg))
                               (delete-region (plist-get loc :prose-beg) (plist-get loc :prose-end))
                               (insert (string-trim new-prose))
                               (insert "\n\n")
                               (save-buffer)
                               'ok))))))
          (if (eq result 'not-found)
              (insert (my/agent-api--json-error "BLOCK_NOT_FOUND" (format "No block under heading: %s" name)))
            (org-roam-db-update-file file)
            (insert (my/agent-api--json `((message . "Prose updated.") (node_id . ,node-id) (heading . ,name))))))))))

;; ==========================================
;; PHASE 6: EXECUTION (tangle / detangle)
;; ==========================================

(my/defservlet-write api/tangle
  (let ((node-id (cdr (assoc 'node_id data))))
    (if (not node-id)
        (insert (my/agent-api--json-error "MISSING_PARAM" "node_id is required"))
      (let ((node (ignore-errors (org-roam-node-from-id node-id))))
        (if (not node)
            (insert (my/agent-api--json-error "NODE_NOT_FOUND" (format "No node with id: %s" node-id)))
          (let ((file (org-roam-node-file node)))
            (with-current-buffer (find-file-noselect file)
              (my-quiet-tangle))
            (insert (my/agent-api--json `((message . "Tangled.") (node_id . ,node-id))))))))))

(my/defservlet-write api/detangle
  (let ((file (cdr (assoc 'file data))))
    (if (not file)
        (insert (my/agent-api--json-error "MISSING_PARAM" "file (path to the tangled code file) is required"))
      (let ((path (expand-file-name file)))
        (if (not (file-exists-p path))
            (insert (my/agent-api--json-error "FILE_NOT_FOUND" (format "No such file: %s" path)))
          (with-current-buffer (find-file-noselect path)
            (my-quiet-detangle))
          (insert (my/agent-api--json `((message . "Detangled.") (file . ,path)))))))))

;; ==========================================
;; SERVER LIFECYCLE
;; ==========================================

(defun my/agent-api-start ()
  "Start the agent API HTTP server."
  (interactive)
  (setq httpd-port my/agent-api-port)
  (httpd-start)
  (message "Agent API listening on port %d" my/agent-api-port))

(defun my/agent-api-stop ()
  "Stop the agent API HTTP server."
  (interactive)
  (httpd-stop)
  (message "Agent API stopped."))

(provide 'org-roam-agent-api)
;;; org-roam-agent-api.el ends here
