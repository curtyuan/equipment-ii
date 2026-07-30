package cli

import "strings"

const payloadInputHelp = `usage: ii p --input [-o [PATH]]
       ii payload --input [-o [PATH]]
       ii p --input --copy [-o [PATH]]
       ii payload --input --copy [-o [PATH]]
       ii pic [-o [PATH]]
       ii p --input --execute [-o [PATH]]
       ii payload --input --execute [-o [PATH]]
       ii pie
       ii p --input --copy --execute [-o [PATH]]
       ii payload --input --copy --execute [-o [PATH]]
       ii pice

Aliases:
  none

Help:
  ii help payload --input
  ii help payload-input
  ii help payload --input --copy
  ii help pic
  ii help payload --input --execute
  ii help pie
  ii help payload --input --copy --execute
  ii help pice

Paste template text below the prompt, then render variables and print the
rendered output. Enter finishes, Alt-Enter inserts a newline, and Esc cancels.
Entering :q or :q! as the complete buffer also cancels.

Piped and here-document input ends at EOF. A standalone :w line finishes early;
a standalone :q or :q! line cancels.

Shell values win over ii tmux values. Missing values keep the original token
and are reported.

With --execute, ii asks [y/N] before executing through the allowlisted
parent-shell channel. --copy copies the rendered text. -o writes it to a file;
with no PATH, output goes to /www/p/att.txt.
`

const payloadInputCopyHelp = `usage: ii payload --input --copy [-o [PATH]]
       ii p --input --copy [-o [PATH]]
       ii pic [-o [PATH]]

Aliases:
  pic

Help:
  ii help payload --input --copy
  ii help pic

Read payload text, render lowercase variables, copy the complete rendered
result, and print it. Enter finishes, Alt-Enter inserts a newline, and Esc
cancels. Piped and here-document input reads through EOF; :w finishes early.

-o writes the rendered text to a file while preserving copy behavior. With no
PATH, output goes to /www/p/att.txt.
`

const payloadInputExecuteHelp = `usage: ii payload --input --execute [-o [PATH]]
       ii p --input --execute [-o [PATH]]
       ii pie

Aliases:
  pie

Help:
  ii help payload --input --execute
  ii help pie

Read and render payload text, show unresolved variables, and ask [y/N] before
executing it in the current shell through the allowlisted parent-shell channel.
Nothing is copied.

Enter finishes, Alt-Enter inserts a newline, and Esc cancels. Piped and
here-document input reads through EOF; :w finishes early.
`

const payloadInputCopyExecuteHelp = `usage: ii payload --input --copy --execute [-o [PATH]]
       ii p --input --copy --execute [-o [PATH]]
       ii pice

Aliases:
  pice

Help:
  ii help payload --input --copy --execute
  ii help pice

Read and render payload text, show unresolved variables, and ask [y/N]. After
confirmation, ii copies the rendered payload and executes it in the current
shell through the allowlisted parent-shell channel. Clipboard failure does not
prevent confirmed execution.

Enter finishes, Alt-Enter inserts a newline, and Esc cancels. Piped input ends
at EOF or a standalone :w line. pice accepts no options or positional arguments.
`

func payloadInputHelpFor(args []string) string {
	joined := " " + strings.Join(args, " ") + " "
	if strings.Contains(joined, " pice ") ||
		strings.Contains(joined, " --copy ") && strings.Contains(joined, " --execute ") {
		return payloadInputCopyExecuteHelp
	}
	if strings.Contains(joined, " pie ") || strings.Contains(joined, " --execute ") {
		return payloadInputExecuteHelp
	}
	if strings.Contains(joined, " pic ") || strings.Contains(joined, " --copy ") {
		return payloadInputCopyHelp
	}
	return payloadInputHelp
}
