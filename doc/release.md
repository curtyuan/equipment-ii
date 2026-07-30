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

Do not update `ori-ii/VERSION`; it identifies the immutable legacy baseline.
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
  ori-ii/
  README.md
  VERSION
  RELEASE
```

During migration, `ori-ii/` is included as the explicit bridge for command
families that have not moved to Go. It disappears from this package when the
last legacy route is removed.

The immutable pre-Go package has a separate build boundary:

```zsh
./ori-ii/script/make
```

It writes only `ori-ii/export/ii`; root `make` never overwrites that directory.

## Tag Release

Create a release by committing `VERSION` and pushing a matching tag:

```zsh
printf '%s\n' 0.3.0 > VERSION
git add VERSION
git commit -m "Release v0.3.0"
git tag v0.3.0
git push origin master --tags
```

The release workflow checks that the tag matches `VERSION`, builds static Linux
amd64 and arm64 deployment packages, and publishes:

```text
ii-VERSION-linux-amd64.tar.gz
ii-VERSION-linux-amd64.zip
ii-VERSION-linux-arm64.tar.gz
ii-VERSION-linux-arm64.zip
```

Each archive has the same top-level `ii/` deployment directory and contains an
`ii-go` binary matching the architecture in its filename.
