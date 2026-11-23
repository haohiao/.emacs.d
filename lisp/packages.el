;;; packages.el --- 包管理配置

;;; Commentary:
;; 包管理配置。

;;; Code:

;;; 加载 package

(require 'package)

;;; 软件源

(setq package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
        ("melpa" . "https://melpa.org/packages/")))

;;; 初始化 package

(unless (bound-and-true-p package--initialized)
  (package-initialize))

;;; use-package

;; 如果没有安装 use-package，则自动安装
(unless (package-installed-p 'use-package)
  (package-refresh-contents)		; 更新包列表
  (package-install 'use-package))	; 安装use-package

;; 加载 use-package
(require 'use-package)			

;; 默认自动安装依赖包
(setq use-package-always-ensure t)

(provide 'packages)

;;; packages.el ends here
