# Build contract

This file is the contract between **the release workflow** and **your `build.sh`**.
Every build script in `build-templates/` is divided into three zones — keeping the
🔒 zones intact is what makes the whole pipeline reproducible.

---

## The three zones

```
🔒 LAUNCHER CONTRACT    ← do not edit, the workflow depends on this
⚙️  PROJECT CONFIG       ← fill in for your project (variables, flags, paths)
🔨 BUILD STEPS          ← edit / add / remove freely
```

Every script starts with a 🔒 block (env contract + binary checks), has an ⚙️
block in the middle (knobs you tune), then a 🔨 block (actual compile commands),
and ends with another 🔒 block (output asserts).

---

## The contract — what NOT to change

### Inputs (set by the workflow, read by your script)

| Variable        | Type          | Meaning                                          |
| --------------- | ------------- | ------------------------------------------------ |
| `APP_VERSION`   | string        | Tag version, no `v` prefix (`1.2.3`)             |
| `APP_NAME`      | string        | Binary filename (no extension)                   |
| `BUILD_LINUX`   | `0` \| `1`    | Whether this run should produce a Linux binary   |
| `BUILD_WINDOWS` | `0` \| `1`    | Whether this run should produce a Windows binary |

These are exported by the workflow's `plan` job. Renaming them, hard-coding
them, or removing the `${VAR:-default}` shell pattern will break the launcher's
ability to reconfigure the build.

### Output convention

| Platform | File                  | Notes                  |
| -------- | --------------------- | ---------------------- |
| Linux    | `dist/<APP_NAME>`     | ELF binary, executable |
| Windows  | `dist/<APP_NAME>.exe` | PE/COFF executable     |

Languages that produce a portable artefact (Java JAR, Ruby gem, PHP PHAR) ship
that file alongside per-OS launcher wrappers (`dist/<APP_NAME>` shell +
`dist/<APP_NAME>.bat`).

The `dist/` directory is the **only** place the release job looks. Anything you
write outside `dist/` is invisible to the release.

### Forbidden in commits

The repo's `.gitignore` blocks `dist/`, `*.exe`, `*.deb`, `*.o`, `*.so`, `*.bin`,
`*.out`. The launcher's "Publish release" button additionally refuses to publish
if it detects any of these untracked.

### Exit codes

- `0` — both requested platforms produced the expected file
- non-zero — workflow fails, no release is produced

The 🔒 closing block of every script asserts that the binaries exist for every
platform that was requested. **Do not weaken these asserts** — they are the only
thing protecting you from a half-broken release.

---

## What you CAN change freely

Inside the ⚙️ and 🔨 blocks, anything goes:

- Pick a different build system (replace CMake with Meson, Maven with Gradle, etc.)
- Add `--features`, `-tags`, `--add-data`, `--hidden-import`, link flags
- Bundle assets, sign binaries, run code generation steps
- Delete the `BUILD_LINUX` block if you only ship Windows (or vice versa)
- Cross-compile a normally-native language (Python with Nuitka, C with mingw)

When you delete a platform block, also set `BUILD_LINUX=0` (or `BUILD_WINDOWS=0`)
in the workflow's `plan` job so the matching CI job is skipped.

---

## Cross-compiling vs native dual-runner

The workflow picks one of two strategies based on `PROJECT_LANG`:

| Strategy            | Languages                                | Runners                     |
| ------------------- | ---------------------------------------- | --------------------------- |
| **Cross-compiling** | go, rust, node, dotnet, java, ruby, php  | one Linux job               |
| **Native dual-run** | python, c, cpp                           | one Linux + one Windows job |

Cross-compiling languages run a single `build_cross` job on Linux and produce
both binaries from there. Native languages need their own runner per OS — the
workflow spins up `build_native_linux` and `build_native_windows` separately.

**Where does my build template live?**

- Cross-compilers: `build-templates/supports-crosscompiling/build.<lang>.sh`
- Natives:         `build-templates/no-crosscompiling/build.<lang>.sh`

If you switch a project from native to cross-compile (or back), copy the
appropriate template over your existing `build.sh`.

---

## Languages currently supported

| `PROJECT_LANG` | Tooling                 | Strategy        |
| -------------- | ----------------------- | --------------- |
| `go`           | `go build`              | cross-compile   |
| `rust`         | `cargo` + mingw         | cross-compile   |
| `node`         | `vercel/pkg`            | cross-compile   |
| `dotnet`       | `dotnet publish` (RIDs) | cross-compile   |
| `java`         | Maven/Gradle → JAR      | cross-compile   |
| `ruby`         | `gem build`             | cross-compile   |
| `php`          | Composer → PHAR         | cross-compile   |
| `python`       | PyInstaller             | native dual-run |
| `c`            | Make (default)          | native dual-run |
| `cpp`          | CMake (default)         | native dual-run |

---

## Windows .exe icons (Go projects)

Drop an **`icon.ico`** at one of these paths and `build.go.sh` will embed it
automatically into the Windows binary as a PE32 resource:

- `<repo>/icon.ico`
- `<repo>/assets/icon.ico`
- `<repo>/<BUILD_PACKAGE>/icon.ico` (next to your `package main`)

Behind the scenes, the script auto-installs
[`rsrc`](https://github.com/akavel/rsrc) into `.go/bin/`, generates a
`rsrc_windows.syso` file, runs the build, and removes the `.syso` on exit
(via `trap`). Linux builds aren't affected because the `_windows` suffix
restricts the resource to that GOOS.

If you only have a PNG, convert it once with ImageMagick:

```bash
magick icon.png -define icon:auto-resize=16,32,48,256 icon.ico
```

The 16/32/48/256 set covers File Explorer, taskbar, alt-tab and high-DPI
displays. Commit the `.ico` next to the `.png`.

> Note: this only handles the **Windows .exe icon** (visible in File Explorer
> and shortcuts). For the **runtime icon** (window title bar, taskbar while
> running) you also need `fyne.App.SetIcon(...)` in your code — that's
> per-language and has nothing to do with the workflow.
>
> Linux uses `.desktop` entries (the `.deb` step can install one). macOS uses
> `.app` bundles. If you need either, the build steps zone is the place.

---

## Adding a new language

1. Drop a `build.<lang>.sh` into the right `build-templates/` subdir, copying
   the three-zone layout from any existing template.
2. Add `<lang>` to the `PROJECT_LANG` validation case in
   `.github/workflows/release.yaml` and `.gitea/workflows/release.yaml`.
3. Add it to the `CROSS_SUPPORTED` switch in the same file.
4. Add a setup step (toolchain install) for the appropriate native job(s).
5. Add the language to the launcher's `langSelect` list (`internal/launcher/app.go`)
   and to `crossCompilingLanguages` map (`internal/launcher/template.go`) if it
   cross-compiles.
