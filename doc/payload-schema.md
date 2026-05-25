# Payload Schema

Payload files are plain text templates under `II_PAYLOAD_DIR`. The selector
entry is the file path relative to `II_PAYLOAD_DIR`.

This schema covers stored payload files only. Pasted input rendering with
`ii p --input` has separate rules documented in [usage.md](usage.md).

For documentation and external tooling, treat each payload file as this logical
object:

```json
{
  "$schema": "https://example.invalid/ii/payload.schema.json",
  "path": "shell/linux/sh-tcp",
  "description": "optional first-line metadata without the prefix",
  "body": "payload text copied after rendering",
  "variables": ["II_LHOST", "II_LPORT"]
}
```

Field meanings:

| Field | Source | Required | Notes |
| --- | --- | --- | --- |
| `$schema` | Documentation/tooling | No | Identifies this logical schema. It is not written into payload files. |
| `path` | Relative file path | Yes | Also used as the fzf selector entry and category filter input. |
| `description` | First line | No | Only recognized when line 1 starts with `# description:`. It is shown in preview and omitted from copied output. |
| `body` | Remaining text | Yes | Copied after `${II_*}` placeholders are rendered. |
| `variables` | Body scan | No | Uppercase `II_*` placeholders used by the renderer. |

Recognized payload file syntax:

```text
# description: optional operator-facing description
payload body with ${II_LHOST}, ${II_LPORT}, or literal shell variables like $file
```

Only `${II_NAME}` or bare `II_NAME` placeholders are rendered from tmux session
variables. Missing values fall back to lowercase shell references such as
`$lhost`. Literal lowercase variables such as `$file`, `$rhost`, and `$mm` are
kept unchanged.
