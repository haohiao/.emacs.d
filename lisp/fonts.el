;;; fonts.el --- 字体和编码配置

;;; Commentary:
;; 字体和编码配置。

;;; Code:

;;; 默认字体
;;; 中文、英文、数字

(set-face-attribute 'default nil
                    :family "霞鹜文楷等宽"
                    :height 120)

;;; 中文

(set-fontset-font t 'han
                  (font-spec :family "霞鹜文楷等宽"))

;;; CJK 扩展汉字
;;; 生僻中文字符

(set-fontset-font t 'cjk-misc
                  (font-spec :family "霞鹜文楷等宽"))

;;; 英文、数字、拉丁字符

(set-fontset-font t 'latin
                  (font-spec :family "霞鹜文楷等宽"))

;;; 符号

(set-fontset-font t 'symbol
                  (font-spec :family "霞鹜文楷等宽"))

;;; 默认编码

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(setq-default buffer-file-coding-system 'utf-8-unix)

(provide 'fonts)

;;; fonts.el ends here
