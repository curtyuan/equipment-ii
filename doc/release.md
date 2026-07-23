# Release Process

`VERSION` is the source of truth for releases and follows SemVer:

```text
MAJOR.MINOR.PATCH
```

## Bump Version

Use the dedicated version script:

```zsh
./script/version patch  # 0.1.0 -> 0.1.1
./script/version minor  # 0.1.0 -> 0.2.0
./script/version major  # 0.1.0 -> 1.0.0
```

Commit the changed `VERSION` file before tagging.

## Build Package

Build the deployable plugin package:

```zsh
./script/make
```

This creates `export/ii`, which is the deployment unit:

```text
export/ii/
  ii.plugin.zsh
  lib/
  payloads/
  script/ii-tmux-pice
  script/ii-tmux-workflow
  README.md
  VERSION
  RELEASE
```

## Tag Release

Create a release by committing `VERSION` and pushing a matching tag:

```zsh
./script/version minor
git add VERSION
git commit -m "Release v0.2.0"
git tag v0.2.0
git push origin master --tags
```

The release workflow checks that the tag matches `VERSION`, builds `export/ii`,
and publishes `ii-VERSION.tar.gz` plus `ii-VERSION.zip`.
