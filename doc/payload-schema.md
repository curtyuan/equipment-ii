# Payload Schema

Payload files are plain text templates under `II_PAYLOAD_DIR`. The selector
entry is the file path relative to `II_PAYLOAD_DIR`.

This schema covers stored payload files. Pasted input with `ii p --input` uses
the same render rules, but it does not have path or first-line description
metadata.

For documentation and external tooling, treat each stored payload file as this
logical object:

```json
{
  "$schema": "ii.payload.schema.v1",
  "path": "shell/linux/sh-tcp",
  "description": "optional first-line metadata without the prefix",
  "stages": [],
  "source_body": "payload source text after first-line description metadata",
  "emitted_body": "payload text after metadata conversion and variable rendering",
  "variables": ["lhost", "lport", "rhost"]
}
```

Field meanings:

| Field | Source | Required | Notes |
| --- | --- | --- | --- |
| `$schema` | Documentation/tooling | No | Identifies this logical schema. It is not written into payload files. |
| `path` | Relative file path | Yes | Also used as the fzf selector entry and category filter input. |
| `description` | First line | No | Only recognized when line 1 starts with `# description:`. It is shown in preview and omitted from copied output. |
| `stages` | Body metadata scan | No | Legacy stage labels are presentation metadata; opted-in workflows use structured stages. |
| `source_body` | Remaining text | Yes | File content after first-line description metadata. It may include `# stage:` metadata. |
| `emitted_body` | Render pipeline | Yes | Text printed, copied, or written after `# stage:` conversion and variable rendering. |
| `variables` | Body scan | No | Lowercase percent or shell-style placeholders used by the renderer. |

Recognized payload file syntax:

```text
# description: optional operator-facing description
# stage: optional combo stage label
payload body with %lhost%, $rhost, ${file}, or ${file:t}
```

Metadata handling:

- `# description:` is recognized only on line 1.
- `# stage:` is recognized on any body line and emits `# --- label ---`.
- Other comment lines are ordinary payload body text.

Payload files render lowercase `%name%`, `$name`, `${name}`, and `${name:t}`
through the shared renderer. A non-empty lowercase shell variable wins first,
then the matching tmux `ii_` variable is used. Uppercase percent/shell forms and
legacy `II_NAME` forms are left unchanged. Missing values keep the original
token and are reported in red.

## Combo Payload Convention

Combo payloads are multi-stage payload files for paired operator/target actions
such as file transfer. Files without `# flow: 1` remain ordinary legacy
payloads. Files with the marker use strict workflow parsing and confirmed tmux
pane routing.

Recommended path shape:

```text
script/combo/DOMAIN/TOOL-DIRECTION-FLOW
```

Naming fields:

| Field | Meaning | Examples |
| --- | --- | --- |
| `DOMAIN` | Workflow area. | `trans` |
| `TOOL` | Primary tool or tool family. | `powercat` |
| `DIRECTION` | Data direction. | `K2T` = Kali sends to target, `T2K` = target sends to Kali |
| `FLOW` | Listener/connector roles. | `KLTC` = Kali listens and target connects, `TLKC` = target listens and Kali connects |

Use `K` for Kali/operator side and `T` for target side. Use `L` for the side
that listens and `C` for the side that connects. The sender/receiver meaning
comes from `DIRECTION`; the network connection shape comes from `FLOW`.

Examples:

```text
script/combo/trans/powercat-K2T-TLKC
script/combo/trans/powercat-T2K-KLTC
script/combo/trans/powercat-K2T-KLTC
script/combo/trans/powercat-T2K-TLKC
```

Executable combo files keep command text in the body and avoid Markdown fences
or prose. The complete first-version form is:

```text
# description: Kali send to Target
# flow: 1
# note: Target must already have powercat.

# stage: powershell | Receive file to TEMP
# lane: remote-transfer
# advance: confirm
$RFILE="${file:t}"
$OUTFILE = Join-Path $env:TEMP "$RFILE"
powercat -l -p $rport -of $OUTFILE

# stage: zsh | Send file from Kali
# lane: kali-transfer
# advance: confirm
nc -q 0 $rhost $rport < $file
```

Workflow rules:

- `# flow: 1` appears exactly once before the first stage.
- Every `# stage: SHELL | TITLE` is immediately followed by a valid
  `# lane: kali-NAME|remote-NAME` and `# advance: confirm`.
- Complete lane names determine sharing. At most three distinct lanes are
  accepted and each is pinned to one distinct pane before execution.
- The parser validates the complete file before preview, render, copy, output,
  or execution. Errors include the source line and never fall back to legacy
  handling.
- Shell metadata is advisory. It does not rewrite commands or prove the shell
  behind a remote connection.
- Preview and ordinary output retain distinct stage headers. Copy replaces the
  clipboard one confirmed stage at a time.
- Execute selection opens a tmux popup. Enter confirms all lane assignments;
  every stage then requires `y` before literal buffer transport and Enter.
- Workflow execution requires tmux and never evaluates the combined body in the
  originating shell.

Legacy combo files without `# flow: 1` retain the original free-form
`# stage: LABEL` conversion to paste-safe `# --- LABEL ---` comments.

Uppercase shell variables such as `$RFILE` and `$OUTFILE` intentionally stay
unrendered. Use them when the target shell should expand or assign the value at
runtime. Use lowercase render tokens such as `$file`, `${file:t}`, `$lhost`,
`$lport`, `$rhost`, and `$rport` only for values that `ii` should resolve before
copying.

Detailed selector, lane memory, and execution semantics are documented in
[workflow.md](workflow.md).
