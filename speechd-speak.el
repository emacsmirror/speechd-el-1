;;; speechd-speak.el --- simple speechd-el based Emacs client

;; Copyright (C) 2003, 2004 Brailcom, o.p.s.

;; Author: Milan Zamazal <pdm@brailcom.org>

;; COPYRIGHT NOTICE
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

;;; Commentary:

;; This is an Emacs client to speechd.  Some ideas taken from the Emacspeak
;; package (http://emacspeak.sourceforge.net) by T. V. Raman.

;;; Code:


(eval-when-compile (require 'cl))
(require 'speechd)


;;; User options


(defgroup speechd-speak nil
  "Speechd-el user client customization."
  :group 'speechd)

(defcustom speechd-speak-deleted-char t
  "If non-nil, speak the deleted char, otherwise speak the adjacent char."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-buffer-name 'text
  "If non-nil, speak buffer name on a buffer change.
If the value is the symbol `text', speak the text from the cursor position in
the new buffer to the end of line as well.  If nil, speak the text only, not
the buffer name."
  :type '(choice (const :tag "Buffer name and buffer text" text)
                 (const :tag "Buffer name" t)
                 (const :tag "Buffer text" nil))
  :group 'speechd-speak)

(defcustom speechd-speak-on-minibuffer-exit t
  "If non-nil, always try to speak something when exiting the minibuffer."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-auto-speak-buffers '("*Help*")
  "List of names of other-window buffers to speak if nothing else fits.
If nothing else is to be spoken after a command and a visible window in the
current frame displaying a buffer with a name contained in this list is
changed, the contents of the window buffer is spoken."
  :type '(repeat (string :tag "Buffer name"))
  :group 'speechd-speak)

(defcustom speechd-speak-force-auto-speak-buffers '()
  "List of names of other-window buffers to speak on visible changes.
Like `speechd-speak-auto-speak-buffers' except that the window content is
spoken even when there are other messages to speak."
  :type '(repeat (string :tag "Buffer name"))
  :group 'speechd-speak)

(defcustom speechd-speak-buffer-insertions 'one-line
  "Defines whether insertions in a current buffer should be read automatically.
The value is a symbol and can be from the following set:
- nil means don't speak them
- t means speak them all
- `one-line' means speak only first line of any change
- `whole-buffer' means speak whole buffer if it was changed in any way
Only newly inserted text is read, the option doesn't affect processing of
deleted text.  Also, the option doesn't affect insertions within commands
processed in a different way by speechd-speak or user definitions."
  :type '(choice (const :tag "Never" nil)
                 (const :tag "One-line changes only" one-line)
                 (const :tag "Always" t)
                 (const :tag "Read whole buffer" whole-buffer))
  :group 'speechd-speak)

(defcustom speechd-speak-insertions-in-buffers
  '(" widget-choose" "*Choices*")
  "List of names of buffers, in which insertions are automatically spoken.
See also `speechd-speak-buffer-insertions'."
  :type '(repeat (string :tag "Buffer name"))
  :group 'speechd-speak)

(defcustom speechd-speak-priority-insertions-in-buffers '()
  "List of names of buffers, in which insertions are spoken immediately.
Unlike `speechd-speak-insertions-in-buffers', speaking is not delayed until a
command is completed.
This is typically useful in comint buffers."
  :type '(repeat (string :tag "Buffer name"))
  :group 'speechd-speak)

(defcustom speechd-speak-align-buffer-insertions t
  "If non-nil, read insertions aligned to the beginning of the first word."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-movement-on-insertions 'read-only
  "If t, speak the text around moved cursor even in modified buffers.
If nil, additional cursor movement doesn't cause speaking the text around the
new cursor position in modified buffers.
If `read-only', speak the text around cursor in read-only buffers only."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-read-command-keys t
  "Defines whether command keys should be read after their command.
If t, always read command keys, before the command is performed.
If nil, never read them.
Otherwise it is a list, consisting of one or more of the following symbols:
`movement' -- read the keys if the cursor has moved without any buffer change
`modification' -- read the keys if the buffer was modified without moving the
  cursor
`modification-movement' -- read the keys if the buffer was modified and the
  cursor has moved
and the keys are read after the command is performed."
  :type '(choice (const :tag "Always" t)
                 (const :tag "Never" nil)
                 (set :tag "Sometimes"
                      (const movement)
                      (const modification)
                      (const modification-movement)))
  :group 'speechd-speak)

(defcustom speechd-speak-allow-prompt-commands t
  "If non-nil, allow speechd-speak commands in read-char prompts."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-ignore-command-keys
  '(forward-char backward-char next-line previous-line
    delete-char delete-backward-char backward-delete-char-untabify)
  "List of commands for which their keys are never read."
  :type '(repeat command)
  :group 'speechd-speak)

(defcustom speechd-speak-read-command-name nil
  "If non-nil, read command name instead of command keys."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-by-properties-on-movement t
  "Method of selection of the piece of text to be spoken on movement.
Unless a command provides its speechd feedback in a different way, it speaks
the current line by default if the cursor has moved.  However, if this variable
is t, it speaks the uniform text around the cursor, where \"uniform\"
means the maximum amount of text without any text property change.

If the variable is a list of faces, uniform text is spoken only when the cursor
is on one of the named faces.

Speaking uniform text only works if font-lock-mode is enabled for the current
buffer.

See also `speechd-speak-by-properties-always' and
`speechd-speak-by-properties-never'."
  :type '(choice (const :tag "Always" t)
                 (repeat :tag "On faces" (face :tag "Face")))
  :group 'speechd-speak)

(defcustom speechd-speak-by-properties-always '()
  "List of commands to always speak by properties on movement.
The elements of the list are command names, symbols.

See `speechd-speak-by-properties-on-movement' for more information about
property speaking."
  :type '(repeat
          (function :tag "Command" :match #'(lambda (w val) (commandp val))))
  :group 'speechd-speak)

(defcustom speechd-speak-by-properties-never '()
  "List of commands to never speak by properties on movement.
The elements of the list are command names, symbols.

See `speechd-speak-by-properties-on-movement' for more information about
property speaking."
  :type '(repeat
          (function :tag "Command" :match #'(lambda (w val) (commandp val))))
  :group 'speechd-speak)

(defcustom speechd-speak-faces '()
  "Alist of faces and speaking functions.
Each element of the list is of the form (FACE . ACTION).
If a movement command leaves the cursor on a FACE and there is no explicit
speaking bound to the command, ACTION is invoked.

If ACTION is a string, the string is spoken.
If ACTION is a function, it is invoked, with no arguments."
  :type '(alist
          :key-type face
          :value-type (choice
                       (string :tag "String to speak")
                       (function :tag "Function to call"
                                 :match #'(lambda (w val) (commandp val)))))
  :group 'speechd-speak)

(defcustom speechd-speak-whole-line nil
  "If non-nil, speak whole line on movement by default.
Otherwise speak from the point to the end of line on movement by default."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-message-time-interval 30
  "Minimum time in seconds, after which the same message may be repeated.
If the message is the same as the last one, it is not spoken unless the number
of seconds defined here has passed from the last spoken message."
  :type 'integer
  :group 'speechd-speak)

(defcustom speechd-speak-connections '()
  "Alist mapping major modes and buffers to speechd connection.
By default, there's a single connection to speechd, named \"default\".  This
variable can define special connections for particular major modes and buffers.

Each element of the alist is of the form (MODE-OR-BUFFER . CONNECTION-NAME).

MODE-OR-BUFFER may be, in the order of preference from the highest to the
lowest:

- a list, representing a function call returning non-nil iff the element should
  be applied
- buffer name
- the symbol `:minibuffer', representing minibuffers
- major mode symbol
- nil, representing non-buffer areas, e.g. echo area
- t, representing the default value if nothing else matches

CONNECTION-NAME is an arbitrary non-empty string naming the corresponding
connection.  If connection with such a name doesn't exist, it is automatically
created."
  :type '(alist :key-type
                (choice :tag "Matcher" :value nil
                        (const :tag "Default" t)
                        (const :tag "Non-buffers" nil)
                        (const :tag "Minibuffer" :value :minibuffer)
                        (symbol :tag "Major mode" :value fundamental-mode)
                        (string :tag "Buffer name" :value "")
                        (restricted-sexp :tag "Function call"
                                         :match-alternatives (listp)))
                :value-type (string :tag "Connection name"))
  :group 'speechd-speak)

(defcustom speechd-speak-signal-events
  '(empty whitespace beginning-of-line end-of-line start finish minibuffer
          message)
  "List of symbolic names of events to signal with a standard sound icon.
The following actions are supported: `empty', `beginning-of-line',
`end-of-line', `start', `finish', `minibuffer', `message'."
  :type '(set (const empty)
              (const whitespace)
              (const beginning-of-line)
              (const end-of-line)
              (const start)
              (const finish)
              (const minibuffer)
              (const message))
  :group 'speechd-speak)

(defcustom speechd-speak-input-method-languages '()
  "Alist mapping input methods to languages.
Each of the alist element is of the form (INPUT-METHOD-NAME . LANGUAGE), where
INPUT-METHOD-NAME is a string naming the input method and LANGUAGE is an ISO
language code accepted by SSIP.
If the current input method is present in the alist, the corresponding language
is selected unless overridden by another setting."
  :type '(alist :key-type (string :tag "Input method")
                :value-type (string :tag "Language code"))
  :group 'speechd)

(defcustom speechd-speak-in-debugger t
  "If nil, speechd-speak functions won't speak in Elisp debuggers.
This may be useful when debugging speechd-el itself."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-prefix "\C-e"
  "Default prefix key used for speechd-speak commands."
  :set #'(lambda (name value)
	   (set-default name value)
           (speechd-speak--build-mode-map))
  :initialize 'custom-initialize-default
  :type 'sexp
  :group 'speechd-speak)


;;; Internal constants


(defvar speechd-speak--event-mapping
  '((empty . "*empty-text")
    (whitespace . "*whitespace")
    (beginning-of-line . "*beginning-of-line")
    (end-of-line . "*end-of-line")
    (start . "*start")
    (finish . "*finish")
    (minibuffer . "*prompt")
    (message . "*message")))
(defun speechd-speak--event-mapping (event)
  (cdr (assq event speechd-speak--event-mapping)))

(defconst speechd-speak--c-buffer-name "*Completions*")


;;; Debugging support


(defvar speechd-speak--debug ())
(defvar speechd-speak--max-debug-length 12)

(defun speechd-speak--debug (info)
  (setq speechd-speak--debug
        (cons info
              (if (>= (length speechd-speak--debug)
                      speechd-speak--max-debug-length)
                  (butlast speechd-speak--debug)
                speechd-speak--debug))))


;;; Control functions


(defvar speechd-speak--predefined-rates
  '((1 . -100)
    (2 . -75)
    (3 . -50)
    (4 . -25)
    (5 . 0)
    (6 . 25)
    (7 . 50)
    (8 . 75)
    (9 . 100)))
(defun speechd-speak-set-predefined-rate (level)
  "Set speech rate to one of nine predefined levels.
Level 1 is the slowest, level 9 is the fastest."
  (interactive "nSpeech rate level (1-9): ")
  (setq level (min (max level 1) 9))
  (let ((rate (cdr (assoc level speechd-speak--predefined-rates))))
    (speechd-set-rate rate)
    (message "Speech rate set to %d" rate)))

(defvar speechd-speak--char-to-number
  '((?1 . 1) (?2 . 2) (?3 . 3) (?4 . 4) (?5 . 5)
    (?6 . 6) (?7 . 7) (?8 . 8) (?9 . 9)))
(defun speechd-speak-key-set-predefined-rate ()
  "Set speech rate to one of nine predefined levels via a key binding.
Level 1 is the slowest, level 9 is the fastest."
  (interactive)
  (let ((level (cdr (assoc last-input-char speechd-speak--char-to-number))))
    (when level
      (speechd-speak-set-predefined-rate level))))


;;; Supporting functions and options


(defun speechd-speak--name (&rest args)
  (intern (mapconcat #'symbol-name args "-")))

(defvar speechd-speak-mode nil)   ; forward definition to make everything happy

(defvar speechd-speak--started nil)

(defvar speechd-speak--last-buffer-mode t)
(defvar speechd-speak--last-connection-name nil)
(defvar speechd-speak--last-connections nil)
(defvar speechd-speak--default-connection-name "default")
(defvar speechd-speak--special-area nil)
(defvar speechd-speak--emulate-minibuffer nil)
(defvar speechd-speak--client-name-set nil)
(make-variable-buffer-local 'speechd-speak--client-name-set)
(defun speechd-speak--connection-name ()
  (let ((buffer-mode (if speechd-speak--special-area
                         nil
                       (cons major-mode (buffer-name)))))
    (cond
     (speechd-speak--client-name-set 
      speechd-client-name)
     ((and (not speechd-speak--client-name-set)
           (eq speechd-speak-connections speechd-speak--last-connections)
           (equal buffer-mode speechd-speak--last-buffer-mode))
      speechd-speak--last-connection-name)
     (t
      (setq speechd-speak--last-buffer-mode buffer-mode
            speechd-speak--last-connections speechd-speak-connections
            speechd-speak--last-connection-name
            (if buffer-mode
                (or (cdr (or
                          ;; minibuffer-like prompts
                          (and speechd-speak--emulate-minibuffer
                               (assoc :minibuffer speechd-speak-connections))
                          ;; functional test
                          (let ((specs speechd-speak-connections)
                                (result nil))
                            (while (and (not result) specs)
                              (if (and (consp (caar specs))
                                       (eval (caar specs)))
                                  (setq result (car specs))
                                (setq specs (cdr specs))))
                            result)
                          ;; buffer name
                          (assoc (buffer-name) speechd-speak-connections)
                          ;; minibuffer
                          (and (speechd-speak--in-minibuffer-p)
                               (assoc :minibuffer speechd-speak-connections))
                          ;; major mode
                          (assq major-mode speechd-speak-connections)
                          ;; default
                          (assq t speechd-speak-connections)))
                    speechd-speak--default-connection-name)
              (or (cdr (assq nil speechd-speak-connections))
                  speechd-speak--default-connection-name)))
      (set (make-local-variable 'speechd-client-name)
           speechd-speak--last-connection-name)))))

(defun speechd-speak--in-debugger ()
  (and (not speechd-speak-in-debugger)
       (or (eq major-mode 'debugger-mode)
           (and (boundp 'edebug-active) edebug-active))))

(defmacro speechd-speak--maybe-speak* (&rest body)
  `(when (and speechd-speak-mode
              (not (speechd-speak--in-debugger)))
     ,@body))

(defmacro speechd-speak--maybe-speak (&rest body)
  `(speechd-speak--maybe-speak*
     (let ((speechd-client-name (speechd-speak--connection-name))
           (speechd-language
            (or (and speechd-speak-input-method-languages
                     current-input-method
                     (cdr (assoc current-input-method
                                 speechd-speak-input-method-languages)))
                speechd-language)))
       ,@body)))

(defmacro speechd-speak--interactive (&rest body)
  `(let ((speechd-speak-mode (or (interactive-p)
                                 (and speechd-speak-mode
                                      (not (speechd-speak--in-debugger)))))
         (speechd-default-text-priority (if (interactive-p)
                                            'message
                                          speechd-default-text-priority)))
     ,@body))

(defun speechd-speak--text (text &rest args)
  (speechd-speak--maybe-speak
   ;; TODO: skip invisible text
   ;; TODO: replace repeating patterns
   ;; TODO: handle selective display
   (apply #'speechd-say-text text args)))

(defun speechd-speak--char (&rest args)
  (speechd-speak--maybe-speak
   (apply #'speechd-say-char args)))

(defun speechd-speak--key (&rest args)
  (speechd-speak--maybe-speak
   (apply #'speechd-say-key args)))

(defun speechd-speak--sound (&rest args)
  (speechd-speak--maybe-speak
   (apply #'speechd-say-sound args)))

(defvar speechd-speak--last-report "")

(defun speechd-speak-report (message &rest args)
  "Speak text or sound icon MESSAGE.
MESSAGE is a string; if it starts with the `*' character, the asterisk is
stripped of the MESSAGE and the rest of MESSAGE names a sound icon to play.
Otherwise MESSAGE is simply a text to speak.

ARGS are appended to the arguments of the corresponding speaking
function (`speechd-say-text' or `speechd-say-sound') without change after the
message argument."
  (speechd-speak--maybe-speak
   (unless (or (string= message "")
               (string= message speechd-speak--last-report))
     (if (string= (substring message 0 (min 1 (length message))) "*")
         (apply #'speechd-say-sound (substring message 1) args)
       (apply #'speechd-say-text message args))
     (setq speechd-speak--last-report message))))

(defun speechd-speak--signal (event &rest args)
  (when (memq event speechd-speak-signal-events)
    (apply #'speechd-speak-report
           (speechd-speak--event-mapping event)
           args)
    t))

(defun speechd-speak-read-char (&optional char)
  "Read character CHAR.
If CHAR is nil, speak the character just after current point."
  (interactive)
  (speechd-speak--interactive
   (speechd-speak--char (or char (following-char)))))

(defun speechd-speak-read-region (&optional beg end empty-text)
  "Read region of the current buffer between BEG and END.
If BEG is nil, current mark is used instead.
If END is nil, current point is used instead.
EMPTY-TEXT is a text to say if the region is empty; if nil, empty text icon is
played."
  (interactive "r")
  (speechd-speak--interactive
   (let ((text (buffer-substring (or beg (mark)) (or end (point)))))
     (cond
      ((string= text "")
       (speechd-speak-report
        (or empty-text
            (speechd-speak--event-mapping 'empty)
            "")
        :priority speechd-default-text-priority))
      ((save-match-data (string-match "\\`[ \t]+\\'" text))
       (speechd-speak-report (or (speechd-speak--event-mapping 'whitespace) "")
                             :priority speechd-default-text-priority))
      (t
       (speechd-speak--text text))))))

(defun speechd-speak-read-line (&optional rest-only)
  "Speak current line.
If the prefix argument is given, speak the line only from the current point
to the end of the line."
  (interactive "P")
  (speechd-speak--interactive
   (speechd-speak-read-region (if rest-only (point) (line-beginning-position))
                              (line-end-position)
                              (when (speechd-speak--in-minibuffer-p) ""))))

(defun speechd-speak-read-next-line ()
  "Speak the next line after the current line.
If there is no such line, play the empty text icon."
  (interactive)
  (speechd-speak--interactive
   (save-excursion
     (if (= (forward-line 1) 0)
         (speechd-speak-read-line)
       (speechd-speak-report (speechd-speak--event-mapping 'empty))))))

(defun speechd-speak-read-previous-line ()
  "Speak the previous line before the current line.
If there is no such line, play the empty text icon."
  (interactive)
  (speechd-speak--interactive
   (save-excursion
     (if (= (forward-line -1) 0)
         (speechd-speak-read-line)
       (speechd-speak-report (speechd-speak--event-mapping 'empty))))))

(defun speechd-speak-read-buffer (&optional buffer)
  "Read BUFFER.
If BUFFER is nil, read current buffer."
  (interactive)
  (speechd-speak--interactive
   (save-excursion
     (when buffer
       (set-buffer buffer))
     (speechd-speak-read-region (point-min) (point-max)))))

(defun speechd-speak-read-rest-of-buffer ()
  "Read current buffer from the current point to the end of the buffer."
  (interactive)
  (speechd-speak--interactive
   (speechd-speak-read-region (point) (point-max))))

(defun speechd-speak-read-rectangle (beg end)
  "Read text in the region-rectangle."
  (interactive "r")
  (speechd-speak--interactive
   (speechd-speak--text
    (mapconcat #'identity (extract-rectangle beg end) "\n"))))

(defun speechd-speak-read-other-window ()
  "Read buffer of the last recently used window."
  (interactive)
  (speechd-speak--interactive
   (speechd-speak-read-buffer (window-buffer (get-lru-window)))))

(defun speechd-speak-read-mode-line ()
  "Read mode line.
This function works only in Emacs 21.4 or higher."
  (interactive)
  (when (fboundp 'format-mode-line)
    (speechd-speak--interactive
     (speechd-speak--text (format-mode-line)))))

(defun speechd-speak--window-contents ()
  (sit-for 0)                           ; to update window start and end
  (speechd-speak-read-region (window-start) (window-end)))

(defun speechd-speak--uniform-text-around-point ()
  (let ((beg (speechd-speak--previous-property-change (1+ (point))))
	(end (speechd-speak--next-property-change (point))))
    (speechd-speak-read-region beg end)))

(defun speechd-speak--speak-piece (start)
  (let ((point (point)))
    (if (> (count-lines start point) 1)
	(speechd-speak-read-line)
      (speechd-speak-read-region start point))))

(defun speechd-speak--speak-current-column ()
  (speechd-speak--text (format "Column %d" (current-column))))

(defmacro speechd-speak--def-speak-object (type)
  (let* ((function-name (speechd-speak--name 'speechd-speak-read type))
	 (backward-function (speechd-speak--name 'backward type))
	 (forward-function (speechd-speak--name 'forward type)))
    `(defun ,function-name ()
       ,(format "Speak current %s." type)
       (interactive)
       (speechd-speak--interactive
        (save-excursion
          (let* ((point (point))
                 (end (progn (,forward-function 1) (point)))
                 (beg (progn (,backward-function 1) (point))))
            (when (<= (progn (,forward-function 1) (point)) point)
              (setq beg end))
            (speechd-speak-read-region beg end)))))))

(speechd-speak--def-speak-object word)
(speechd-speak--def-speak-object sentence)
(speechd-speak--def-speak-object paragraph)
(speechd-speak--def-speak-object page)
(speechd-speak--def-speak-object sexp)

(defstruct speechd-speak--command-info-struct
  marker
  modified
  (changes '())
  (change-end nil)
  (other-changes '())
  other-changes-buffer
  other-window
  other-buffer-modified
  completion-buffer-modified
  minibuffer-contents
  info)

(defmacro speechd-speak--cinfo (slot)
  `(,(speechd-speak--name 'speechd-speak--command-info-struct slot)
    info))

(defun speechd-speak--command-info-struct-buffer (info)
  (let ((marker (speechd-speak--cinfo marker)))
    (and marker (marker-buffer marker))))

(defun speechd-speak--command-info-struct-point (info)
  (let ((marker (speechd-speak--cinfo marker)))
    (and marker (marker-position marker))))

(defvar speechd-speak--command-start-info (make-vector 5 nil))

(defmacro speechd-speak--with-minibuffer-depth (&rest body)
  `(let ((depth (minibuffer-depth)))
     (when (>= depth (length speechd-speak--command-start-info))
       (setq speechd-speak--command-start-info
	     (vconcat speechd-speak--command-start-info
		      (make-vector
		       (- (1+ depth)
			  (length speechd-speak--command-start-info))
		       nil))))
     ,@body))

(defun speechd-speak--in-minibuffer-p ()
  (window-minibuffer-p (selected-window)))

(defun speechd-speak--command-start-info ()
  (speechd-speak--with-minibuffer-depth
    (aref speechd-speak--command-start-info depth)))

(defun speechd-speak--set-command-start-info (&optional reset)
  (speechd-speak--with-minibuffer-depth
    (aset speechd-speak--command-start-info depth
	  (if reset
	      nil
	    (ignore-errors
	      (let ((other-window (next-window)))
		(make-speechd-speak--command-info-struct
                 :marker (point-marker)
		 :modified (buffer-modified-tick)
		 :other-window other-window
		 :other-buffer-modified
                   (and other-window
                        (buffer-modified-tick (window-buffer other-window)))
                 :completion-buffer-modified
                   (let ((buffer (get-buffer speechd-speak--c-buffer-name)))
                     (and buffer (buffer-modified-tick buffer)))
                 :minibuffer-contents
                   (if (speechd-speak--in-minibuffer-p)
                       (minibuffer-contents)
                     'unset)
                 :info (speechd-speak--current-info)
                )))))))

(defun speechd-speak--reset-command-start-info ()
  (speechd-speak--set-command-start-info t))

(defmacro speechd-speak--with-command-start-info (&rest body)
  `(let ((info (speechd-speak--command-start-info)))
     (when info
       ,@body)))

(defmacro speechd-speak--defadvice (function class &rest body)
  (let* ((function* function)
         (fname (if (listp function*) (first function*) function*))
         (aname (if (listp function*) 'speechd-speak-user 'speechd-speak)))
    `(defadvice ,fname (,class ,aname activate preactivate compile)
       (if (not speechd-speak--started)
           ,(when (eq class 'around) 'ad-do-it)
         ,@body))))

(defmacro speechd-speak--report (feedback &rest args)
  (if (stringp feedback)
      `(speechd-speak-report ,feedback ,@args)
    feedback))

(defmacro speechd-speak-function-feedback (function position feedback)
  "Report FEEDBACK on each invocation of FUNCTION.
FUNCTION is a function name.
POSITION may be one of the symbols `before' (the feedback is run before the
function is invoked) or `after' (the feedback is run after the function is
invoked.
FEEDBACK is a string to be given as the argument of the `speechd-speak-report'
function or a sexp to be evaluated."
  `(speechd-speak--defadvice ,(list function) ,position
     (speechd-speak--report ,feedback :priority 'message)))

(defmacro speechd-speak-command-feedback (function position feedback)
  "Report FEEDBACK on each invocation of FUNCTION.
The arguments are the same as in `speechd-speak-function-feedback'.
Unlike `speechd-speak-function-feedback', the feedback is reported only when
FUNCTION is invoked interactively."
  `(speechd-speak--defadvice ,(list function) ,position
     (when (interactive-p)
       (speechd-speak--report ,feedback :priority 'message))))

(defmacro speechd-speak--command-feedback (commands position &rest body)
  (let ((commands* (if (listp commands) commands (list commands)))
	(position* position)
	(body* `(progn (speechd-speak--reset-command-start-info) ,@body)))
    `(progn
       ,@(mapcar #'(lambda (command)
		     `(speechd-speak--defadvice ,command ,position*
			,(if (eq position* 'around)
			     `(if (interactive-p)
				  ,body*
				ad-do-it)
			   `(when (interactive-p)
			      ,body*))))
		 commands*))))

(defmacro speechd-speak--command-feedback-region (commands)
  `(speechd-speak--command-feedback ,commands around
     (let ((start (point)))
       (prog1 ad-do-it
         (speechd-speak--speak-piece start)))))

(defun* speechd-speak--next-property-change (&optional (point (point))
                                                       (limit (point-max)))
  (next-char-property-change point limit))

(defun* speechd-speak--previous-property-change (&optional (point (point))
                                                           (limit (point-min)))
  (previous-char-property-change point limit))

(defun speechd-speak--new-connection-name ()
  (let* ((i 0)
         (base-name (buffer-name))
         (name base-name)
         (connections (speechd-connection-names)))
    (while (member name connections)
      (setq name (format "%s%d" base-name (incf i))))
    name))

(defun speechd-speak-new-connection (&optional arg)
  "Open a separate connection for the current buffer.
If the optional prefix argument is used, let the user choose from the existing
connections, otherwise create completely new connection."
  (interactive "P")
  (let ((name (if arg
                  (completing-read
                   "Connection name: "
                   (mapcar #'(lambda (c) (cons c c))
                           (speechd-connection-names)))
                (read-string "Connection name: "
                             (speechd-speak--new-connection-name)))))
    (set (make-local-variable 'speechd-client-name) name)
    (setq speechd-speak--client-name-set t)))


;;; Basic speaking


;; These two simply don't work in Emacs 21.3 when invoked via key binding.
;; They're called directly in Emacs 21, to speed them up; no advice is invoked
;; in such a case.

;; (speechd-speak--command-feedback (self-insert-command) after
;;   (speechd-speak--char (preceding-char)))

;; (speechd-speak--command-feedback (forward-char backward-char) after
;;   (speechd-speak-read-char))

(speechd-speak--command-feedback (next-line previous-line) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (forward-word backward-word) after
  (speechd-speak-read-word))

(speechd-speak--command-feedback (forward-sentence backward-sentence) after
  (speechd-speak-read-sentence))

(speechd-speak--command-feedback (forward-paragraph backward-paragraph) after
  (speechd-speak-read-paragraph))

(speechd-speak--command-feedback (forward-page backward-page) after
  (speechd-speak-read-page))

(speechd-speak--command-feedback (scroll-up scroll-down) after
  (speechd-speak--window-contents))

(speechd-speak--command-feedback-region
 (backward-sexp forward-sexp forward-list backward-list up-list
  backward-up-list down-list))

(speechd-speak--command-feedback (upcase-word downcase-word capitalize-word)
				 after
  (speechd-speak-read-word))

(speechd-speak--command-feedback (delete-backward-char backward-delete-char
				  backward-delete-char-untabify)
				 around
  (when speechd-speak-deleted-char
    (speechd-speak-read-char (preceding-char)))
  (prog1 ad-do-it
    (unless speechd-speak-deleted-char
      (speechd-speak-read-char (preceding-char)))))

(speechd-speak--command-feedback (delete-char) around
  (when speechd-speak-deleted-char
    (speechd-speak-read-char (following-char)))
  (prog1 ad-do-it
    (unless speechd-speak-deleted-char
      (speechd-speak-read-char (following-char)))))

(speechd-speak--command-feedback (quoted-insert) after
  (speechd-speak-read-char (preceding-char)))

(speechd-speak--command-feedback (newline newline-and-indent) before
  (speechd-speak-read-line))

(speechd-speak--command-feedback (undo) after
  (speechd-speak-read-line))

(defmacro speechd-speak--unhide-message (function)
  ;; If `message' is invoked within a built-in function, there's no way to get
  ;; notified automatically about it.  So we have to wrap the built-in
  ;; functions displaying messages to check for the otherwise hidden messages.
  `(speechd-speak--defadvice ,function after
     (speechd-speak--current-message)))

(speechd-speak--unhide-message write-region)


;;; Killing and yanking


(speechd-speak--command-feedback (kill-word) before
  (speechd-speak-read-word))

(speechd-speak--command-feedback (backward-kill-word) before
  (save-excursion
    (forward-word -1)
    (speechd-speak-read-word)))

(speechd-speak--command-feedback (kill-line) before
  (speechd-speak-read-line))

(speechd-speak--command-feedback (kill-sexp) before
  (speechd-speak-read-sexp))

(speechd-speak--command-feedback (kill-sentence) before
  (speechd-speak-read-sentence))

(speechd-speak--command-feedback (zap-to-char) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (yank yank-pop) after
  (speechd-speak-read-region))

(speechd-speak--command-feedback (kill-region completion-kill-region) around
  (let ((nlines (count-lines (region-beginning) (region-end))))
    (prog1 ad-do-it
      (speechd-speak--maybe-speak*
        (message "Killed region containing %s lines" nlines)))))


;;; Messages


(defvar speechd-speak--last-message "")
(defvar speechd-speak--last-spoken-message "")
(defvar speechd-speak--last-spoken-message-time 0)

(defun speechd-speak-last-message ()
  "Speak last message from the echo area."
  (interactive)
  (speechd-speak--interactive
   (let ((speechd-speak-input-method-languages nil)
         (speechd-language "en"))
     (speechd-speak--text speechd-speak--last-message))))

(defun speechd-speak--read-message (message)
  (let ((speechd-speak--special-area t))
    (speechd-speak--maybe-speak         ; necessary to select proper connection
      (speechd-block '(spelling-mode nil message-priority progress)
        (speechd-speak--signal 'message)
        (speechd-speak--minibuffer-prompt message)))))

(defun speechd-speak--message (message &optional reset-last-spoken)
  (speechd-speak--maybe-speak*
   (when (and message
              (or (not (string= message speechd-speak--last-spoken-message))
                  (>= (- (float-time) speechd-speak--last-spoken-message-time)
                      speechd-speak-message-time-interval)))
     (let* ((oldlen (length speechd-speak--last-spoken-message))
            (len (length message))
            ;; The following tries to handle answers to y-or-n questions, e.g.
            ;; "Do something? (y or n) y", which are reported as a single
            ;; string, including the prompt.
            (message* (if (and (= (- len oldlen) 1)
                               (save-match-data
                                 (string-match "\?.*) .$" message))
                               (string= (substring message 0 oldlen)
                                        speechd-speak--last-spoken-message))
                          (substring message oldlen)
                        message)))
       (setq speechd-speak--last-message message
             speechd-speak--last-spoken-message message
             speechd-speak--last-spoken-message-time (float-time))
       (speechd-speak--read-message message*)))
   (when reset-last-spoken
     (setq speechd-speak--last-spoken-message ""))))

(defun speechd-speak--current-message (&optional reset-last-spoken)
  (speechd-speak--message (current-message) reset-last-spoken))

(speechd-speak--defadvice message after
  (speechd-speak--current-message))


;;; Minibuffer


(defvar speechd-speak--minibuffer-inherited-language nil)

(speechd-speak--defadvice read-from-minibuffer around
  (let ((speechd-speak--minibuffer-inherited-language
         (and (ad-get-arg 6) speechd-language)))
    ad-do-it))

(defun speechd-speak--prompt (prompt)
  (speechd-speak--text prompt :priority 'message))

(defun speechd-speak--speak-minibuffer-prompt ()
  (let ((speechd-language "en")
        (speechd-speak-input-method-languages nil))
    (speechd-speak--prompt (minibuffer-prompt)))
  (speechd-speak--prompt (minibuffer-contents)))

(defun speechd-speak--minibuffer-setup-hook ()
  (set (make-local-variable 'speechd-language)
       speechd-speak--minibuffer-inherited-language)
  (speechd-speak--enforce-speak-mode)
  (speechd-speak--with-command-start-info
   (setf (speechd-speak--cinfo minibuffer-contents) (minibuffer-contents)))
  (speechd-speak--signal 'minibuffer :priority 'message)
  (speechd-speak--speak-minibuffer-prompt))

(defun speechd-speak--minibuffer-exit-hook ()
  (speechd-speak--with-command-start-info
   (setf (speechd-speak--cinfo minibuffer-contents) 'unset)))

(defun speechd-speak--speak-minibuffer ()
  (speechd-speak--text (minibuffer-contents)))

(defvar speechd-speak--last-other-changes "")
(defvar speechd-speak--last-other-changes-buffer nil)

(defun speechd-speak--read-changes (text buffer &rest speak-args)
  (with-current-buffer (or (get-buffer buffer) (current-buffer))
    (apply #'speechd-speak--text text speak-args)))

(defun speechd-speak--read-other-changes ()
  (speechd-speak--with-command-start-info
   (when (speechd-speak--cinfo other-changes)
     (let ((speechd-speak--special-area nil)
           (buffer (get-buffer (speechd-speak--cinfo other-changes-buffer)))
           (text (mapconcat
                  #'identity
                  (nreverse (speechd-speak--cinfo other-changes)) "")))
       (setq speechd-speak--last-other-changes text
             speechd-speak--last-other-changes-buffer buffer)
       (speechd-speak--read-changes text buffer :priority 'message))
     (setf (speechd-speak--cinfo other-changes) '()))))

(defun speechd-speak-last-insertions ()
  "Speak last insertions read in buffers with automatic insertion speaking.
This command applies to buffers defined in
`speechd-speak-insertions-in-buffers' and
`speechd-speak-priority-insertions-in-buffers'."
  (interactive)
  (speechd-speak--interactive
   (let ((speechd-speak--special-area nil))
     (speechd-speak--read-changes speechd-speak--last-other-changes
                                  speechd-speak--last-other-changes-buffer))))

(defun speechd-speak--minibuffer-prompt (prompt &rest args)
  (speechd-speak--read-other-changes)
  (let ((speechd-language "en")
        (speechd-speak-input-method-languages nil))
    (apply #'speechd-speak--text prompt args)))
                          
(speechd-speak--command-feedback minibuffer-message after
  (speechd-speak--minibuffer-prompt (ad-get-arg 0) :priority 'notification))

;; Some built-in functions, reading a single character answer, prompt in the
;; echo area.  They don't invoke minibuffer-setup-hook and may put other
;; messages to the echo area by invoking other built-in functions.  There's no
;; easy way to catch the prompts and messages, the only way to deal with this
;; is to use idle timers.
(defvar speechd-speak--message-timer nil)
(defun speechd-speak--message-timer ()
  (let ((message (current-message)))
    (when (and cursor-in-echo-area
               (not (string= message speechd-speak--last-spoken-message)))
      (let ((speechd-speak--emulate-minibuffer t))
        (speechd-speak--minibuffer-prompt message))
      (setq speechd-speak--last-spoken-message message))))

;; The following functions don't invoke `minibuffer-setup-hook' and don't put
;; the cursor into the echo area.  Sigh.
(speechd-speak--defadvice read-key-sequence before
  (let ((prompt (ad-get-arg 0))
        (speechd-speak--emulate-minibuffer t))
    (when prompt
      (speechd-speak--minibuffer-prompt prompt :priority 'message))))
(speechd-speak--defadvice read-event before
  (let ((prompt (ad-get-arg 0)))
    (when prompt
      (let ((speechd-speak--emulate-minibuffer t)
            (speechd-language (if (ad-get-arg 1) speechd-language "en")))
        (speechd-speak--minibuffer-prompt prompt :priority 'message)))))


;;; Repitition in character reading commands


(defvar speechd-speak-read-char-keymap (make-sparse-keymap)
  "Keymap used by speechd-el for repititions during reading characters.
Only single characters are allowed in the keymap.")
(define-key speechd-speak-read-char-keymap
  "\C-a" 'speechd-speak-last-insertions)
(define-key speechd-speak-read-char-keymap
  "\C-e" 'speechd-speak-last-message)

(speechd-speak--defadvice read-char-exclusive around
  (if speechd-speak-allow-prompt-commands
      (let ((char nil))
        (while (not char)
          (setq char ad-do-it)
          (let ((command (lookup-key speechd-speak-read-char-keymap
                                     (vector char))))
            (when command
              (setq char nil)
              (call-interactively command))))
        char)
    ad-do-it))


;;; Commands


(defun speechd-speak--command-keys (&optional priority)
  (speechd-speak--maybe-speak
    (speechd-block (if priority `(message-priority ,priority) ())
      (let* ((keys (this-command-keys-vector))
             (i 0)
             (len (length keys)))
        (while (< i len)
          (let ((key (aref keys i)))
            (speechd-say-key key)
            (let ((m-x-chars (and (equal (event-basic-type key) ?x)
                                  (equal (event-modifiers key) '(meta))
                                  (let ((j (1+ i))
                                        (chars '("")))
                                    (while (and chars (< j len))
                                      (let* ((k (aref keys j))
                                             (km (event-modifiers k))
                                             (kb (event-basic-type k)))
                                        (unless (or (not (numberp kb))
                                                    (< kb 32) (>= kb 128)
                                                    km)
                                          (push (char-to-string kb) chars)))
                                      (incf j))
                                    (nreverse chars)))))
              (if m-x-chars
                  (progn
                    (speechd-speak--text (apply #'concat m-x-chars))
                    (setq i len))
                (incf i)))))))))

(defun speechd-speak--add-command-text (info beg end)
  (let ((last (first (speechd-speak--cinfo changes)))
        (last-end (speechd-speak--cinfo change-end))
        (text (speechd-speak--buffer-substring beg end)))
    (setf (speechd-speak--cinfo change-end) end)
    (cond
     ((and last (string= last text))
      ;; nothing to do
      )
     ((and last-end (= last-end beg))
      (rplaca (speechd-speak--cinfo changes)
              (concat last (buffer-substring beg end))))
     (t
      (push text (speechd-speak--cinfo changes))))))

(defun speechd-speak--buffer-substring (beg end)
  (buffer-substring
   (if (and speechd-speak-align-buffer-insertions
            (not (eq this-command 'self-insert-command)))
       (save-excursion
         (goto-char beg)
         (when (save-match-data
                 (and (looking-at "\\w")
                      (not (looking-at "\\<"))))
           (backward-word 1))
         (point))
     beg)
   end))

(defun speechd-speak--minibuffer-update-report (info old new)
  (speechd-speak--add-command-text
   info
   (+ (minibuffer-prompt-end)
      (if (and (<= (length old) (length new))
               (string= old (substring new 0 (length old))))
          (length old)
        0))
   (point-max)))

(defun speechd-speak--minibuffer-update (beg end len)
  (speechd-speak--with-command-start-info
   (let ((old-content (speechd-speak--cinfo minibuffer-contents))
         (new-content (minibuffer-contents)))
     (unless (or (eq old-content 'unset)
                 (string= old-content new-content))
       (setf (speechd-speak--cinfo minibuffer-contents) new-content)
       (speechd-speak--minibuffer-update-report
        info old-content new-content)))))

(defun speechd-speak--read-buffer-change (buffer-name text)
  (with-current-buffer (or (get-buffer buffer-name)
                           (get-buffer "*scratch*")
                           (current-buffer))
    (speechd-speak--text text :priority 'message)))

(defun speechd-speak--after-change-hook (beg end len)
  (speechd-speak--enforce-speak-mode)
  (speechd-speak--with-command-start-info
    (unless (= beg end)
      (cond
       ((or (member (buffer-name)
                    speechd-speak-priority-insertions-in-buffers)
            ;; Asynchronous buffer changes
            (and (not this-command)
                 (member (buffer-name) speechd-speak-insertions-in-buffers)))
        (speechd-speak--read-buffer-change
         (buffer-name) (speechd-speak--buffer-substring beg end)))
       ((not this-command)
        ;; Asynchronous buffer change -- we are not interested in it by
        ;; default
        nil)
       ((member (buffer-name) speechd-speak-insertions-in-buffers)
        (setf (speechd-speak--cinfo other-changes-buffer) (buffer-name))
        (push (speechd-speak--buffer-substring beg end)
              (speechd-speak--cinfo other-changes)))
       ((eq (current-buffer) (speechd-speak--cinfo buffer))
        (if (speechd-speak--in-minibuffer-p)
            (progn
              (speechd-speak--read-other-changes)
              (speechd-speak--minibuffer-update beg end len))
          (speechd-speak--add-command-text info beg end)))))))

(defconst speechd-speak--dont-cancel-on-commands
  '(speechd-speak speechd-unspeak speechd-cancel speechd-stop speechd-pause
    speechd-resume))

(defun speechd-speak--pre-command-hook ()
  (condition-case err
      (progn
        (unless (memq this-command speechd-speak--dont-cancel-on-commands)
          (speechd-cancel 1))
        (speechd-speak--set-command-start-info)
        (setq speechd-speak--last-report "")
        (when speechd-speak-spell-command
          (speechd-speak-spell-mode 1))
        (speechd-speak--maybe-speak
          (when (and (eq speechd-speak-read-command-keys t)
                     (not (memq this-command
                                speechd-speak-ignore-command-keys)))
            (speechd-speak--command-keys
             (if (eq this-command 'self-insert-command)
                 'notification 'message)))
          ;; Some parameters of interactive commands don't set up the
          ;; minibuffer, so we have to speak the prompt in a special way.
          (let ((interactive (and (commandp this-command)
                                  (cadr (interactive-form this-command)))))
            (save-match-data
              (when (and (stringp interactive)
                         (string-match "^[@*]*\\([eipPmnr]\n\\)*[ckK]\\(.+\\)"
                                       interactive))
                (speechd-speak--prompt (match-string 2 interactive)))))))
    (error
     (speechd-speak--debug (list 'pre-command-hook-error err))
     (apply #'error (cdr err))))
  (add-hook 'pre-command-hook 'speechd-speak--pre-command-hook))

(defmacro speechd-speak--post-defun (name shy new-state guard &rest body)
  (let* ((name (speechd-speak--name 'speechd-speak--post-read name))
         (state-condition (case shy
                            ((t) `(eq state nil))
                            (sometimes `(not (eq state t)))
                            (t t))))
    `(defun ,name (state buffer-changed buffer-modified point-moved
                   in-minibuffer other-buffer)
       (if (and ,state-condition
                ,guard)
           (progn
             ,@body
             ,new-state)
         state))))

(speechd-speak--post-defun special-commands t t
  ;; Speak commands that can't speak in a regular way
  (memq this-command '(forward-char backward-char))
  (speechd-block `(message-priority ,speechd-default-char-priority)
    (cond
     ((looking-at "^")
      (speechd-speak--signal 'beginning-of-line)
      (speechd-speak-read-char))
     ((and (looking-at "$")
           (memq 'end-of-line speechd-speak-signal-events))
      (speechd-speak-report (speechd-speak--event-mapping 'end-of-line)))
     (t
      (speechd-speak-read-char)))))

(speechd-speak--post-defun buffer-switch t t
  ;; Any buffer switch
  buffer-changed
  (when speechd-speak-buffer-name
    (speechd-speak--text (buffer-name) :priority 'message))
  (when (memq speechd-speak-buffer-name '(text nil))
    (speechd-speak-read-line t)))

(speechd-speak--post-defun command-keys t nil
  ;; Keys that invoked the command
  (and (not (memq this-command speechd-speak-ignore-command-keys))
       (not (eq this-command 'self-insert-command))
       (not (eq speechd-speak-read-command-keys t))
       (or (and buffer-modified point-moved
                (memq 'modification-movement speechd-speak-read-command-keys))
           (and buffer-modified (not point-moved)
                (memq 'modification speechd-speak-read-command-keys))
           (and (not buffer-modified) point-moved
                (memq 'movement speechd-speak-read-command-keys))))
  (if speechd-speak-read-command-name
      (speechd-speak--text (symbol-name this-command) :priority 'message)
    (speechd-speak--command-keys 'message)))

(speechd-speak--post-defun info-change t nil
  ;; General status information has changed
  (not (equalp (speechd-speak--cinfo info) (speechd-speak--current-info)))
  (let ((old-info (speechd-speak--cinfo info))
        (new-info (speechd-speak--current-info)))
    (dolist (item new-info)
      (let* ((id (car item))
             (new (cdr item))
             (old (cdr (assq id old-info))))
        (when (and (memq id speechd-speak-state-changes)
                   (not (equalp old new)))
          (funcall (speechd-speak--name 'speechd-speak--update id)
                   old new))))))

(speechd-speak--post-defun speaking-commands nil t
  ;; Avoid additional reading on speaking commands
  (let ((command-name (symbol-name this-command))
        (prefix "speechd-speak-read-"))
    (and (> (length command-name) (length prefix))
         (string= (substring command-name 0 (length command-name)) prefix))))

(speechd-speak--post-defun buffer-modifications t
    (cond
     ((eq this-command 'self-insert-command) t)
     ((not speechd-speak-movement-on-insertions) t)
     ((and (eq speechd-speak-movement-on-insertions 'read-only)
           (not buffer-read-only))
      t)
     (t 'insertions))
  ;; Any buffer modification, including completion, abbrev expansions and
  ;; self-insert-command
  buffer-modified
  ;; We handle self-insert-command in a special way.  We don't speak the
  ;; inserted character itself, we only read other buffer modifications caused
  ;; by the command (typically abbrev expansions).  Instead of speaking the
  ;; inserted character, we try to speak the command key.
  (let ((self-insert (eq this-command 'self-insert-command))
        (changes (speechd-speak--cinfo changes)))
    (when speechd-speak-buffer-insertions
      (let ((text (mapconcat #'identity
                             (funcall (if self-insert
                                          #'butlast #'identity)
                                      (reverse changes))
                             " ")))
        (when (and self-insert
                   (> (length (first changes)) 1))
          (setq text (concat text " " (first changes))))
        (cond
         ((and (eq speechd-speak-buffer-insertions 'whole-buffer)
               (not self-insert))
          (speechd-speak-read-buffer))
         (t
          (speechd-speak--text (if (eq speechd-speak-buffer-insertions t)
                                   text
                                 (save-match-data
                                   (string-match "^.*$" text)
                                   (match-string 0 text))))))))
    (when (and self-insert
               (not (eq speechd-speak-read-command-keys t))
               (not (memq 'self-insert-command
                          speechd-speak-ignore-command-keys)))
      (speechd-speak--command-keys))))

(speechd-speak--post-defun completions t t
  ;; *Completions* buffer
  (and in-minibuffer
       (get-buffer speechd-speak--c-buffer-name)
       (/= (speechd-speak--cinfo completion-buffer-modified)
           (buffer-modified-tick (get-buffer speechd-speak--c-buffer-name))))
  (save-excursion
    (set-buffer speechd-speak--c-buffer-name)
      (let ((speechd-language "en")
            (speechd-speak-input-method-languages nil))
        (goto-char (point-min))
        (save-match-data
          (re-search-forward "\n\n+" nil t))
        (speechd-speak-read-region (point) (point-max) nil))))

(speechd-speak--post-defun special-face-movement sometimes
    (or (not (stringp (cdr (assq (get-char-property (point) 'face)
                                 speechd-speak-faces))))
        state)
  ;; Special face hit
  (and (not in-minibuffer)
       point-moved
       (assq (get-char-property (point) 'face) speechd-speak-faces))
  (let ((action (cdr (assq (get-char-property (point) 'face)
                           speechd-speak-faces))))
    (cond
     ((stringp action)
      (speechd-speak--text action :priority 'message))
     ((functionp action)
      (ignore-errors
        (funcall action))))))

(speechd-speak--post-defun text-property-movement sometimes t
  ;; General text or overlay property hit
  (and (not in-minibuffer)
       point-moved
       (not (memq this-command speechd-speak-by-properties-never))
       (or (eq speechd-speak-by-properties-on-movement t)
           (memq this-command speechd-speak-by-properties-always)
           (memq (get-char-property (point) 'face)
                 speechd-speak-by-properties-on-movement))
       (or (get-char-property (point) 'face)
           (overlays-at (point)))
       (let ((position (speechd-speak--cinfo point)))
         (or (> (speechd-speak--previous-property-change
                 (1+ (point)) position)
                position)
             (<= (speechd-speak--next-property-change
                  (point) (1+ position))
                 position))))
  (speechd-speak--uniform-text-around-point))

(speechd-speak--post-defun plain-movement sometimes t
  ;; Other kinds of movement
  point-moved
  (speechd-speak-read-line (not speechd-speak-whole-line)))

(speechd-speak--post-defun other-window-event t 'other-window
  ;; Something interesting in other window
  (and (not in-minibuffer)
       other-buffer
       (member (buffer-name other-buffer) speechd-speak-auto-speak-buffers)
       (or (not (eq (next-window) (speechd-speak--cinfo other-window)))
           (not (= (buffer-modified-tick other-buffer)
                   (speechd-speak--cinfo other-buffer-modified)))))
  (speechd-speak-read-buffer (window-buffer (next-window))))

(speechd-speak--post-defun other-window-buffer nil t
  ;; Other window buffer is very interesting
  (and (not (eq state 'other-window))
       (not in-minibuffer)
       other-buffer
       (member (buffer-name other-buffer)
               speechd-speak-force-auto-speak-buffers)
       (or (not (eq (next-window) (speechd-speak--cinfo other-window)))
           (not (= (buffer-modified-tick other-buffer)
                   (speechd-speak--cinfo other-buffer-modified)))))
  (speechd-speak-read-buffer (window-buffer (next-window))))

(speechd-speak--post-defun minibuffer-exit t t
  (and speechd-speak-on-minibuffer-exit
       (/= (minibuffer-depth) speechd-speak--last-minibuffer-depth))
  (speechd-speak-read-line t))
                           
(defvar speechd-speak--last-minibuffer-depth 0)

(defvar speechd-speak--post-command-speaking-defaults
  '(speechd-speak--post-read-special-commands
    speechd-speak--post-read-buffer-switch
    speechd-speak--post-read-command-keys
    speechd-speak--post-read-info-change
    speechd-speak--post-read-speaking-commands
    speechd-speak--post-read-buffer-modifications
    speechd-speak--post-read-completions
    speechd-speak--post-read-special-face-movement
    speechd-speak--post-read-text-property-movement
    speechd-speak--post-read-plain-movement
    speechd-speak--post-read-other-window-event
    speechd-speak--post-read-other-window-buffer
    speechd-speak--post-read-minibuffer-exit))
(defvar speechd-speak--post-command-speaking nil)

(defun speechd-speak--post-command-hook ()
  (speechd-speak--enforce-speak-mode)
  (when (and speechd-speak-spell-command speechd-speak-spell-mode)
    ;; Only in spell mode to avoid disabling it after speechd-speak-spell
    (setq speechd-speak-spell-command nil)
    (speechd-speak-spell-mode 0))
  ;; Now, try to speak something useful
  (speechd-speak--maybe-speak
    (condition-case err
        (progn
          ;; Messages should be handled by an after change function.
          ;; Unfortunately, in Emacs 21 after change functions in the
          ;; *Messages* buffer don't work in many situations.  This is a
          ;; property of the Emacs implementation, so the mechanism can't be
          ;; used.
          (speechd-speak--current-message t)
          (speechd-speak--with-command-start-info
           (let* ((state nil)
                  (buffer-changed (not (eq (speechd-speak--cinfo buffer)
                                           (current-buffer))))
                  (buffer-modified (and (not buffer-changed)
                                        (/= (speechd-speak--cinfo modified)
                                            (buffer-modified-tick))))
                  (point-moved (and (not buffer-changed)
                                    (not (= (speechd-speak--cinfo point)
                                            (point)))))
                  (in-minibuffer (speechd-speak--in-minibuffer-p))
                  (other-window (next-window))
                  (other-buffer (let* ((buffer (and other-window
                                                    (window-buffer
                                                     other-window))))
                                  (unless (eq buffer (current-buffer))
                                    buffer))))
             (dolist (f speechd-speak--post-command-speaking)
               (let ((new-state state))
                 (condition-case err
                     (setq new-state (funcall f state buffer-changed
                                              buffer-modified point-moved
                                              in-minibuffer other-buffer))
                   (error
                    (speechd-speak--debug
                     (list 'post-command-hook-error f err))
                    (setq speechd-speak--post-command-speaking
                          (remove f speechd-speak--post-command-speaking))))
                 (setq state new-state)))
             (setq speechd-speak--last-minibuffer-depth (minibuffer-depth)))))
        (error
         (speechd-speak--debug (list 'post-command-hook-top-error err))
         (apply #'error (cdr err))))
    (add-hook 'post-command-hook 'speechd-speak--post-command-hook)))


;;; Comint


(speechd-speak--command-feedback comint-show-output after
  (speechd-speak-read-region))


;;; Completions, menus, etc.


(defun speechd-speak--speak-completion ()
  ;; Taken from `choose-completion'
  (let (beg end completion (buffer completion-reference-buffer)
	(base-size completion-base-size))
    (if (and (not (eobp)) (get-text-property (point) 'mouse-face))
	(setq end (point) beg (1+ (point))))
    (if (and (not (bobp)) (get-text-property (1- (point)) 'mouse-face))
	(setq end (1- (point)) beg (point)))
    (if (null beg)
	(error "No completion here"))
    (setq beg (previous-single-property-change beg 'mouse-face))
    (setq end (or (next-single-property-change end 'mouse-face) (point-max)))
    (setq completion (buffer-substring beg end))
    (speechd-speak--text completion)
    (speechd-speak--reset-command-start-info)))

(speechd-speak--command-feedback (next-completion previous-completion) after
  (speechd-speak--speak-completion))

(speechd-speak--command-feedback choose-completion before
  (speechd-speak--speak-completion))

(speechd-speak--defadvice widget-choose around
  (let ((widget-menu-minibuffer-flag t))
    ad-do-it))


;;; Other functions and packages


(speechd-speak--command-feedback (isearch-search isearch-delete-char) after
  (speechd-speak--text isearch-string)
  (speechd-speak-read-line))

(speechd-speak--command-feedback (occur-prev occur-next
				  occur-mode-goto-occurence)
				 after
  (speechd-speak-read-line))

(speechd-speak--command-feedback transpose-chars after
  (speechd-speak--char (following-char)))

(speechd-speak--command-feedback transpose-lines after
  (speechd-speak-read-line))

(speechd-speak--command-feedback transpose-words after
  (speechd-speak-read-word))

(speechd-speak--command-feedback transpose-sexps after
  (speechd-speak-read-sexp))

(speechd-speak--command-feedback undefined after
  (speechd-speak--text "No command on this key"))

(speechd-speak--command-feedback indent-for-tab-command after
  (speechd-speak--speak-current-column))


;;; Spelling


(define-minor-mode speechd-speak-spell-mode
  "Toggle spelling.
When the mode is enabled, all spoken text is spelled."
  nil " Spell" nil
  (set (make-local-variable 'speechd-spell) speechd-speak-spell-mode))

(defvar speechd-speak-spell-command nil)

(defun speechd-speak-spell ()
  "Let the very next command to be spell the text it reads."
  (interactive)
  (unless speechd-speak-spell-mode
    (setq speechd-speak-spell-command t)))
  


;;; Informatory commands


(defvar speechd-speak-info-map (make-sparse-keymap))

(defvar speechd-speak--info-updates nil)

(defmacro* speechd-speak--watch (name get-function
                                 &key on-change info info-string key)
  `(locally
     (fset (quote ,(speechd-speak--name 'speechd-speak--get name))
           ,get-function)
     ,(when info
        `(fset (quote ,(speechd-speak--name 'speechd-speak name 'info))
               #'(lambda (info)
                   (interactive)
                   (funcall ,info info))))
     ,(when info-string
        `(fset (quote ,(speechd-speak--name 'speechd-speak name 'info))
               #'(lambda ()
                   (interactive)
                   (speechd-speak--text
                    (format ,info-string
                            (funcall
                             (function ,(speechd-speak--name
                                         'speechd-speak--get name))))))))
     ,(when (and (or info info-string) key)
        `(define-key speechd-speak-info-map ,key
           (quote ,(speechd-speak--name 'speechd-speak name 'info))))
     ,(when on-change
        `(defun ,(speechd-speak--name 'speechd-speak--update name) (old new)
           (speechd-speak--maybe-speak
            (let ((speechd-default-text-priority 'message))
              (funcall ,on-change old new)))))
     ,(when on-change
        `(add-to-list 'speechd-speak--info-updates (quote ,name)))))

(speechd-speak--watch buffer-name #'buffer-name
  :on-change #'(lambda (old new)
                 (speechd-speak--text (format "Buffer %s" new))))

(speechd-speak--watch buffer-identification
  #'(lambda ()
      (when (fboundp 'format-mode-line)
        (let ((ident (format-mode-line mode-line-buffer-identification)))
          (set-text-properties 0 (length ident) nil ident)
          ident)))
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (format "New buffer identification: %s" new))))

(speechd-speak--watch buffer-modified #'buffer-modified-p
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (if new "Buffer modified" "No buffer modification"))))

(speechd-speak--watch buffer-read-only #'(lambda () buffer-read-only)
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (if new "Buffer writable" "Buffer read-only"))))

(defun speechd-speak-buffer-info ()
  "Speak current buffer information."
  (interactive)
  (speechd-speak--text
   (format "Buffer %s, %s %s %s; %s"
           (speechd-speak--get-buffer-name)
           (or vc-mode "")
           (if (speechd-speak--get-buffer-read-only) "read only" "")
           (if (speechd-speak--get-buffer-modified) "modified" "")
           (let ((ident (speechd-speak--get-buffer-identification)))
             (if ident
                 (format "buffer identification: %s" ident)
               "")))))
(define-key speechd-speak-info-map "b" 'speechd-speak-buffer-info)

(speechd-speak--watch frame-name #'(lambda () (frame-parameter nil 'name))
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (format "Old frame: %s; new frame: %s" old new))))

(speechd-speak--watch frame-identification
  #'(lambda ()
      (when (fboundp 'format-mode-line)
        (let ((ident (format-mode-line mode-line-frame-identification)))
          (set-text-properties 0 (length ident) nil ident)
          ident)))
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (format "New frame identification: %s" new))))

(defun speechd-speak-frame-info ()
  "Speak current frame information."
  (interactive)
  (speechd-speak--text
   (format "Frame: %s; %s"
           (speechd-speak--get-frame-name)
           (let ((ident (speechd-speak--get-frame-identification)))
             (if ident
                 (format "frame identification: %s" ident)
               "")))))
(define-key speechd-speak-info-map "f" 'speechd-speak-frame-info)

(speechd-speak--watch header-line
  #'(lambda ()
      (if (fboundp 'format-mode-line)
          (let ((line (format-mode-line t)))
            (if (string= line "") "empty" line))
        "unknown"))
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (format "Header line: %s" new)))
  :info-string "Header line: %s"
  :key "h")

(speechd-speak--watch major-mode #'(lambda () mode-name)
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (format "Major mode changed from %s to %s" old new))))

(speechd-speak--watch minor-modes
  #'(lambda ()
      (loop for mode in (mapcar #'car minor-mode-alist)
            when (and (boundp mode) (symbol-value mode))
            collect mode))
  :on-change #'(lambda (old new)
                 (let ((disabled (set-difference old new))
                       (enabled (set-difference new old)))
                   (when disabled
                     (speechd-speak--text
                      (format "Disabled minor modes: %s" disabled)))
                   (when enabled
                     (speechd-speak--text
                      (format "Enabled minor modes: %s" enabled))))))

(defun speechd-speak-mode-info ()
  "Speak information about current major and minor modes."
  (interactive)
  (speechd-speak--text
   (format "Major mode: %s; minor modes: %s"
           (speechd-speak--get-major-mode)
           (speechd-speak--get-minor-modes))))
(define-key speechd-speak-info-map "m" 'speechd-speak-mode-info)

(speechd-speak--watch buffer-file-coding
  #'(lambda () buffer-file-coding-system)
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (format "Buffer file coding changed from %s to %s"
                          old new))))

(speechd-speak--watch terminal-coding #'terminal-coding-system
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (format "Terminal coding changed from %s to %s" old new))))

(defun speechd-speak-coding-info ()
  "Speak information about current codings."
  (interactive)
  (speechd-speak--text
   (format "Buffer file coding is %s, terminal coding is %s"
           (speechd-speak--get-buffer-file-coding)
           (speechd-speak--get-terminal-coding))))
(define-key speechd-speak-info-map "c" 'speechd-speak-coding-info)

(speechd-speak--watch input-method #'(lambda ()
                                       (or current-input-method "none"))
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (format "Input method changed from %s to %s" old new)))
  :info-string "Input method %s"
  :key "i")

(speechd-speak--watch process
  #'(lambda ()
      (let ((process (get-buffer-process (current-buffer))))
        (and process (process-status process))))
  :on-change #'(lambda (old new)
                 (speechd-speak--text
                  (format "Process status changed from %s to %s" old new)))
  :info-string "Process status: %s"
  :key "p")

(defcustom speechd-speak-state-changes
  '(buffer-identification buffer-read-only frame-name frame-identification
    major-mode minor-modes buffer-file-coding terminal-coding input-method
    process)
  "List of identifiers of the Emacs state changes to be automatically reported.
The following symbols are valid state change identifiers: `buffer-name',
`buffer-identification', `buffer-modified', `buffer-read-only', `frame-name',
`frame-identification', `header-line', `major-mode', `minor-modes',
`buffer-file-coding', `terminal-coding', `input-method', `process'."
  :type `(set ,@(mapcar #'(lambda (i) `(const ,i))
                        (reverse speechd-speak--info-updates)))
  :group 'speechd-speak)

(defun speechd-speak--current-info ()
  (sort (mapcar #'(lambda (i)
                    (cons i (funcall
                             (speechd-speak--name 'speechd-speak--get i))))
                speechd-speak--info-updates)
        #'(lambda (x y) (string< (symbol-name (car x))
                                 (symbol-name (car y))))))


;;; Mode definition


(defvar speechd-speak-mode-map nil
  "Keymap used by speechd-speak-mode.")

(define-prefix-command 'speechd-speak-prefix-command 'speechd-speak-mode-map)

(define-key speechd-speak-mode-map "b" 'speechd-speak-read-buffer)
(define-key speechd-speak-mode-map "c" 'speechd-speak-read-char)
(define-key speechd-speak-mode-map "i" 'speechd-speak-last-insertions)
(define-key speechd-speak-mode-map "l" 'speechd-speak-read-line)
(define-key speechd-speak-mode-map "m" 'speechd-speak-last-message)
(define-key speechd-speak-mode-map "o" 'speechd-speak-read-other-window)
(define-key speechd-speak-mode-map "p" 'speechd-pause)
(define-key speechd-speak-mode-map "q" 'speechd-speak-toggle-speaking)
(define-key speechd-speak-mode-map "r" 'speechd-speak-read-region)
(define-key speechd-speak-mode-map "s" 'speechd-stop)
(define-key speechd-speak-mode-map "w" 'speechd-speak-read-word)
(define-key speechd-speak-mode-map "x" 'speechd-cancel)
(define-key speechd-speak-mode-map "z" 'speechd-repeat)
(define-key speechd-speak-mode-map "." 'speechd-speak-read-sentence)
(define-key speechd-speak-mode-map "{" 'speechd-speak-read-paragraph)
(define-key speechd-speak-mode-map " " 'speechd-resume)
(define-key speechd-speak-mode-map "'" 'speechd-speak-read-sexp)
(define-key speechd-speak-mode-map "[" 'speechd-speak-read-page)
(define-key speechd-speak-mode-map ">" 'speechd-speak-read-rest-of-buffer)
(define-key speechd-speak-mode-map "\C-a" 'speechd-add-connection-settings)
(define-key speechd-speak-mode-map "\C-c" 'speechd-speak-new-connection)
(define-key speechd-speak-mode-map "\C-i" speechd-speak-info-map)
(define-key speechd-speak-mode-map "\C-l" 'speechd-speak-spell)
(define-key speechd-speak-mode-map "\C-m" 'speechd-speak-read-mode-line)
(define-key speechd-speak-mode-map "\C-n" 'speechd-speak-read-next-line)
(define-key speechd-speak-mode-map "\C-p" 'speechd-speak-read-previous-line)
(define-key speechd-speak-mode-map "\C-r" 'speechd-speak-read-rectangle)
(define-key speechd-speak-mode-map "\C-s" 'speechd-speak)
(define-key speechd-speak-mode-map "\C-x" 'speechd-unspeak)
(dotimes (i 9)
  (define-key speechd-speak-mode-map (format "%s" (1+ i))
              'speechd-speak-key-set-predefined-rate))
(define-key speechd-speak-mode-map "d." 'speechd-set-punctuation-mode)
(define-key speechd-speak-mode-map "dc" 'speechd-set-capital-character-mode)
(define-key speechd-speak-mode-map "dl" 'speechd-set-language)
(define-key speechd-speak-mode-map "do" 'speechd-set-output-module)
(define-key speechd-speak-mode-map "dp" 'speechd-set-pitch)
(define-key speechd-speak-mode-map "dr" 'speechd-set-rate)
(define-key speechd-speak-mode-map "dv" 'speechd-set-voice)
(define-key speechd-speak-mode-map "dV" 'speechd-set-volume)

(defvar speechd-speak--mode-map (make-sparse-keymap))
(defvar speechd-speak--prefix nil)

(defun speechd-speak--build-mode-map ()
  (let ((map speechd-speak--mode-map))
    (when speechd-speak--prefix
      (define-key map speechd-speak--prefix nil))
    (setq speechd-speak--prefix speechd-speak-prefix)
    (define-key map speechd-speak-prefix 'speechd-speak-prefix-command)
    (unless (lookup-key speechd-speak-mode-map speechd-speak-prefix)
      (define-key map (concat speechd-speak-prefix speechd-speak-prefix)
        (lookup-key global-map speechd-speak-prefix)))))

(define-minor-mode speechd-speak-map-mode
  "Toggle use of speechd-speak keymap.
With no argument, this command toggles the mode.
Non-null prefix argument turns on the mode.
Null prefix argument turns off the mode."
  nil nil speechd-speak--mode-map)

(easy-mmode-define-global-mode
 global-speechd-speak-map-mode speechd-speak-map-mode
 (lambda () (speechd-speak-map-mode 1))
 :group 'speechd-speak)

(defun speechd-speak--shutdown ()
  ;; We don't have to call CANCEL here, since Emacs exit is usually called
  ;; interactivelly, so it is preceeded by the pre-command CANCEL.  Moreover,
  ;; calling CANCEL here means trouble with stopping the final exit messages.
  (speechd-speak--signal 'finish :priority 'important))

;;;###autoload
(define-minor-mode speechd-speak-mode
  "Toggle speaking, the speechd-speak mode.
With no argument, this command toggles the mode.
Non-null prefix argument turns on the mode.
Null prefix argument turns off the mode.
     
When speechd-speak mode is enabled, speech output is provided to Speech
Dispatcher on many actions.

The following key bindings are offered by speechd-speak mode, prefixed with
the value of the `speechd-speak-prefix' variable:

\\{speechd-speak-mode-map}
"
  nil " S" speechd-speak--mode-map
  (if speechd-speak-mode
      (progn
        (speechd-speak-map-mode 1)
        (add-hook 'pre-command-hook 'speechd-speak--pre-command-hook)
        (add-hook 'post-command-hook 'speechd-speak--post-command-hook)
        (add-hook 'after-change-functions 'speechd-speak--after-change-hook)
        (add-hook 'minibuffer-setup-hook 'speechd-speak--minibuffer-setup-hook)
        (add-hook 'minibuffer-exit-hook 'speechd-speak--minibuffer-exit-hook)
        (add-hook 'kill-emacs-hook 'speechd-speak--shutdown))
    ;; We used to call `speechd-cancel' here, but that slows down global mode
    ;; disabling if there are many buffers present.  So `speechd-cancel' is
    ;; called only on global mode disabling now.
    )
  (when (interactive-p)
    (let ((state (if speechd-speak-mode "on" "off"))
          (speechd-speak-mode t))
      (message "Speaking turned %s" state))))

;;;###autoload
(easy-mmode-define-global-mode
 global-speechd-speak-mode speechd-speak-mode
 (lambda () (speechd-speak-mode 1))
 :group 'speechd-speak)

(speechd-speak--defadvice global-speechd-speak-mode before
  (when global-speechd-speak-mode
    (speechd-cancel)))

;; global-speechd-speak-map-mode is not enabled until kill-all-local-variables
;; is called.  So we have to be a bit more aggressive about it sometimes.  The
;; same applies to global-speechd-speak-mode.
(defun speechd-speak--enforce-speak-mode ()
  (flet ((enforce-mode (global-mode local-mode-var)
           (when (and global-mode
                      (not (symbol-value local-mode-var))
                      (not (local-variable-p local-mode-var)))
             (funcall local-mode-var 1))))
    (enforce-mode global-speechd-speak-map-mode 'speechd-speak-map-mode)
    (enforce-mode global-speechd-speak-mode 'speechd-speak-mode)))

(defun speechd-speak-toggle-speaking (arg)
  "Toggle speaking.
When prefix ARG is non-nil, toggle it locally, otherwise toggle it globally."
  (interactive "P")
  (if arg
      (speechd-speak-mode)
    (global-speechd-speak-mode))
  (when (interactive-p)
    (let ((state (if speechd-speak-mode "on" "off"))
          (speechd-speak-mode t))
      (message "Speaking turned %s %s" state (if arg "locally" "globally")))))

(defun speechd-unspeak ()
  "Try to avoid invoking any speechd-speak function.
This command is useful as the last help in case speechd-speak gets crazy and
starts blocking your Emacs functions."
  (interactive)
  (setq speechd-speak--started nil)
  (ignore-errors (global-speechd-speak-mode -1))
  (when speechd-speak--message-timer
    (cancel-timer speechd-speak--message-timer)
    (setq speechd-speak--message-timer nil))
  (remove-hook 'pre-command-hook 'speechd-speak--pre-command-hook)
  (remove-hook 'post-command-hook 'speechd-speak--post-command-hook)
  (remove-hook 'after-change-functions 'speechd-speak--after-change-hook)
  (remove-hook 'minibuffer-setup-hook 'speechd-speak--minibuffer-setup-hook)
  (remove-hook 'minibuffer-exit-hook 'speechd-speak--minibuffer-exit-hook)
  (remove-hook 'kill-emacs-hook 'speechd-speak--shutdown)
  (speechd-close)
  (global-speechd-speak-map-mode -1))

;;;###autoload
(defun speechd-speak (&optional arg)
  "Start or restart speaking.
With a prefix argument, close all open connections first."
  (interactive "P")
  (if arg
      (speechd-unspeak)
    (speechd-reopen))
  (let ((already-started speechd-speak--started))
    (setq speechd-speak--started t)
    (speechd-speak--build-mode-map)
    (setq speechd-speak--post-command-speaking
          speechd-speak--post-command-speaking-defaults)
    (global-speechd-speak-mode 1)
    (global-speechd-speak-map-mode 1)
    (speechd-speak--debug 'start)
    (speechd-speak--signal 'start)
    (setq speechd-speak--message-timer
          (run-with-idle-timer 0 t 'speechd-speak--message-timer))))


;;; Announce


(provide 'speechd-speak)


;;; speechd-speak.el ends here
