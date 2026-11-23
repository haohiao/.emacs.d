;;; completion.el --- 补全配置

;;; Commentary:
;; 补全配置。

;;; Code:

;;; 加载依赖

(require 'use-package)

;;; Eldoc
;;; 函数参数提示

;; 例如：
;; (set-face-attribute
;; 显示：
;; set-face-attribute FACE ATTRIBUTE &rest ARGS
(global-eldoc-mode 1)

;;; Corfu
;;; 自动补全

(use-package corfu
  :custom
  (corfu-cycle t)
  (corfu-auto t)
  :config
  (global-corfu-mode 1))

(provide 'completion)

;;; completion.el ends here
