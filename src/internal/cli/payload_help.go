package cli

const payloadHelp = `usage: ii payload [CATEGORY]
       ii p [CATEGORY]
       ii p [CATEGORY] -o [PATH]
       ii p [KEYWORD ...]
       ii p --copy [KEYWORD ...]
       ii pc [KEYWORD ...]
       ii p --execute [KEYWORD ...]
       ii pe [KEYWORD ...]
       ii p --copy --execute [KEYWORD ...]
       ii pce [KEYWORD ...]
       ii p --www --file PATH
       ii p --www ln SOURCE_PATH [LINK_NAME]
       ii p --www ls
       ii p --www search [FILTER]
       ii p --input [-o [PATH]]
       ii p --input --copy [-o [PATH]]
       ii pic [-o [PATH]]
       ii p --input --execute [-o [PATH]]
       ii pie
       ii p --input --copy --execute [-o [PATH]]
       ii pice

Aliases:
  p
  pc
  pe
  pce
  pic
  pie
  pice

Help:
  ii help payload
  ii help pc
  ii help pe
  ii help pce
  ii help payload --input
  ii help pic
  ii help payload --input --execute
  ii help pie
  ii help pice
  ii help payload --www

Payload files:
  Open the payload selector, render the selected template, and print the output.

  The selector shows payload paths in the list and a selected template preview
  at the bottom, with resolved renderable tokens highlighted green and missing
  tokens highlighted red.
  A first-line "# description: ..." metadata line is shown in preview but
  omitted from copied output.
  "# stage: ..." metadata lines are emitted as paste-safe "# --- ... ---"
  comment delimiters for combo payloads.
  The selector starts in normal mode. Press / to search; Esc returns to normal.
  Use y to copy the selected rendered payload and close the selector.
  Use --copy or pc to open the same selector in copy mode. Keywords initialize
  its query; they never select or copy a best match without review.
  Use e in normal mode to execute the selected rendered payload in the current
  shell. With --execute or pe, Enter confirms execution instead of printing.
  With --copy --execute or pce, confirmed execution also copies first. Execution
  is not isolated: shell variables, cwd, and other side effects persist.
  Use l to unfold the selected script into a full preview, and h to return to
  compact normal mode. In unfolded preview, j and k still move between
  payloads, Enter still renders and outputs, and q aborts.
  Payload files render lowercase %name%, $name, ${name}, and ${name:t}. Shell
  values win over ii tmux values. Uppercase placeholders are left unchanged.
  Missing values keep their original token.

Pasted input:
  ii p --input [-o [PATH]]
  ii p --input --copy [-o [PATH]] = ii pic [-o [PATH]]
  ii p --input --execute [-o [PATH]] = ii pie
  ii p --input --copy --execute [-o [PATH]] = ii pice

  Paste template text below the prompt. In a terminal, Enter finishes,
  Alt+Enter inserts a newline, Esc cancels, and a bottom status line keeps
  the keys visible. Piped input finishes with a single ":w" line. The renderer
  uses lowercase shell-style variables from this shell first and ii variables
  second. Use --copy to copy the rendered input to the clipboard. Here-documents and pipes
  read standard input through EOF, so ` + "`ii pic <<EOF` and `COMMAND | ii pic`" + `
  both render and copy the complete input.
  With --execute or pie, ii confirms and executes the rendered input without
  copying. pie accepts no options or positional arguments.
  With --copy --execute or pice, ii confirms, copies, and executes the rendered
  input in the current shell. pice accepts no positional arguments.

Output:
  -o writes the rendered text to a file while keeping the normal terminal
  output. With no PATH, output goes to /www/p/att.txt. A bare filename writes
  to /www/FILENAME. Directory paths use att.txt. After rendering, ii prints the
  output file note and ends with the absolute output path on its own line.

/www helpers:
  ii p --www --file PATH
    Read PATH, render it with the normal payload renderer, print the render
    report and rendered output, then symlink PATH into /www/p and print
    relative_file, file, and rfile shell commands for manual copy.

  ii p --www ln SOURCE_PATH [LINK_NAME]
    Select a directory under /www and create a symlink to SOURCE_PATH there.

  ii p --www ls
    Print files and directories under /www as a tree.

  ii p --www search [FILTER]
    Fuzzy-select an entry under /www and print its containing directory relative
    to /www, then its absolute path. FILTER preselects the first
    case-insensitive fzf match.

Categories:
  all, shell, script, linux, windows, sqli, xss
`

const payloadCopyHelp = `usage: ii p --copy [KEYWORD ...]
       ii pc [KEYWORD ...]

Aliases:
  pc

Help:
  ii help payload-copy
  ii help pc

Open the payload selector with all keywords joined as its initial query. Review
the preview, then press y to copy the selected payload.
`

const payloadExecuteHelp = `usage: ii payload --execute [KEYWORD ...]
       ii p --execute [KEYWORD ...]
       ii pe [KEYWORD ...]

Aliases:
  pe

Help:
  ii help payload --execute
  ii help pe

Open the payload selector with all keywords joined as its initial query. Enter
renders the selected payload, shows unresolved lowercase variables when
present, and asks [y/N] before executing in the current shell. Nothing is
copied. Execution is not isolated: cwd, variables, functions, and other shell
side effects persist.
`

const payloadCopyExecuteHelp = `usage: ii payload --copy --execute [KEYWORD ...]
       ii p --copy --execute [KEYWORD ...]
       ii pce [KEYWORD ...]

Aliases:
  pce

Help:
  ii help payload --copy --execute
  ii help pce

Open the payload selector with all keywords joined as its initial query. Enter
renders the selected payload, shows unresolved lowercase variables when
present, and asks [y/N]. After y, ii copies the rendered payload and executes
it in the current shell. Clipboard failure is reported but does not prevent
confirmed execution. The letter c in pce always means copy.
`

func payloadHelpFor(args []string) string {
	if containsString(args, "pce") {
		return payloadCopyExecuteHelp
	}
	if containsString(args, "pe") {
		return payloadExecuteHelp
	}
	if containsString(args, "pc") || containsString(args, "payload-copy") {
		return payloadCopyHelp
	}
	if containsString(args, "--execute") {
		if containsString(args, "--copy") {
			return payloadCopyExecuteHelp
		}
		return payloadExecuteHelp
	}
	if containsString(args, "--copy") {
		return payloadCopyHelp
	}
	return payloadHelp
}
