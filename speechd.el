;;; speechd.el --- Library for accessing Speech Daemon

;; Copyright (C) 2003 Brailcom, o.p.s.

;; COPYRIGHT NOTICE
;;
;; This program is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 2, or (at your option) any later
;; version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.
;;
;; You can find the GNU General Public License at
;; http://www.gnu.org/copyleft/gpl.html
;; or you can write to the Free Software Foundation, Inc., 59 Temple Place,
;; Suite 330, Boston, MA 02111-1307, USA.

;;; Commentary:

;; This library allows you to communicate with Speech Daemon.
;; Usually, the communication goes like this:
;; 
;;   (speechd-open)
;;   ...
;;   (speechd-say "Hello, world!")
;;   ...
;;   (speechd-close)

;;; Code:


(eval-when-compile (require 'cl))


(defvar speechd-connection nil
  "Connection object to speechd.
Nil if no connection is currently open.")
(defvar speechd-connection-failure nil)


(defgroup speechd ()
  "Speech Daemon interface.")

(defcustom speechd-host "localhost"
  "*Name of the default host running speechd to connect to."
  :type 'string
  :group 'speechd)

(defcustom speechd-port 9876
  "*Default port of speechd."
  :type 'integer
  :group 'speechd)

(defcustom speechd-timeout 3
  "*Number of seconds to wait for speechd response."
  :type 'integer
  :group 'speechd)

(defconst speechd-priority-tags
  '(radio (const :tag "High"   :value :high)
	  (const :tag "Medium" :value :medium)
	  (const :tag "Low"    :value :low)))

(defcustom speechd-default-text-priority :medium
  "*Default Speech Daemon priority of sent texts."
  :type speechd-priority-tags
  :group 'speechd)

(defcustom speechd-default-sound-priority :medium
  "*Default Speech Daemon priority of sent sound icons."
  :type speechd-priority-tags
  :group 'speechd)

(defcustom speechd-default-char-priority :low
  "*Default Speech Daemon priority of sent single letters."
  :type speechd-priority-tags
  :group 'speechd)

(defcustom speechd-default-key-priority :low
  "*Default Speech Daemon priority of sent symbols of keys."
  :type speechd-priority-tags
  :group 'speechd)

(defcustom speechd-debug nil
  "*If non-nil, be verbose about communication with speechd."
  :type 'boolean
  :group 'speechd)


(defconst speechd-el-version "speechd-el $Id: speechd.el,v 1.7 2003-04-17 15:24:59 pdm Exp $"
  "Version stamp of the source file.
Useful only for diagnosing problems.")

(defvar speechd-buffer " *speechd*"
  "Name of the buffer associated with speechd connection.")

(defvar speechd-client-name "Emacs"
  "Name of the client as set to speechd.")

(defvar speechd-priorities
  '((:high .   "1")
    (:medium . "2")
    (:low .    "3"))
  "Alist mapping symbolic priorities to speechd parameters.
Each element is a pair is of the form (PRIORITY . SPEECHD-PARAMETER).")

(defvar speechd-punctuations
  '((:none . "none")
    (:some . "some")
    (:all . "all"))
  "Alist mapping symbolic punctuation modes to speechd parameters.
Each element is a pair is of the form (PUNCTUATION . SPEECHD-PARAMETER).")

(defvar speechd-capitalizations
  '((:on .  "1")
    (:off . "0"))
  "Alist mapping symbolic capitalization modes to speechd parameters.
Each element is a pair is of the form (CAPITALIZATION . SPEECHD-PARAMETER).")

(defvar speechd-debug-info '())

(defconst speechd-coding-system 'utf-8-dos)

(defvar speechd-connection-output nil)
(defvar speechd-sending-data-p nil)
(defvar speechd-paused-p nil)
(defvar speechd-current-priority nil)

(defun speechd-reset-connection-parameters ()
  (setq speechd-connection-output nil
	speechd-sending-data-p nil
	speechd-paused-p nil
	speechd-current-priority nil))

(defun speechd-process-name ()
  (process-name speechd-connection))

(defun speechd-convert-numeric (number)
  (number-to-string (cond
		     ((< number -100) -100)
		     ((> number 100) 100)
		     (t number))))


(defun speechd-connection-filter (process string)
  (when speechd-debug
    (with-current-buffer (process-buffer process)
      (let* ((marker (process-mark process))
	     (marker-position (or (marker-position marker) 1))
	     (moving (= (point) marker-position)))
	(save-excursion
	  (goto-char marker-position)
	  (insert string)
	  (set-marker marker (point)))
	(when moving
	  (goto-char marker-position)))))
  (setq speechd-connection-output (concat speechd-connection-output string)))

;;;###autoload
(defun* speechd-open (&optional (host speechd-host) (port speechd-port))
  "Open connection to speechd running on the given host and port.
The optional arguments HOST and PORT identify the speechd location differing
from the values of `speechd-host' and `speechd-port', see `open-network-stream'
for closer description of those arguments."
  (interactive)
  (when speechd-connection
    (speechd-close))
  (speechd-reset-connection-parameters)
  (setq speechd-connection
	(condition-case nil
	    (open-network-stream "speechd-proc" speechd-buffer host port)
	  (error nil)))
  (if speechd-connection
      (progn
	(set-process-coding-system speechd-connection
				   speechd-coding-system speechd-coding-system)
	(set-process-filter speechd-connection 'speechd-connection-filter)
	(when speechd-debug
	  (message "OK")))
    (message "Connection to Speech Daemon failed"))
  (setq speechd-connection-failure (not speechd-connection))
  (when speechd-debug
    (push (cons "open" speechd-connection) speechd-debug-info))
  ;; Speech Daemon does not like running without client+connection name
  (speechd-set-connection-name "default")
  speechd-connection)

;;;public
(defun speechd-close ()
  "Close the connection to speechd."
  (interactive)
  (ignore-errors
    (delete-process speechd-connection))
  (ignore-errors
    (kill-buffer speechd-buffer))
  (when speechd-debug
    (push "close" speechd-debug-info))
  (setq speechd-connection nil))

;;;public
(defun speechd-reopen ()
  "Close and open again the connection to speechd."
  (interactive)
  (speechd-close)
  (speechd-open))

;;;public
(defun speechd-running-p ()
  (and speechd-connection (eq (process-status speechd-connection) 'open)))


(defconst speechd-eol "\n")

(defun speechd-send-string (string)
  (unwind-protect
      (process-send-string (speechd-process-name) string)
    (unless (speechd-running-p)
      (speechd-close))))

(defun speechd-command-answer ()
  ;; Why this function exists and the answer is not handled within
  ;; `speech-send-command' immediately:
  ;;
  ;; When a user walks through a buffer with autorepeated C-p or so, he wants
  ;; to listen to the very short sounds indicating beginnings of lines.  Thus
  ;; the reaction time must be very short, preferably less than 10 ms.
  ;; However, it seems that if `accept-process-output' is called and process
  ;; output is not available *immediately*, Emacs is unable to read the awaited
  ;; input anytime sooner than after several tens of miliseconds.  So we delay
  ;; reading the process output until `speechd-command-answer' is called,
  ;; either explicitly or automatically before sending next command.
  (while (and speechd-connection-output
	      (let ((len (length speechd-connection-output)))
		(or (= len 0)
		    (not (= (aref speechd-connection-output (1- len)) ?\n)))))
    (unless (accept-process-output speechd-connection speechd-timeout)
      (push (cons "Timeout:" speechd-connection-output) speechd-debug-info)
      (speechd-close)
      (error "Timeout during communication with speechd.")))
  (let ((answer speechd-connection-output))
    (setq speechd-connection-output nil)
    (when speechd-debug
      (push answer speechd-debug-info))
    answer))

(defun speechd-send-command (command &rest args)
  (when speechd-sending-data-p
    (speechd-send-data-end))
  (speechd-command-answer)
  (when (or speechd-connection
	    (and (not speechd-connection-failure) (speechd-open)))
    (let ((string-to-send (concat
			   (mapconcat #'identity (list* command args) " ")
			   speechd-eol)))
      (when speechd-debug
	(display-buffer (process-buffer speechd-connection)))
      (funcall (if speechd-debug #'message #'ignore)
	       (speechd-send-string string-to-send))
      (setq speechd-connection-output ""))))

(defun speechd-send-data (text)
  (unless speechd-sending-data-p
    (speechd-resume t)
    (speechd-send-command "SPEAK")
    (speechd-command-answer)
    (setq speechd-sending-data-p t))
  (flet ((send (string)
	   (when speechd-debug
	     (push "Sending data" speechd-debug-info))
	   (speechd-send-string string)
	   (when speechd-debug
	     (push "Data sent" speechd-debug-info))))
    (while (and (> (length text) 0)
		(string-match "\\(`\\|.*\n\\)\\(\\.\\)\\(.*\\)\\(\n\\|\\'\\)"
			      text))
      (replace-match ".." nil nil text 2)
      (let ((end (1+ (match-end 0))))
	(send (substring text 0 end))
	(setq text (substring text end))))
    (send text)
    (unless (or (string= text "")
		(eql (aref text (1- (length text))) ?\n))
      (speechd-send-string speechd-eol))))

(defun speechd-send-data-end ()
  (when speechd-sending-data-p
    (let ((speechd-sending-data-p nil))
      (speechd-send-command "."))
    (setq speechd-sending-data-p nil)))


;;;public
(defun speechd-set-connection-name (name)
  (speechd-send-command
   "SET" "CLIENT_NAME"
   (format "%s:%s:%s" (user-login-name) speechd-client-name name))
  (speechd-reset-connection-parameters))

;;;public
(defun speechd-set-language (language)
  (speechd-send-command "SET" "LANGUAGE" language))

;;;public
(defun speechd-set-priority (priority)
  (unless (eq priority speechd-current-priority)
    (let ((priority-string (cdr (assoc priority speechd-priorities))))
      (speechd-send-command "SET" "PRIORITY" priority-string))
    (setq speechd-current-priority priority)))

;;;public
(defun speechd-set-rate (rate)
  (speechd-send-command "SET" "RATE" (speechd-convert-numeric rate)))

;;;public
(defun speechd-set-punctuation (punctuation)
  (let ((punctuation-string (cdr (assoc punctuation speechd-punctuations))))
    (speechd-send-command "SET" "PUNCTUATION" punctuation-string)))

;;;public
(defun speechd-set-capitalization (capitalization)
  (let ((capitalization-string (cdr (assoc capitalization
					   speechd-capitalizations))))
    (speechd-send-command "SET" "CAPITALIZATION" capitalization-string)))


;;;###autoload
(defun* speechd-say (text &key (priority speechd-default-text-priority)
			       (finish t))
  (interactive "sText: ")
  (speechd-set-priority priority)
  (speechd-send-data text)
  (when finish
    (speechd-send-data-end)))

(defun* speechd-say-sound (name &key (priority speechd-default-sound-priority))
  (speechd-set-priority priority)
  (speechd-send-command "SOUND_ICON" name))

(defun* speechd-say-char (char &key (priority speechd-default-char-priority))
  (speechd-set-priority priority)
  (speechd-send-command "CHAR" (char-to-string char)))

  
;;;###autoload
(defun speechd-cancel ()
  (interactive)
  (speechd-send-command "CANCEL" "self"))

;;;###autoload
(defun speechd-stop ()
  (interactive)
  (speechd-send-command "STOP" "self"))

;;;###autoload
(defun speechd-pause ()
  (interactive)
  (setq speechd-paused-p t)
  (speechd-send-command "PAUSE" "self"))

;;;###autoload
(defun speechd-resume (&optional softp)
  (interactive)
  (when (or speechd-paused-p (not softp))
    (speechd-send-command "RESUME" "self")
    (setq speechd-paused-p nil)))


(defconst speechd-maintainer-address "pdm@brailcom.org")

;;;###autoload
(defun speechd-submit-bug-report ()
  (interactive)
  (require 'reporter)
  (if speechd-debug
      (if speechd-debug-info
	  (let ((reporter-prompt-for-summary-p t))
	    (reporter-submit-bug-report speechd-maintainer-address
					speechd-el-version
					'(speechd-debug-info)))
	(y-or-n-p "No debugging info available, really send bug report? "))
    (error
     "Please set speechd-debug to T before invoking the bug.")))


;;; Announce

(provide 'speechd)


;;; speechd.el ends here
