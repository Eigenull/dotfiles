;; notmuch-crypto.el --- functions for handling display of cryptographic metadata.
;;
;; Copyright © Jameson Rollins
;;
;; This file is part of Notmuch.
;;
;; Notmuch is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Notmuch is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with Notmuch.  If not, see <http://www.gnu.org/licenses/>.
;;
;; Authors: Jameson Rollins <jrollins@finestructure.net>

(defcustom notmuch-crypto-process-mime nil
  "Should cryptographic MIME parts be processed?

If this variable is non-nil signatures in multipart/signed
messages will be verified and multipart/encrypted parts will be
decrypted.  The result of the crypto operation will be displayed
in a specially colored header button at the top of the processed
part.  Signed parts will have variously colored headers depending
on the success or failure of the verification process and on the
validity of user ID of the signer.

The effect of setting this variable can be seen temporarily by
viewing a signed or encrypted message with M-RET in notmuch
search."
  :group 'notmuch
  :type 'boolean)

(defface notmuch-crypto-not-processed
  '((t (:foreground "blue")))
  "Face used for unprocessed cryptographic mime parts."
  :group 'notmuch)

(defface notmuch-crypto-signature-not-processed
  '((t (:background "red" :foreground "black")))
  "Face used for unprocessed signatures."
  :group 'notmuch)

(defface notmuch-crypto-signature-good
  '((t (:background "green" :foreground "black")))
  "Face used for good signatures."
  :group 'notmuch)

(defface notmuch-crypto-signature-good-key
  '((t (:background "orange" :foreground "black")))
  "Face used for good signatures."
  :group 'notmuch)

(defface notmuch-crypto-signature-bad
  '((t (:background "red" :foreground "black")))
  "Face used for bad signatures."
  :group 'notmuch)

(defface notmuch-crypto-signature-unknown
  '((t (:background "red" :foreground "black")))
  "Face used for signatures of unknown status."
  :group 'notmuch)

(defface notmuch-crypto-encryption
  '((t (:background "purple" :foreground "black")))
  "Face used for encryption/decryption status messages."
  :group 'notmuch)

(define-button-type 'notmuch-crypto-status-button-type
  'action '(lambda (button) (message (button-get button 'help-echo)))
  'follow-link t
  'help-echo "Set notmuch-crypto-process-mime to process cryptographic mime parts."
  'face 'notmuch-crypto-not-processed
  'mouse-face 'notmuch-crypto-not-processed)

(defun notmuch-crypto-insert-sigstatus-button (sigstatus from)
  (let* ((status (plist-get sigstatus :status))
	 (help-msg nil)
	 (label "multipart/signed: signature not processed")
	 (face 'notmuch-crypto-signature-not-processed)
	 (button-action '(lambda (button) (message (button-get button 'help-echo)))))
    (cond
     ((string= status "good")
      ; if userid present, userid has full or greater validity
      (if (plist-member sigstatus :userid)
	  (let ((userid (plist-get sigstatus :userid)))
	    (setq label (concat "Good signature by: " userid))
	    (setq face 'notmuch-crypto-signature-good))
	(let ((fingerprint (concat "0x" (plist-get sigstatus :fingerprint))))
	  (setq label (concat "Good signature by key: " fingerprint))
	  (setq face 'notmuch-crypto-signature-good-key))))
     ((string= status "error")
      (let ((keyid (concat "0x" (plist-get sigstatus :keyid))))
	(setq label (concat "Unknown key ID " keyid " or unsupported algorithm"))
	(setq face 'notmuch-crypto-signature-unknown)
	(setq button-action 'notmuch-crypto-sigstatus-callback)))
     ((string= status "bad")
      (let ((keyid (concat "0x" (plist-get sigstatus :keyid))))
	(setq label (concat "Bad signature (claimed key ID " keyid ")"))
	(setq face 'notmuch-crypto-signature-bad)))
     (t
      (setq label "Unknown signature status")
      (if status (setq label (concat label " \"" status "\"")))))
    (insert-button
     (concat "[ " label " ]")
     :type 'notmuch-crypto-status-button-type
     'help-echo help-msg
     'face face
     'mouse-face face
     'action button-action
     :notmuch-sigstatus sigstatus
     :notmuch-from from)
    (insert "\n")))

(defun notmuch-crypto-sigstatus-callback (button)
  (let* ((sigstatus (button-get button :notmuch-sigstatus))
	 (keyid (plist-get sigstatus :keyid)))
    (notmuch-crypto-maybe-fetch (concat "0x" keyid))))

(defun notmuch-crypto-maybe-fetch (query)
  (if (require 'epg nil t)
      (when (y-or-n-p (concat "Fetch " query " from keyserver?"))
	(let ((context (epg-make-context 'OpenPGP)))
	  (epg-receive-keys context (list query))))
    (message "EasyPG (included in Emacs 23) is needed to fetch keys")))

(defun notmuch-crypto-insert-encstatus-button (encstatus)
  (let* ((status (plist-get encstatus :status))
	 (help-msg nil)
	 (label "multipart/encrypted: decryption not attempted")
	 (face 'notmuch-crypto-encryption))
    (cond
     ((string= status "good")
      (setq label "decryption successful"))
     ((string= status "bad")
      (setq label "decryption error"))
     (t
      (setq label (concat "unknown encstatus \"" status "\""))))
    (insert-button
     (concat "[ multipart/encrypted: " label " ]")
     :type 'notmuch-crypto-status-button-type
     'help-echo help-msg
     'face face
     'mouse-face face)
    (insert "\n")))

;;

(provide 'notmuch-crypto)
