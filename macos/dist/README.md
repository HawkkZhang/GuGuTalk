# Local Build Artifacts

All locally generated distributable files should live under this directory.

- DMG files: `dist/dmg/`
- Use `./scripts/package-dmg.sh` to create new DMGs.
- Do not place DMGs in the project root, `Packages/`, Desktop, or random temporary folders.
- Files in `dist/dmg/` are local artifacts and should not be committed.
