package cli

import (
	"fmt"
	"io"
	"os"
	"strings"
)

const topHelp = `usage: ii COMMAND [ARGS]

Aliases:
  h, -h, --help

Help:
  ii help

Variables:
  set|s NAME=VALUE      Set a variable in tmux and this shell
  set|s NAME VALUE      Set one variable from CLI arguments
  s:NAME=VALUE[,NAME=VALUE...]
                          Set one or more variables with "="
  set|s NAME[,NAME...] --from-shell
                          Save current shell variables back to tmux
  set|s --from-shell -a | sha
                          Save all non-empty default shell variables
  set|s --from-file [PATH] | sf [PATH]
                          Import variables from PATH, default .env
  set|s -d [IFACE]       Detect lhost from an interface, default tun0
  set|s rhost=VALUE      Set rhost and auto-detect lhost when enabled
  sr VALUE               Set rhost and trigger the same lhost auto-detection
  get|g FILTER           Copy and print one tmux variable value
  g:FILTER               Shortcut form of ii g FILTER
  gr                     Copy and print rhost (ii g r)
  gl                     Copy and print lhost (ii g l)
  load|l                 Load variables into this shell
  load --all-pane|la     Review panes, then load selected shells
  interactive|i          Select, edit, add, and copy variables
  ls|list|variable|vars|var [PATTERN]
                          List non-empty variables, optionally filtered by key
  v [PATTERN]            List variables; --out writes them to a file
  v --out [PATH]         Write non-empty variables to .env or PATH
  vo [PATH]              Alias for ii v --out
  voc [PATH]             Compatibility alias for ii v --out
  unset|u NAME [...]     Remove ii_ variables
  unset|u -a             Prompt, then remove all ii_ variables

Payloads:
  payload|p [CATEGORY]   Select, render, print, and optionally write a payload
  payload|p KEYWORD ...  Fuzzy-search using all keyword arguments
  payload|p --copy [KEYWORD ...] | pc [KEYWORD ...]
                          Review and copy a selection from an initial query
  payload|p --execute [KEYWORD ...] | pe [KEYWORD ...]
                          Select, confirm, and execute without copying
  payload|p --copy --execute [KEYWORD ...] | pce [KEYWORD ...]
                          Select, confirm, copy, and execute in this shell
  payload|p --input [-o [PATH]]
                          Render pasted or standard input
  payload|p --input --copy [-o [PATH]] | pic [-o [PATH]]
                          Render and copy input
  payload|p --input --execute [-o [PATH]] | pie
                          Render, confirm, and execute input
  payload|p --input --copy --execute [-o [PATH]] | pice
                          Render, confirm, copy, and execute input
  payload|p --www        Render a file, list, search, or symlink under /www

Clipboard:
  clip|clipboard backend Show or set clipboard backend
  clip|clipboard doctor  Diagnose clipboard backend behavior

Tmux integration:
  tmux status            Diagnose the default tmux :ii command alias

Other:
  version|-v|--version   Show installed version
  help|h|-h|--help [COMMAND]
                          Show help
`

const versionHelp = `usage: ii version

Aliases:
  -v, --version

Help:
  ii help version

Print the installed ii version.
`

const listHelp = `usage: ii ls [PATTERN]

Aliases:
  list, variable, vars, var

Help:
  ii help ls

Print non-empty variables from the current tmux session.
PATTERN filters variable names only, case-insensitively.
Output format is blue key, then value, without blank lines between entries.
ii v [PATTERN] uses this same listing behavior; see ii v --help for its --out
file-output mode.
`

const variableHelp = `usage: ii v [PATTERN]
       ii v --out [PATH]
       ii vo [PATH]
       ii voc [PATH]

Aliases:
  vo
  voc

Help:
  ii help v
  ii help v --out
  ii help vo
  ii help voc

Without --out, list non-empty variables using the same optional key filter as
ii ls. With --out, write all non-empty variables to PATH in shell-sourceable
name='value' format. PATH defaults to .env in the current directory.
`

