;;; org-life.el --- 人生：递归式事件管理 -*- lexical-binding: t; -*-

;;; Commentary:
;; 人生：递归式事件管理。

;;; Code:

;;; 加载依赖

(require 'org)
(require 'seq)
(require 'subr-x)

;;; 基础配置

(defgroup life nil
  "人生：主体、规划、事件和任务管理。"
  :group 'org)

;; 默认使用当前用户主目录下的「人生」仓库。
(defcustom life-root "~/人生/"
  "人生管理仓库的根目录。"
  :type 'directory
  :group 'life)

;;; 目录与编号

(defun life--root ()
  "返回人生根目录；不存在时提示错误。"
  (let ((root (file-name-as-directory (expand-file-name life-root))))
    (unless (file-directory-p root)
      (user-error "人生根目录不存在：%s" root))
    root))

(defun life--directories (directory pattern)
  "返回 DIRECTORY 中名称匹配 PATTERN 的直接子目录。"
  (when (file-directory-p directory)
    (seq-filter #'file-directory-p
                (directory-files directory t pattern t))))

(defun life--subjects ()
  "返回有效主体目录；不递归搜索仓库或附件。"
  (let ((root (life--root)) result)
    (dolist (kind '(("个人" . "P[0-9]+") ("组织" . "O[0-9]+")))
      (let ((directory (expand-file-name (car kind) root))
            (pattern (concat "\\`" (cdr kind) "\\'")))
        (dolist (subject (life--directories directory pattern))
          (when (file-exists-p (expand-file-name "目录.org" subject))
            (push subject result)))))
    (nreverse result)))

(defun life--events (container)
  "递归返回 CONTAINER 下的事件目录，只沿正式的「事件/」向下搜索。"
  (let (result)
    (dolist (event (life--directories
                    (expand-file-name "事件" container) "\\`E-[0-9]+\\'"))
      (when (file-exists-p (expand-file-name "目录.org" event))
        (push event result)
        (setq result (nconc (nreverse (life--events event)) result))))
    (nreverse result)))

(defun life--containers ()
  "返回主体和全部事件容器。"
  (let (result)
    (dolist (subject (life--subjects))
      (push subject result)
      (dolist (event (life--events subject))
        (push event result)))
    (nreverse result)))

(defun life--select-container (&optional event-only)
  "选择管理容器；EVENT-ONLY 非空时只允许选择事件。"
  (let* ((root (life--root))
         (directories (if event-only
                          (apply #'append (mapcar #'life--events
                                                  (life--subjects)))
                        (life--containers)))
         (choices (mapcar (lambda (dir)
                            (cons (file-relative-name dir root) dir))
                          directories)))
    (unless choices
      (user-error "没有可用的%s目录" (if event-only "事件" "主体或事件")))
    (cdr (assoc (completing-read "管理容器：" choices nil t) choices))))

(defun life--subject (container)
  "从 CONTAINER 所在路径取得其主体目录。"
  (let ((directory (file-name-as-directory (expand-file-name container)))
        (root (life--root))
        found)
    (while (and (not found) (file-in-directory-p directory root))
      (let* ((name (file-name-nondirectory (directory-file-name directory)))
             (parent (file-name-nondirectory
                      (directory-file-name (file-name-directory
                                            (directory-file-name directory))))))
        (if (or (and (equal parent "个人") (string-match-p "\\`P[0-9]+\\'" name))
                (and (equal parent "组织") (string-match-p "\\`O[0-9]+\\'" name)))
            (setq found directory)
          (setq directory (file-name-directory (directory-file-name directory))))))
    (or found (user-error "无法确定所属主体：%s" container))))

(defun life--object-dirs (container kind)
  "递归收集 CONTAINER 范围内类型为 KIND 的规划或事件目录。"
  (let ((pattern (if (equal kind "规划") "\\`P-[0-9]+\\'" "\\`E-[0-9]+\\'"))
        result)
    (dolist (dir (life--directories (expand-file-name kind container) pattern))
      (push dir result))
    (dolist (event (life--directories
                    (expand-file-name "事件" container) "\\`E-[0-9]+\\'"))
      (setq result (nconc (life--object-dirs event kind) result)))
    result))

(defun life--next-id (subject kind)
  "计算 SUBJECT 下 KIND 类型的下一个编号；不复用现存目录中的编号。"
  (let ((maximum 0)
        (prefix (if (equal kind "规划") "P" "E")))
    (dolist (dir (life--object-dirs subject kind))
      (let ((name (file-name-nondirectory (directory-file-name dir))))
        (when (string-match (concat "\\`" prefix "-\\([0-9]+\\)\\'") name)
          (setq maximum (max maximum (string-to-number (match-string 1 name)))))))
    (format "%s-%04d" prefix (1+ maximum))))

;;; 登记表

(defun life--table-position (file heading)
  "在 FILE 当前缓冲区中查找「* 登记」下 HEADING 表格的插入位置。
仅检查直接位于对应二级标题之下的登记表，避免误写其他部分。"
  (goto-char (point-min))
  (unless (re-search-forward "^\\* 登记[ \t]*$" nil t)
    (user-error "缺少一级标题「* 登记」：%s" file))
  (let ((end (save-excursion
               (or (and (re-search-forward "^\\* " nil t) (line-beginning-position))
                   (point-max)))))
    (unless (re-search-forward (format "^\\*\\* %s[ \t]*$" (regexp-quote heading)) end t)
      (user-error "登记区域缺少「** %s」：%s" heading file))
    (let ((limit (save-excursion
                   (or (and (re-search-forward "^\\*+ " end t) (line-beginning-position))
                       end))))
      (unless (re-search-forward "^|" limit t)
        (user-error "「** %s」下没有 Org 登记表：%s" heading file))
      (beginning-of-line)
      (while (and (< (point) limit) (looking-at-p "^|"))
        (forward-line 1))
      (point))))

(defun life--register (index-file kind row)
  "将 ROW 登记到 INDEX-FILE 中 KIND 类型的表格。"
  (with-current-buffer (find-file-noselect index-file)
    ;; 避免未保存的用户编辑被命令附带写入磁盘。
    (when (buffer-modified-p)
      (user-error "登记文件有未保存的修改，请先保存：%s" index-file))
    (save-excursion
      (org-with-wide-buffer
        (goto-char (life--table-position index-file kind))
        (insert row "\n")
        (forward-line -1)
        (org-table-align)
        (save-buffer)))))

(defun life--check-register (index-file kind)
  "在修改文件前确认 INDEX-FILE 有 KIND 登记表并且没有未保存更改。"
  (unless (file-exists-p index-file)
    (user-error "父容器没有入口文件：%s" index-file))
  (with-current-buffer (find-file-noselect index-file)
    (when (buffer-modified-p)
      (user-error "请先保存父容器入口文件：%s" index-file))
    (save-excursion
      (org-with-wide-buffer
        (life--table-position index-file kind)))))

;;; 新建规划与事件

(defun life--event-template (id name)
  "生成 ID、NAME 对应的事件入口正文。"
  (format (concat "#+title: %s - %s\n#+startup: overview\n\n"
                  "* 概述\n** 目标\n** 完成标准\n** 实施安排\n\n"
                  "* 登记\n** 规划\n"
                  "| 编号 | 规划 | 规划目录 | 建立日期 | 状态 |\n"
                  "|------+------+----------+----------+------|\n\n"
                  "** 事件\n"
                  "| 编号 | 事件 | 事件目录 | 建立日期 | 状态 |\n"
                  "|------+------+----------+----------+------|\n\n"
                  "** 任务\n任务详情见 [[file:任务/任务.org][任务清单]]（建立任务后生效）。\n"
                  "** 日志\n** 仓库\n\n"
                  "* 结项\n** 结果\n** 经验与遗留问题\n") id name))

(defun life--plan-template (id name)
  "生成 ID、NAME 对应的规划入口正文。"
  (format (concat "#+title: %s - %s\n#+startup: overview\n\n"
                  "* 目标\n* 完成标准\n* 路线\n* 关联事件\n* 评估与调整\n") id name))

(defun life--new-object (kind)
  "在所选管理容器下新建 KIND（规划或事件）并写入唯一登记表。"
  (let* ((container (life--select-container))
         (subject (life--subject container))
         (id (life--next-id subject kind))
         (name (string-trim (read-string (format "%s %s 名称：" kind id))))
         (file-name (if (equal kind "事件") "目录.org" "规划.org"))
         (index-file (expand-file-name "目录.org" container))
         (dir (expand-file-name (concat kind "/" id) container))
         (file (expand-file-name file-name dir))
         (relative (concat kind "/" id "/" file-name))
         (row (format "| %s | %s | [[file:%s][%s/%s]] | %s | 未启 |"
                      id name relative kind id
                      (format-time-string "%Y-%m-%d"))))
    (when (string-empty-p name)
      (user-error "名称不能为空"))
    (when (file-exists-p dir)
      (user-error "目标目录已存在：%s" dir))
    (life--check-register index-file kind)
    (make-directory dir t)
    (condition-case err
        (progn
          (with-temp-file file
            (insert (if (equal kind "事件")
                        (life--event-template id name)
                      (life--plan-template id name))))
          (life--register index-file kind row))
      (error
       ;; 登记失败时删除本次新建的、仍只包含入口文件的目录。
       (when (and (file-directory-p dir)
                  (equal (directory-files dir nil directory-files-no-dot-files-regexp)
                         (list file-name)))
         (delete-directory dir t))
       (signal (car err) (cdr err))))
    ;; 登记成功后即使打开失败，也保留已创建的对象及登记。
    (find-file file)
    (message "已建立 %s，并登记在直接父容器：%s" id index-file)))

(defun life-new-event ()
  "新建事件，自动分配主体范围内唯一的 E-编号。"
  (interactive)
  (life--new-object "事件"))

(defun life-new-plan ()
  "新建规划，自动分配主体范围内唯一的 P-编号。"
  (interactive)
  (life--new-object "规划"))

;;; 任务

(defun life--next-task-id (file)
  "扫描任务 FILE 的 Org 标题，返回下一个 T-编号。"
  (let ((maximum 0))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (re-search-forward "^\\*+ +\\(?:未启\\|进行\\|暂停\\|完成\\|终止\\) +T-\\([0-9]+\\)\\(?: +\\|$\\)" nil t)
          (setq maximum (max maximum (string-to-number (match-string 1)))))))
    (format "T-%04d" (1+ maximum))))

(defun life-new-task ()
  "为所选事件建立独立编号的任务；不在主体层建立无归属任务。"
  (interactive)
  (let* ((event (life--select-container t))
         (event-id (file-name-nondirectory (directory-file-name event)))
         (file (expand-file-name "任务/任务.org" event))
         (name (string-trim (read-string "任务名称："))))
    (when (string-empty-p name)
      (user-error "任务名称不能为空"))
    (when (and (get-file-buffer file)
               (buffer-modified-p (get-file-buffer file)))
      (user-error "请先保存已有的任务文件：%s" file))
    (let ((id (life--next-task-id file)))
      (make-directory (file-name-directory file) t)
      (with-current-buffer (find-file-noselect file)
        (unless (> (buffer-size) 0)
          (insert (format "#+title: %s - 任务\n#+startup: overview\n\n" event-id)))
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (insert (format "* 未启 %s %s\n" id name))
        (save-buffer)
        (switch-to-buffer (current-buffer)))
      (message "已添加任务 %s：%s" id name))))

;;; 删除规划、事件和任务

(defun life--archive-path (name)
  "为 NAME 在人生目录的回收区中生成不重复的路径。"
  (let ((dir (expand-file-name ".life-trash/" (life--root))))
    (make-directory dir t)
    (make-temp-name (expand-file-name (concat name "-") dir))))

(defun life--assert-unmodified (directory)
  "若 DIRECTORY 内有未保存的文件缓冲区，则停止操作。"
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and buffer-file-name (buffer-modified-p)
                 (file-in-directory-p buffer-file-name directory))
        (user-error "请先保存文件：%s" buffer-file-name)))))

