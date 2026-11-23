;;; display.el --- 显示配置

;;; Commentary:
;; 显示配置。

;;; Code:

;;; 常量

;;; 界面主题

;; 使用 Emacs 内置主题，不增加外部依赖。
(defcustom config-default-theme 'modus-operandi
  "启动时使用的主题。"
  :type '(choice (const :tag "明亮" modus-operandi)
                 (const :tag "暗色" modus-vivendi))
  :group 'faces)

;; 暗色正文避免纯黑背景和接近纯白的文字带来的眩光。
(setq modus-vivendi-palette-overrides
      '((bg-main "#202528")
        (fg-main "#c5c9c7")))

(defun config-set-theme (theme)
  "启用 THEME，并同步更新 Org 配色。"
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme theme t)
  (when (fboundp 'config-org-apply-faces)
    (config-org-apply-faces)))

(defun config-toggle-theme ()
  "在内置明亮和暗色主题之间切换。"
  (interactive)
  (config-set-theme (if (memq 'modus-vivendi custom-enabled-themes)
                        'modus-operandi 'modus-vivendi))
  (message "已切换到%s主题" (if (memq 'modus-vivendi custom-enabled-themes) "暗色" "明亮")))

(config-set-theme config-default-theme)
(global-set-key (kbd "C-c t") #'config-toggle-theme)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(setq inhibit-startup-screen t
      frame-title-format '(:eval (if buffer-file-name
                                     (abbreviate-file-name buffer-file-name)
                                   "%b")))
(setq-default cursor-type 'bar)

;; Windows 临时目录使用完整路径，避免 Administrator 被缩写为 ADMIN~1，
;; 导致 LaTeX 无法识别路径。预览图片也存放在该目录下。
(when (eq system-type 'windows-nt)
  (setq temporary-file-directory
        (file-name-as-directory
         (or (w32-long-file-name (directory-file-name temporary-file-directory))
             temporary-file-directory)))
  (setq org-preview-latex-image-directory
        (expand-file-name "org-latex/" temporary-file-directory)))

;; 默认文本宽度
(defconst config-fill-column 124) ; 文本列宽

;; 窗口宽度
;;
;; 比文本宽度多 2 列：
;;   1. 避免 fill-column 参考线贴在窗口边缘
;;   2. 给窗口边框和显示区域留一点空间
(defconst config-frame-width
  (+ config-fill-column 2))

;; 窗口上下边距（像素）
;;
;; 窗口不会紧贴桌面顶部和底部。
(defconst config-frame-vertical-margin 50)

;;; 设置默认文本宽度

(setq-default fill-column config-fill-column)

;;; 自动视觉换行（只影响显示，不修改文件）

;; 中文按字符类别寻找换行位置，避免整段文字被挪到下一行。
(setq-default word-wrap-by-category t)
(global-visual-line-mode 1)

;; 普通文本的续行跟随列表缩进；Org 缩进模式自行处理其列表。
(defun config-enable-visual-wrap-prefix ()
  "在非 Org 文本缓冲区启用视觉续行缩进。"
  (unless (derived-mode-p 'org-mode)
    (visual-wrap-prefix-mode 1)))

(add-hook 'text-mode-hook #'config-enable-visual-wrap-prefix)

(use-package visual-fill-column
  :hook (visual-line-mode . visual-fill-column-for-vline)
  :custom
  ;; 视觉换行宽度与项目设置的最大列保持一致。
  (visual-fill-column-width config-fill-column)
  (visual-fill-column-center-text nil))

;;; 显示列宽参考线

;; (setq-default display-fill-column-indicator-column config-fill-column)
;; (global-display-fill-column-indicator-mode 1)

;;; 设置默认窗口大小

;; 设置窗口宽度
;;
;; Emacs 的 width 单位是“字符列”，不是像素。
(add-to-list 'default-frame-alist
             `(width . ,config-frame-width))

;; 高度不在这里固定。
;;
;; 启动后根据当前显示器工作区动态计算，
;; 这样可以适应：
;;
;;   - 不同分辨率
;;   - Windows 缩放
;;   - 不同显示器
;;   - 任务栏位置
;;
;; 因此这里不再设置 height。

;;; 设置窗口位置和高度

(defun config-center-frame ()
  "Set frame size and position according to the current monitor."

  (when (display-graphic-p)
   (let* ((frame (selected-frame))

         ;; 当前显示器的工作区
         ;;
         ;; 与 display-pixel-width / display-pixel-height 不同，
         ;; frame-monitor-workarea 会考虑 Windows 任务栏等区域。
         (workarea (frame-monitor-workarea frame))

         ;; 工作区位置
         (workarea-x (nth 0 workarea))
         (workarea-y (nth 1 workarea))

         ;; 工作区大小
         (workarea-width (nth 2 workarea))
         (workarea-height (nth 3 workarea))

         ;; 上下边距
         (margin config-frame-vertical-margin)

         ;; 字符高度（像素）
         (char-height (frame-char-height frame))

         ;; 窗口可用高度
         (available-height
          (- workarea-height
             (* margin 2)))

         ;; 根据像素高度转换成 Emacs 行数
         (frame-height
          (max 1
               (floor (/ available-height
                         char-height)))))

    ;; -------------------------------------------------------------------------------------------------
    ;; 设置窗口大小
    ;; -------------------------------------------------------------------------------------------------

    ;; width：
    ;;   使用字符列数
    ;;
    ;; height：
    ;;   根据当前显示器工作区动态计算
    (set-frame-size frame
                    config-frame-width
                    frame-height)

    ;; -------------------------------------------------------------------------------------------------
    ;; 获取调整后的实际像素大小
    ;; -------------------------------------------------------------------------------------------------

    (let* ((frame-pixel-width
            (frame-pixel-width frame))

           (frame-pixel-height
            (frame-pixel-height frame))

           ;; 水平居中
           (left
            (+ workarea-x
               (/ (- workarea-width
                     frame-pixel-width)
                  2)))

           ;; 垂直位置
           ;;
           ;; 不再真正“垂直居中”，
           ;; 而是固定距离工作区顶部 margin 像素。
           (top
            (+ workarea-y
               margin)))

      ;; -------------------------------------------------------------------------------------------------
      ;; 设置窗口位置
      ;; -------------------------------------------------------------------------------------------------

      (set-frame-position frame
                          left
                          top)))))

;;; Emacs 启动完成后调整窗口

;;
;; emacs-startup-hook：
;;
;;   Emacs 启动流程完成后执行。
;;
;; 此时：
;;
;;   - frame 已经创建
;;   - 字体已经基本确定
;;   - frame-char-height 可以正常获取
;;   - frame-monitor-workarea 可以正常获取
;;
(add-hook 'emacs-startup-hook
          #'config-center-frame)

;;; 窗口显示

;; 某些情况下 Emacs 以隐藏 frame 启动，
;; 确保启动完成后窗口可见。
(add-hook 'emacs-startup-hook
          (lambda ()
            (when (display-graphic-p) (make-frame-visible))))

(provide 'display)

;;; display.el ends here
