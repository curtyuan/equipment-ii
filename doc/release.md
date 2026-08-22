# Release Process

`VERSION` is the source of truth for releases and follows SemVer:

```text
MAJOR.MINOR.PATCH
```

Releases support Linux amd64 only. The project does not build or publish
packages for other operating systems or architectures.

## Bump Version

Edit the root `VERSION` with the next SemVer value:

```text
MAJOR.MINOR.PATCH
```

Automated Go version bump tooling has not migrated yet. Commit the changed root
`VERSION` file before tagging.

## Build Package

Build the sole deployment package:

```zsh
make
```

This creates `export/ii`, which contains a statically linked Linux amd64 helper
and is the deployment unit:

```text
export/ii/
  ii.plugin.zsh
  ii-go
  lib/
  script/ii-tmux-popup
  payloads/
  help/
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
Linux amd64 deployment package, loads the packaged plugin in a smoke test, and
publishes:

```text
ii-VERSION-linux-amd64.tar.gz
ii-VERSION-linux-amd64.zip
ii-linux-amd64.tar.gz
ii-linux-amd64.zip
SHA256SUMS
```

Each archive has the same top-level `ii/` deployment directory and contains a
Linux amd64 `ii-go` binary. Versioned assets support pinned downloads. The
stable names support GitHub's `releases/latest/download/ASSET` URLs without
requiring clients to discover the current version first. `SHA256SUMS` covers
both archive name forms. Users install by downloading and extracting an archive;
the release does not publish or require an installer script.