(defun life--registration-row (index-file kind id)
  "在当前缓冲区查找 INDEX-FILE 中 KIND 表格的唯一 ID 行。"
  (let ((end (life--table-position index-file kind)) matches)
    (goto-char end)
    (while (and (> (point) (point-min))
                (progn (forward-line -1) (looking-at-p "^|")))
      (when (looking-at-p (concat "^|[ \t]*" (regexp-quote id) "[ \t]*|"))
        (push (line-beginning-position) matches)))
    (unless (= (length matches) 1)
      (user-error "登记表中 %s 的记录不是唯一的一行" id))
    (car matches)))

(defun life--delete-object (kind)
  "选择 KIND 对象并移入回收区，同时删除其父级登记。"
  (let* ((root (life--root))
         (dirs (apply #'append
                      (mapcar (lambda (subject)
                                (life--object-dirs subject kind))
                              (life--subjects))))
         (choices (mapcar (lambda (dir) (cons (file-relative-name dir root) dir)) dirs)))
    (unless choices (user-error "没有可删除的%s" kind))
    (let* ((dir (cdr (assoc (completing-read (concat "删除" kind "：") choices nil t) choices)))
           (id (file-name-nondirectory (directory-file-name dir)))
           (parent (file-name-directory (directory-file-name (file-name-directory (directory-file-name dir)))))
           (index (expand-file-name "目录.org" parent)))
      (when (file-symlink-p dir) (user-error "不能删除符号链接：%s" dir))
      (life--assert-unmodified dir)
      (life--check-register index kind)
      (with-current-buffer (find-file-noselect index)
        (save-restriction
          (widen)
          (let ((row (save-excursion (life--registration-row index kind id))))
            (when (yes-or-no-p (format "将 %s 及其全部内容移入回收区并删除登记？" (file-relative-name dir root)))
              (let ((archive (life--archive-path id)))
                (rename-file dir archive)
                (condition-case err
                    (progn
                      (atomic-change-group
                        (goto-char row)
                        (delete-region (line-beginning-position) (min (point-max) (1+ (line-end-position))))
                        (save-buffer))
                      (message "已移入回收区：%s" archive))
                  (error (rename-file archive dir) (signal (car err) (cdr err))))))))))))

