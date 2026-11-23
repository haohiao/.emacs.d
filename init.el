;;; init.el --- 初始化配置

;;; Commentary:
;; 初始化配置。

;;; Code:

;;; 模块路径

(add-to-list 'load-path "~/.emacs.d/lisp/")

;;; 加载模块

(require 'packages)			; 包管理
(require 'fonts)			; 字体
(require 'display)			; 显示
(require 'completion)			; 补全
(require 'org-mode)                     ; Org-mode
(require 'org-life)                     ; 人生：递归事件管理

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(corfu visual-fill-column)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;;; init.el ends here
