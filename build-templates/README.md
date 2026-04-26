# build-templates

Per-language `build.sh` templates to copy into a project and adapt.

## Structure

- `supports-crosscompiling/` — languages/strategies that can produce both Linux and Windows binaries from a single Linux job (using cross-compilation toolchains).
- `no-crosscompiling/` — languages/strategies that require a native runner per target platform.

## Default behaviour

All templates ship with `BUILD_LINUX=1` and `BUILD_WINDOWS=1`. Each script separates platform logic into clearly marked blocks:

```
===== LINUX BUILD START/END =====
===== WINDOWS BUILD START/END =====
```

To target only one platform you have two options:
1. Delete the block for the platform you don't need.
2. Keep it and let the workflow drive it with `BUILD_LINUX=0` or `BUILD_WINDOWS=0`.

## Usage

1. Copy the appropriate template to `./build.sh`.
2. Adjust project variables (`APP_NAME`, `ENTRY_POINT`, etc.).
3. Review the Linux/Windows blocks and remove anything you don't need.
4. Make sure all release artifacts end up in `dist/`.
5. Verify the contract rules in `../BUILD_CONTRACT.md`.

## Important note

Some stacks (e.g. Python + PyInstaller) have no official Linux → Windows cross-compilation path within the same job. In those cases the template fails with a clear error message that tells you to either use a native Windows runner or disable `BUILD_WINDOWS`.
