# Scripts for vChewing-macOS Repository

This folder contains `vchewing-update.swift` which automates the following project maintenance tasks:

- Run `make update` to update submodule lexicons.
- Commit submodule updates using `Update Data - YYYYMMDD` commit message.
- Detect the highest git tag and bump the patch version. Supports `-legacy` suffix.
- Compute a build number: major*1000 + minor*100 + patch*10.
- Run `BuildVersionSpecifier.swift` with the computed version/build number.
- Commit version bump using `[VersionUp] <version> GM Build <build>.` and create the corresponding tag.
- Revert only `Update-Info.plist` to its parent commit state and commit the revert as `[SUPPRESSOR]`.

Usage:
```pwsh
# from the repo root
chmod +x Scripts/vchewing-update.swift
Scripts/vchewing-update.swift --path .

# developments and safety options
Scripts/vchewing-update.swift --path . --dry-run   # does not make changes
Scripts/vchewing-update.swift --path . --push      # enable push after manual confirmation
```

Notes & Safety:
- This script does NOT run `git push` by default to avoid accidental remote changes.
- The script assumes the repo root contains `BuildVersionSpecifier.swift` and `Update-Info.plist`.
- The script detects submodule changes using `git status --porcelain` and checks for `Source/Data` and `DictionaryData` paths; adjust if submodules differ.
 - The script reads the current version and build number directly from the repo's Xcode project (`project.pbxproj`) and will base the new version bump on that.
 - The script detects submodule changes using `git submodule status --recursive` and will commit any updated submodule pointers as a separate `Update Data - YYYYMMDD` commit before the `[VersionUp]` commit. If any submodule changes still remain before the `[VersionUp]` commit, the script will abort to avoid merging them into the version commit.
- `git checkout HEAD~1 -- Update-Info.plist` reverts the file from the previous commit — ensure the HEAD commit is the VersionUp commit.

Requirements:
- macOS with `swift` command available.
- Git in PATH and repo is clean (or you accept the script's behavior).

For usage on the legacy repository, see `../vChewing-OSX-legacy/Scripts/vchewing-legacy-update.swift` as a reference.

Makefile usage:
```pwsh
# Dry run
$env:DRY_RUN='true'; make gitrelease

# Run the script (no push to remote by default)
make gitrelease
```
