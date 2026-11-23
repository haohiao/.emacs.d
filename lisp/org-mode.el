;;; org-mode.el --- Org 模式配置

;;; Commentary:
;; Org 模式配置。

;;; Code:

;;; 基础配置

(require 'org)

;;; TODO 状态

(setq org-todo-keywords
      '((sequence
         "未启(t!)"
         "进行(i!)"
         "暂停(p!)"
         "|"
         "完成(d!)"
         "终止(c!)")))

;;; TODO 时间记录

;; 使用 Org 原生 CLOSED 时间记录
;; (setq org-log-done 'time)

;; 状态变化记录到 LOGBOOK
(setq org-log-into-drawer t)

;; 状态日志按照时间顺序记录
(setq org-log-states-order-reversed nil)

;;; 复选框

(setq org-checkbox-statistics t)

;;; 编辑

;; 自动缩进
(setq org-startup-indented t)

;;; 折叠

;; 默认显示标题和正文，不展开所有子标题
(setq org-startup-folded 'content)

;;; 文档显示

;; 隐藏强调符号
(setq org-hide-emphasis-markers t)

;; 允许强调标记紧邻中文标点，重建用于字体渲染的匹配规则。
(let ((components (copy-sequence org-emphasis-regexp-components)))
  (setcar components (concat (car components) "，。！？；：、（【「『“‘"))
  (setcar (cdr components) (concat (cadr components) "，。！？；：、）】」』”’"))
  (org-set-emph-re 'org-emphasis-regexp-components components))

;;; 文档视觉层次

;; 保持等宽正文；明暗主题分别使用柔和、可读的颜色。
(defun config-org-apply-faces ()
  "根据当前明暗主题设置 Org 文档和状态配色。"
  (let* ((dark (memq 'modus-vivendi custom-enabled-themes))
         (heading (if dark "#b0c4cc" "#263e47"))
         (secondary (if dark "#aeb9bd" "#354b50"))
         (muted (if dark "#a8adb0" "#465154"))
         (block (if dark "#202528" "#f2f4f3"))
         (block-edge (if dark "#2a3033" "#e8edeb")))
    (dolist (face `((org-document-title :foreground ,heading :weight bold :height 1.25)
                    (org-level-1 :foreground ,heading :weight bold :height 1.14)
                    (org-level-2 :foreground ,secondary :weight bold :height 1.07)
                    (org-level-3 :foreground ,muted :weight bold :height 1.0)
                    (org-level-4 :foreground ,muted :weight normal :height 1.0)
                    (org-block :background ,block :extend t)
                    (org-block-begin-line :foreground ,muted :background ,block-edge :extend t)
                    (org-block-end-line :foreground ,muted :background ,block-edge :extend t)
                    (org-table :foreground ,secondary)
                    (org-link :foreground ,(if dark "#9bbdd0" "#466b7c") :underline t)))
      (apply #'set-face-attribute (car face) nil (cdr face)))
    (setq org-todo-keyword-faces
          `(("未启" . ,muted)
            ("进行" . ,(if dark "#a8c5d5" "#416b7e"))
            ("暂停" . ,(if dark "#d1bb94" "#806644"))
            ("完成" . ,(if dark "#a8c5ac" "#53745b"))
            ("终止" . ,muted)))
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (derived-mode-p 'org-mode) (font-lock-flush))))))

(config-org-apply-faces)

(provide 'org-mode)

;;; org-mode.el ends here
