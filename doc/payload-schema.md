# Payload Schema

Payload files are plain text templates under `II_PAYLOAD_DIR`. The selector
entry is the file path relative to `II_PAYLOAD_DIR`.

This schema covers stored payload files. Pasted input with `ii p --input` uses
the same render rules, but it does not have path or first-line description
metadata.

For documentation and external tooling, treat each payload file as this logical
object:

```json
{
  "$schema": "https://example.invalid/ii/payload.schema.json",
  "path": "shell/linux/sh-tcp",
  "description": "optional first-line metadata without the prefix",
  "body": "payload text copied after rendering",
  "variables": ["II_LHOST", "II_LPORT", "rhost"]
}
```

Field meanings:

| Field | Source | Required | Notes |
| --- | --- | --- | --- |
| `$schema` | Documentation/tooling | No | Identifies this logical schema. It is not written into payload files. |
| `path` | Relative file path | Yes | Also used as the fzf selector entry and category filter input. |
| `description` | First line | No | Only recognized when line 1 starts with `# description:`. It is shown in preview and omitted from copied output. |
| `body` | Remaining text | Yes | Copied after renderable placeholders are rendered. |
| `variables` | Body scan | No | Uppercase `II_*` and lowercase shell-style placeholders used by the renderer. |

Recognized payload file syntax:

```text
# description: optional operator-facing description
payload body with ${II_LHOST}, $rhost, ${file}, or ${file:t}
```

Payload files render `${II_NAME}`, bare `II_NAME`, `$name`, `${name}`, and
`${name:t}` through the shared renderer. A non-empty lowercase shell variable
wins first, then the matching tmux `ii_` variable is used. Uppercase shell
variables such as `$RHOST` are left unchanged. Missing values keep the original
token and are reported in red.

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
| `TOOL` | Primary tool or tool family. | `powercat`, `lin-nc`, `lin-busybox-nc` |
| `DIRECTION` | Data direction. | `K2T` = Kali sends to target, `T2K` = target sends to Kali |
| `FLOW` | Listener/connector roles. | `KLTC` = Kali listens and target connects, `TLKC` = target listens and Kali connects |

Use `K` for Kali/operator side and `T` for target side. Use `L` for the side
that listens and `C` for the side that connects. The sender/receiver meaning
comes from `DIRECTION`; the network connection shape comes from `FLOW`.

Examples:

```text
script/combo/trans/powercat-K2T-TLKC
script/combo/trans/powercat-K2T-KLTC
script/combo/trans/powercat-T2K-KLTC
script/combo/trans/lin-nc-K2T-TLKC
script/combo/trans/lin-nc-T2K-KLTC
script/combo/trans/lin-busybox-nc-K2T-TLKC
script/combo/trans/lin-busybox-nc-T2K-KLTC
```

Combo files should keep executable command text in the body and avoid Markdown
fences or long prose in copied output. Use metadata lines for structure:

```text
# description: Kali send to Target
# stage: Target receive
$RFILE="${file:t}"
$OUTFILE = Join-Path $env:TEMP "$RFILE"
powercat -l -p $rport -of $OUTFILE

# stage: Kali send
nc -q 0 $rhost $rport < $file
nc -N $rhost $rport < $file
```

`# stage:` is reserved for combo-aware formatting. Stage labels should be shown
as blue bold headings before their rendered commands when combo formatting is
implemented.

Uppercase non-`II_` variables such as `$RFILE` and `$OUTFILE` intentionally stay
unrendered. Use them when the target shell should expand or assign the value at
runtime. Use lowercase render tokens such as `$file`, `${file:t}`, `$lhost`,
`$lport`, `$rhost`, and `$rport` only for values that `ii` should resolve before
copying.