(defun life-delete-event ()
  "选择事件并移入回收区。"
  (interactive)
  (life--delete-object "事件"))

(defun life-delete-plan ()
  "选择规划并移入回收区。"
  (interactive)
  (life--delete-object "规划"))

(defun life-delete-task ()
  "删除当前任务标题及其内容，并将其备份到回收区。"
  (interactive)
  (unless (and buffer-file-name (derived-mode-p 'org-mode)
               (string= (file-name-nondirectory buffer-file-name) "任务.org")
               (string= (file-name-nondirectory (directory-file-name (file-name-directory buffer-file-name))) "任务")
               (seq-some (lambda (event)
                           (file-equal-p event (file-name-directory
                                                (directory-file-name (file-name-directory buffer-file-name)))))
                         (apply #'append (mapcar #'life--events (life--subjects)))))
    (user-error "请在正式事件的任务.org 中执行"))
  (when (buffer-modified-p) (user-error "请先保存任务文件"))
  (org-back-to-heading t)
  (unless (looking-at "^\\*+ +\\(?:未启\\|进行\\|暂停\\|完成\\|终止\\) +\\(T-[0-9]+\\)\\(?: +\\|$\\)")
    (user-error "请将光标放在任务标题或其内容中"))
  (let* ((id (match-string-no-properties 1))
         (start (point))
         (end (save-excursion (org-end-of-subtree t t) (point))))
    (when (yes-or-no-p (format "删除任务 %s 及其全部子内容？" id))
      (let ((archive (concat (life--archive-path id) ".org")))
        (write-region start end archive nil 'silent)
        (atomic-change-group
          (delete-region start end)
          (save-buffer))
        (message "已备份任务到：%s" archive)))))

;;; 导航与议程

(defun life-empty-trash ()
  "永久清空人生回收区；操作前要求输入确认文字。"
  (interactive)
  (let ((trash (expand-file-name ".life-trash" (life--root))))
    (unless (and (file-directory-p trash) (not (file-symlink-p trash)))
      (user-error "回收区不存在或不是普通目录"))
    (let ((entries (directory-files trash t directory-files-no-dot-files-regexp)))
      (unless entries (user-error "回收区为空"))
      (unless (equal (read-string (format "永久删除回收区中的 %d 项；请输入 清空回收区：" (length entries)))
                     "清空回收区")
        (user-error "已取消清空"))
      (dolist (entry entries)
        (if (and (file-directory-p entry) (not (file-symlink-p entry)))
            (delete-directory entry t)
          (delete-file entry)))
      (message "回收区已清空"))))

(defun life-open-root ()
  "打开人生根目录入口。"
  (interactive)
  (let ((file (expand-file-name "目录.org" (life--root))))
    (unless (file-exists-p file)
      (user-error "根目录缺少目录.org：%s" file))
    (find-file file)))

(defun life-open-container ()
  "从主体和递归事件列表中选择一个目录入口。"
  (interactive)
  (find-file (expand-file-name "目录.org" (life--select-container))))

(defun life-refresh-agenda ()
  "将人生仓库下正式事件的任务文件加入 Org Agenda。"
  (interactive)
  (let (files)
    (dolist (event (apply #'append (mapcar #'life--events
                                             (life--subjects))))
      (let ((file (expand-file-name "任务/任务.org" event)))
        (when (file-exists-p file)
          (push file files))))
    (setq org-agenda-files (nreverse files))
    (message "Org Agenda 已收集 %d 个事件任务文件" (length org-agenda-files))))

;;; 快捷键

;; 使用 C-c l 作为「人生」独立前缀，不覆盖既有 Org 标准按键。
(defvar life-map (make-sparse-keymap)
  "人生管理命令的快捷键映射。")

(define-key global-map (kbd "C-c l") life-map)
(define-key life-map (kbd "r") #'life-open-root)
(define-key life-map (kbd "o") #'life-open-container)
(define-key life-map (kbd "e") #'life-new-event)
(define-key life-map (kbd "p") #'life-new-plan)
(define-key life-map (kbd "t") #'life-new-task)
(define-key life-map (kbd "a") #'life-refresh-agenda)
(define-key life-map (kbd "d e") #'life-delete-event)
(define-key life-map (kbd "d p") #'life-delete-plan)
(define-key life-map (kbd "d t") #'life-delete-task)
(define-key life-map (kbd "d c") #'life-empty-trash)

(provide 'org-life)

;;; org-life.el ends here