const variableOutputHelp = `usage: ii v --out [PATH]
       ii vo [PATH]
       ii voc [PATH]

Aliases:
  vo
  voc

Help:
  ii help v --out
  ii help variables-output
  ii help vo
  ii help voc

Write all non-empty ii variables to PATH in shell-sourceable name='value'
format. User-facing names are lowercase without the internal ii_ prefix.
PATH defaults to .env in the current directory. Existing files are replaced.
`

const interactiveHelp = `usage: ii interactive
       ii i

Aliases:
  i

Help:
  ii help interactive

Select variables with fzf, edit values, and copy values.
Default variable names are shown even before they have values.
Variables with values are listed before empty default names.
Select "add new variable" to create or update a variable.
Enter copies the selected value and closes.
i or l edits the selected variable. y copies without closing.
h, q, Esc, or Ctrl-C aborts. Use ii load to load variables into this shell.
`

const clipboardHelp = `usage: ii clip backend
       ii clip backend auto
       ii clip backend BACKEND
       ii clip doctor

Aliases:
  clipboard

Help:
  ii help clip

Inspect or change clipboard backend settings for this shell and tmux session.

backend prints the effective backend. backend auto clears II_CLIP_BACKEND and
II_CLIP_CMD from this shell and the current tmux session. backend BACKEND sets
II_CLIP_BACKEND in this shell and the current tmux session.

doctor prints clipboard context, copies a test token, asks whether it reached
the desired clipboard, and can set a context-appropriate backend.
`

const tmuxHelp = `usage: ii tmux status

Aliases:
  none

Help:
  ii help tmux

The tmux command alias is installed automatically when the plugin loads inside
tmux. It adds ii to tmux's native Prefix + : command prompt without replacing
that key binding. Enter ii at the prompt to open an isolated payload popup.

Set II_TMUX_INTEGRATION=0 before loading the plugin to disable automatic setup.
If another tmux command alias already owns the name ii, ii leaves it unchanged;
set II_TMUX_INTEGRATION_FORCE=1 to replace that conflicting alias. Status is
read-only and reports the command alias, native Prefix+: binding, and helper.
`

const setUsage = `usage: ii set NAME=VALUE [NAME=VALUE...]
       ii set NAME VALUE
`

const setHelp = `usage: ii set NAME=VALUE [NAME=VALUE...]
       ii s NAME=VALUE [NAME=VALUE...]
       ii set NAME VALUE
       ii s NAME VALUE
       ii sr VALUE
       ii s:NAME=VALUE[,NAME=VALUE...]
       ii set NAME[,NAME...] [--from-shell]
       ii s:NAME[,NAME...] [--from-shell]
       ii set --from-shell -a
       ii s --from-shell -a
       ii sha
       ii set --from-file [PATH]
       ii s --from-file [PATH]
       ii sf [PATH]
       ii s NAME -d [INTERFACE]
       ii s -d [INTERFACE]
       ii s:lhost -d [INTERFACE]

Aliases:
  s
  sr
  sf
  sha

Help:
  ii help set

Forms:
  NAME=VALUE
    Set NAME=VALUE in the current tmux session and export it into this shell.
    Multiple assignments can be separate arguments or comma-separated shortcut
    entries, such as ii s:usert=alice,passt=secret.

  NAME VALUE
    Set one variable from explicit command-line arguments. Use NAME=VALUE for
    batches or when the value could otherwise be confused with an option.

  NAME[,NAME...] --from-shell
    Save existing shell variables back into the tmux session. Lowercase shell
    names are checked first, then uppercase names. Missing shell variables print
    red warnings and are skipped.

  --from-shell -a
    Check every default ii variable name against non-empty lowercase, then
    uppercase shell variables. Save and print each value found; silently skip
    unset or empty defaults.

  --from-file [PATH]
    Read NAME=VALUE entries from PATH, defaulting to .env in the current
    directory. Blank lines, comments, an optional export prefix, and the
    quoting written by ii v --out are supported. Each imported value is saved
    to tmux, exported into this shell, and printed.

  -d [INTERFACE]
    Detect lhost from INTERFACE. The default INTERFACE is tun0. Detect is only
    supported for lhost.

  automatic lhost detect
    When rhost or rhosts is set, ii automatically detects lhost from the
    configured interface and prints the detected value. This is controlled by
    II_AUTO_DETECT_LHOST and II_AUTO_DETECT_LHOST_INTERFACE.

Notes:
  User-facing names do not include the internal ii_ prefix. Single-letter
  shortcuts include r for rhost, l for lhost, and d for domain. II_EXPORT_CASE
  controls whether exported shell variables use lower, upper, or both cases.
`

