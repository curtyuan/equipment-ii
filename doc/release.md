# Release Process

`VERSION` is the source of truth for releases and follows SemVer:

```text
MAJOR.MINOR.PATCH
```

## Bump Version

Edit the root `VERSION` with the next SemVer value:

```text
MAJOR.MINOR.PATCH
```

Automated Go version bump tooling has not migrated yet. Commit the changed root
`VERSION` file before tagging.

## Build Package

Build the current Go deployment package:

```zsh
make
```

This creates `export/ii`, which is the deployment unit:

```text
export/ii/
  ii.plugin.zsh
  ii-go
  lib/
  payloads/
  script/ii-tmux-popup
  README.md
  VERSION
  RELEASE
```

## Tag Release

Create a release by committing `VERSION` and pushing a matching tag:

```zsh
printf '%s\n' 0.3.0 > VERSION
git add VERSION
git commit -m "Release v0.3.0"
git tag v0.3.0
git push origin master --tags
```

The release workflow checks that the tag matches `VERSION`, builds a static
Linux amd64 deployment package, and publishes:

```text
ii-VERSION-linux-amd64.tar.gz
ii-VERSION-linux-amd64.zip
```

Each archive has the same top-level `ii/` deployment directory and contains a
Linux amd64 `ii-go` binary.
