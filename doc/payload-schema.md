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
| `stages` | Body metadata scan | No | Each `# stage:` line marks a combo step and is emitted as a paste-safe comment delimiter. |
| `source_body` | Remaining text | Yes | File content after first-line description metadata. It may include `# stage:` metadata. |
| `emitted_body` | Render pipeline | Yes | Text printed, copied, or written after `# stage:` conversion and variable rendering. |
| `variables` | Body scan | No | Lowercase shell-style placeholders used by the renderer. |

Recognized payload file syntax:

```text
# description: optional operator-facing description
# stage: optional combo stage label
payload body with ${lhost}, $rhost, ${file}, or ${file:t}
```

Metadata handling:

- `# description:` is recognized only on line 1.
- `# stage:` is recognized on any body line and emits `# --- label ---`.
- Other comment lines are ordinary payload body text.

Payload files render `$name`, `${name}`, and `${name:t}` through the shared
renderer. New payloads should use lowercase shell-style placeholders only. A
non-empty lowercase shell variable wins first, then the matching tmux `ii_`
variable is used. Uppercase shell variables such as `$RHOST` are left unchanged.
Missing values keep the original token and are reported in red.

## Combo Payload Convention

Combo payloads are multi-stage payload files for paired operator/target actions
such as file transfer. Store them under `script/combo/` so they remain ordinary
payload files and continue to use the shared renderer.

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
script/combo/shell/powercat-rev-cmd-TCKL
script/combo/shell/powercat-rev-ps-TCKL
```

Combo files should keep executable command text in the body and avoid Markdown
fences or long prose in copied output. Use concise `# stage:` metadata to mark
each operator/target step:

```text
# description: Kali send to Target
# stage: Target PowerShell: receive file to TEMP
$RFILE="${file:t}"
$OUTFILE = Join-Path $env:TEMP "$RFILE"
powercat -l -p $rport -of $OUTFILE

# stage: Kali shell: send file and close connection
nc -q 0 $rhost $rport < $file
nc -N $rhost $rport < $file
```

`# stage:` lines are not emitted literally. During preview, print, copy, and
file output, each stage becomes a paste-safe shell comment delimiter:

```text
# --- Target PowerShell: receive file to TEMP ---
```

The emitted delimiter uses `#` because it is valid in both PowerShell and common
Linux shells. Keep stage labels short and action-oriented, and name the side and
shell when that matters.

Uppercase shell variables such as `$RFILE` and `$OUTFILE` intentionally stay
unrendered. Use them when the target shell should expand or assign the value at
runtime. Use lowercase render tokens such as `$file`, `${file:t}`, `$lhost`,
`$lport`, `$rhost`, and `$rport` only for values that `ii` should resolve before
copying.