const unsetHelp = `usage: ii unset NAME [NAME...]
       ii unset -a

Aliases:
  u

Help:
  ii help unset
  ii help u

Remove ii_name from the current tmux session and unset it in this shell.
With -a, remove all ii_ variables after confirmation.
`

const loadHelp = `usage: ii load
       ii l
       ii load --all-pane
       ii la

Aliases:
  l
  la    ii load --all-pane

Help:
  ii help load
  ii help load --all-pane

Load non-empty variables from the current tmux session into this shell.
The current shell exports use names without the internal ii_ prefix.
II_EXPORT_CASE controls exported shell names: lower, upper, or both.
The default is lower.

With --all-pane or la, show every pane in the current tmux window in a
multi-select prompt. Panes that appear to be idle zsh shells are preselected
as "likely ready". Review the selection with Space, then press Enter to load
the current shell directly and dispatch ` + "`ii l`" + ` to the other selected panes.
Other panes must already have ii loaded. "dispatched" means the command was
sent successfully; it does not confirm that the destination shell ran it.
`

const getUsage = `usage: ii get FILTER
       ii g FILTER
       ii g:FILTER
       ii gr
       ii gl
`

const getHelp = `usage: ii get FILTER
       ii g FILTER
       ii g:FILTER
       ii gr
       ii gl

Aliases:
  g
  gr (ii g r)
  gl (ii g l)

Help:
  ii help get
  ii help g

Get a variable value from the current tmux session, copy it, and print it.
FILTER matches variable names case-insensitively, with the same shortcut
handling as ii set. No matches prints "no matched". One match copies the value.
Multiple matches open a prompt; Enter or Space selects one value. q, Esc, or
Ctrl-C aborts without changing variables or copying anything.
`

func ColorEnabled(stdout io.Writer, getenv func(string) string) bool {
	if getenv("NO_COLOR") != "" {
		return false
	}
	switch strings.ToLower(getenv("II_COLOR")) {
	case "always":
		return true
	case "never":
		return false
	}
	if getenv("TERM") == "dumb" {
		return false
	}
	file, ok := stdout.(*os.File)
	if !ok {
		return false
	}
	info, err := file.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

func ColorizeAliases(input string, enabled bool) string {
	if !enabled {
		return input
	}

	lines := strings.SplitAfter(input, "\n")
	inAliases := false
	for index, line := range lines {
		body := strings.TrimSuffix(line, "\n")
		newline := strings.TrimPrefix(line, body)
		if body == "Aliases:" {
			inAliases = true
			continue
		}
		if inAliases && body == "" {
			inAliases = false
			continue
		}
		if !inAliases || !strings.HasPrefix(body, "  ") {
			continue
		}
		content := strings.TrimPrefix(body, "  ")
		if content == "none" {
			continue
		}
		aliases, suffix := splitAliasSuffix(content)
		lines[index] = "  \x1b[36m" + aliases + "\x1b[0m" + suffix + newline
	}
	return strings.Join(lines, "")
}

func Color(code int, text string, enabled bool) string {
	if !enabled {
		return text
	}
	return fmt.Sprintf("\x1b[%dm%s\x1b[0m", code, text)
}

func splitAliasSuffix(content string) (string, string) {
	if index := strings.Index(content, "    "); index >= 0 {
		return content[:index], content[index:]
	}
	if index := strings.Index(content, " ("); index >= 0 {
		return content[:index], content[index:]
	}
	return content, ""
}
