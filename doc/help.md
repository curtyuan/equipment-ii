# Help System

Live command help belongs in the same feature layer as the command
implementation. The shared registry stores routing metadata only; it does not
own or duplicate help text.

## Output Contract

Every command help follows this order:

```text
usage: executable command forms

Aliases:
  true alternative command names, or none

Help:
  representative ways to open this help
```

Alias names in the `Aliases:` section are cyan when shared color policy enables
ANSI output. Only the alias column is colored; annotations, `none`, usage,
help routes, and descriptions remain unchanged. `II_COLOR` and `NO_COLOR`
control this formatting through `lib/color.zsh`.

The sections have distinct meanings:

- `usage` contains commands that can actually be executed, including arguments.
- `Aliases` contains only alternative command or option names. It never contains
  positional arguments, complete invocations, registry topics, or help routes.
- `Help` contains representative `ii help ...` routes. A canonical audit topic
  may appear here, but it is not presented as a command alias.
- A parent command's help enumerates every direct child path and fixed alias.
  For example, `ii p --help` lists each input flag combination together with
  `pic`, `pie`, and `pice`; each child route then provides its own detailed
  help.

For example:

```text
usage: ii p --www ln SOURCE_PATH [LINK_NAME]
       ii payload --www ln SOURCE_PATH [LINK_NAME]

Aliases:
  none

Help:
  ii help payload --www ln
  ii help payload-www-ln
```

`p` is an alias of the parent `payload` command. The complete
`ii payload --www ln ...` line is a usage variant, and `payload-www-ln` is a
canonical help topic. They are deliberately not mixed in `Aliases`.

An alias may also carry fixed options when that behavior is explicit. For
example, `ii pic` means `ii payload --input --copy`; its remaining arguments are
forwarded to the same payload-input handler.

The same rule applies to a fixed operand. `ii sr VALUE` means
`ii set rhost=VALUE`; it does not expose a general variable-name argument.
`ii sf [PATH]` means `ii set --from-file [PATH]`, and `ii sha` means
`ii set --from-shell -a`; `sha` accepts no arguments.
Likewise, `ii gr` and `ii gl` mean `ii g r` and `ii g l`, selecting rhost and
lhost respectively.
`ii vo [PATH]` similarly means `ii v --out [PATH]`. The older `ii voc [PATH]`
form remains available as a compatibility alias.
`ii pe [KEYWORD ...]` means `ii p --execute [KEYWORD ...]`.
`ii pce [KEYWORD ...]` means
`ii p --copy --execute [KEYWORD ...]`; `c` always means copy.
`ii pie` means `ii p --input --execute` and accepts no arguments.
`ii pice` means `ii p --input --copy --execute` and accepts no arguments.
`ii pc [KEYWORD ...]` means `ii p --copy [KEYWORD ...]`.

## Registration Model

`lib/help_registry.zsh` provides a thin metadata registry:

```zsh
ii_help_register TOPIC HANDLER [ROUTE...]
```

- `TOPIC` is the canonical name printed by `ii_help_topics` and audited by
  `script/help`.
- `HANDLER` is a function in the feature layer that accepts `--help`.
- Each `ROUTE` is another path accepted after `ii help`.

Simple command registration stays beside its implementation:

```zsh
ii_help_register get ii_cmd_get g
```

Nested routes can have multiple words:

```zsh
ii_help_register payload-www-ln ii_cmd_payload_www_ln \
  "payload --www ln" "payload www ln" "p --www ln" "p www ln"
```

The dispatcher uses longest-path matching. This lets
`ii help payload --www ln` select the `ln` help before the broader
`payload --www` route.

The help registry is independent of `lib/core.zsh`: registering a help route
does not create an executable command alias.

Registrations are rejected when a topic uses a different handler, a route is
already owned by another topic, a route is empty, or the handler is unavailable.
Validation completes before registry state is changed, so a rejected
registration cannot leave a partial topic behind.
The plugin entrypoint aborts before loading the public dispatcher when any help
registration reports an error.

## Adding or Changing Help

When a command changes:

1. Update the command's `--help` heredoc in the same feature file. Every public
   command and fixed child path must expose the same help through both `-h` and
   `--help` without entering normal execution.
2. Keep `usage`, `Aliases`, and `Help` semantically separate.
3. Add or update the nearby `ii_help_register` call when its topic or routes
   change.
4. Update user-facing behavior in `usage.md` or the relevant focused document.
5. Run `./script/help` and the checks in `testing.md`. The audit covers
   canonical `ii help ...` routes plus `-h` and `--help` for dispatcher aliases
   and fixed child paths.

Do not add feature-specific routing branches to `lib/help.zsh` or duplicate live
help text in `script/help`.

## Ownership

```text
lib/help_registry.zsh  generic registration, lookup, and topic enumeration
lib/help.zsh           top-level ii help summary
feature layer          command help text and its registration call
script/help            repository audit over canonical topics
doc/help.md            help conventions and maintainer workflow
```
