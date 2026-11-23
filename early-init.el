;;; early-init.el --- 启动兼容性配置 -*- lexical-binding: t; -*-

;;; Commentary:
;; 处理特定 Windows Emacs 版本的启动兼容性问题。

;;; Code:

;; 在加载软件包前禁用原生编译代码，保留字节码加载。
(when (and (eq system-type 'windows-nt)
           (= emacs-major-version 31)
           (= emacs-minor-version 1))
  (setq load-no-native t
        native-comp-jit-compilation nil))

;;; early-init.el ends here
