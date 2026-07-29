# AGENTS.md

Version: 0.1.0
Date: 2026-07-28

This file is the agent tracking and architecture guide for GitStart Lite.

- `SRS.md` is the source of truth for product behavior.
- This file is the source of truth for implementation structure, design decisions, and MVP progress.
- `CURSOR.md` defines how an agent shall work in this repository.
- `PLAN.md` holds the phase plan. Update this file when module status changes.

When instructions conflict, use this order:

1. A direct instruction from the project owner.
2. `SRS.md`
3. `AGENTS.md`
4. `CURSOR.md`
5. Existing code conventions

Do not change a requirement silently. Report the conflict.

---

## 1. MVP progress tracker

Update the Status column when work starts or finishes.

| Area | Path / item | Status | Requirement IDs |
|------|-------------|--------|-----------------|
| Plan | `PLAN.md` | Done | SRS §17 |
| Header | `src/00_header.sh` | Done | NFR-040 |
| Constants | `src/10_constants.sh` | Done | SRS §12 |
| Terminal | `src/20_terminal.sh` | Done | FR-020–FR-031, FR-040–FR-048 |
| Text UI | `src/30_text.sh` | Done | FR-040–FR-046, NFR-020–NFR-025 |
| Input | `src/40_input.sh` | Done | FR-064–FR-066, FR-075 |
| Picker | `src/50_picker.sh` | Done | FR-060–FR-088 |
| Fuzzy | `src/60_fuzzy.sh` | Done | FR-068–FR-070 |
| Git exec | `src/70_git_exec.sh` | Done | FR-105–FR-108, FR-300–FR-309 |
| Git state | `src/80_git_state.sh` | Done | FR-120–FR-130 |
| Safety | `src/90_safety.sh` | Done | FR-083–FR-085, FR-140–FR-144, FR-300–FR-310 |
| Lesson engine | `src/100_lesson_engine.sh` | Done | FR-050–FR-054, FR-100–FR-113 |
| Lesson: initialize | `src/lessons/initialize.sh` | Done | FR-160–FR-184 |
| Lesson: commit/push | `src/lessons/commit_push.sh` | Done | FR-200–FR-211 |
| Lesson: update | `src/lessons/update_clone.sh` | Done | FR-220–FR-227 |
| Lesson: fork sync | `src/lessons/sync_fork.sh` | Done | FR-240–FR-248 |
| Lesson: diagnose | `src/lessons/diagnose.sh` | Done | FR-260–FR-264 |
| Main | `src/999_main.sh` | Done | FR-050–FR-055 |
| Build | `build.sh`, `Makefile` | Done | NFR-121 |
| Release file | `dist/gitstart.sh` | Done | FR-010, FR-011 |
| Bootstrap | `site/run` | Done | FR-001–FR-009 |
| Pages site | `site/` | Done | FR-012 |
| CI | `.github/workflows/` | Done | NFR-122 |
| Tests | `tests/` | Done | NFR-122, SRS §13 |
| Docs | `README.md`, `GLOSSARY.md` | Done | NFR-125 |

Status values: `Not started` | `In progress` | `Done` | `Blocked`

---

## 2. Product constraints

- Release artifact: one Bash file at `dist/gitstart.sh`.
- Support Bash 3.2 or later.
- Student runtime needs only Bash and Git.
- Do not require Go, Python, Node.js, `jq`, `fzf`, GitHub CLI, or a package manager.
- Optional tools need a built-in fallback.
- Do not use associative arrays, `mapfile`, `readarray`, `globstar`, or negative array indexes.
- Do not use `eval` on student input.
- Do not execute student text as shell code.
- Do not add destructive Git operations.
- Do not request, store, or transmit passwords or tokens.
- Do not add telemetry.
- Use ASD-STE100 Simplified Technical English for comments, UI text, errors, docs, and commit messages that agents create. Do not claim formal STE certification.

Forbidden Git operations in the MVP:

```text
git push --force
git reset --hard
git clean -fd
git restore .
git checkout -- .
git branch -D
```

Do not resolve merge conflicts automatically. Do not merge unrelated histories.

---

## 3. Repository layout

```text
gitstart-lite/
|-- SRS.md
|-- AGENTS.md
|-- CURSOR.md
|-- PLAN.md
|-- README.md
|-- LICENSE
|-- Makefile
|-- build.sh
|-- src/
|   |-- 00_header.sh
|   |-- 10_constants.sh
|   |-- 20_terminal.sh
|   |-- 30_text.sh
|   |-- 40_input.sh
|   |-- 50_picker.sh
|   |-- 60_fuzzy.sh
|   |-- 70_git_exec.sh
|   |-- 80_git_state.sh
|   |-- 90_safety.sh
|   |-- 100_lesson_engine.sh
|   |-- lessons/
|   |   |-- initialize.sh
|   |   |-- commit_push.sh
|   |   |-- update_clone.sh
|   |   |-- sync_fork.sh
|   |   `-- diagnose.sh
|   `-- 999_main.sh
|-- tests/
|   |-- unit/
|   |-- integration/
|   |-- fixtures/
|   `-- manual/
|-- site/
|   |-- index.html
|   |-- run
|   |-- .nojekyll
|   `-- releases/
|-- dist/
`-- .github/
    `-- workflows/
        |-- test.yml
        `-- pages.yml
```

Numeric prefixes define build order. The release shall not depend on source files at runtime.

---

## 4. Module responsibilities

### 4.1 `00_header.sh`

Shebang, metadata, license header. Use `set -u` and `set -o pipefail`. Do not rely on `set -e` for normal teaching control flow.

### 4.2 `10_constants.sh`

Version, diagnostic codes, limits, lesson identifiers. No mutable state.

### 4.3 `20_terminal.sh`

Detect terminal capabilities, width, and color. Save and restore terminal settings. Install cleanup traps for `EXIT`, `INT`, `TERM`, and `HUP`. Do not use the alternate screen in the MVP.

Public functions or equivalents:

```text
terminal_init
terminal_cleanup
terminal_get_width
terminal_supports_color
terminal_supports_single_key
terminal_hide_cursor
terminal_show_cursor
terminal_clear_line
```

`terminal_cleanup` shall be safe when it runs more than one time.

### 4.4 `30_text.sh`

All common UI helpers. Support color and plain output. Put style codes in this module only. Each status needs a text marker such as `[INFO]`, `[SUCCESS]`, `[WARNING]`, `[ERROR]`, `[STOPPED]`, `[NEXT]`.

### 4.5 `40_input.sh`

Read a full line. Read one key when supported. Parse arrow keys. Request yes/no, numbered choice, and text data. Do not interpret input as code.

### 4.6 `50_picker.sh`

Built-in directory picker. List immediate child directories. Support current-directory select, parent navigation, arrows, local search, manual path, hidden toggle, preview, and plain numbered fallback. Do not parse `ls`. Do not scan a full drive. Do not change the parent shell directory.

### 4.7 `60_fuzzy.sh`

Match visible labels only. Score order:

1. Exact full-name match
2. Prefix match
3. Case-insensitive substring match
4. Ordered character match
5. No match

Prefer earlier matches, shorter gaps, then shorter names.

### 4.8 `70_git_exec.sh`

The only module that starts Git commands. Pass arguments separately. Use `--` before user-controlled paths when supported. Sanitize credentials before display. Preserve exit status.

### 4.9 `80_git_state.sh`

Read-only Git inspection. Prefer machine-readable Git output. Reset state variables before each inspection. Use prefixed globals such as `GS_STATE_*`.

### 4.10 `90_safety.sh`

Dangerous directories, nested repos, secret file names, generated directories, existing remotes, incompatible history, diverged branches, and forbidden commands. Do not read secret-file contents.

### 4.11 `100_lesson_engine.sh`

Step model: WHY → TYPE OR CONFIRM → RUN → OBSERVE → EXPLAIN → VERIFY → NEXT.

Student text is a knowledge check. After validation, call a predefined function. Do not execute the typed text.

### 4.12 Lesson modules

Each lesson inspects state, confirms applicability, teaches one command at a time, verifies after each change, stops on unsafe state, and names SRS requirement IDs in its header comment.

---

## 5. Global state and coding rules

Prefixes:

```text
GS_APP_       Application metadata
GS_TERM_      Terminal state
GS_UI_        User-interface state
GS_PICKER_    Picker state
GS_STATE_     Git state
GS_LESSON_    Lesson state
GS_TMP_       Temporary paths
```

- Use `local` for function variables.
- Quote expansions unless intentional word splitting is documented.
- Use `printf` for controlled output.
- Separate data output from display output.
- Check important command exit status explicitly.
- Inspect Git state after a state-changing command.
- Do not assume the branch is named `main` in existing repositories.
- Do not assume a remote is named `origin` until the lesson confirms it.

### Validation

- Paths: quote, use `--` when possible, support spaces, reject non-directories.
- Commit messages: non-empty after trim; treat as data; first line 72 characters or fewer (D-003).
- Remote URLs: HTTPS only in MVP; reject embedded credentials (D-004).
- Branch names: validate with `git check-ref-format` when the tool requests a name.

### Diagnostic code groups

```text
GS-BOOT-*   Bootstrap and download
GS-TERM-*   Terminal input and output
GS-PATH-*   Directory and path
GS-GIT-*    Local Git state
GS-NET-*    Network access
GS-AUTH-*   Remote authentication
GS-SAFE-*   Safety stop
GS-LESSON-* Lesson state
GS-INTERNAL-* Unexpected program state
```

Each error needs: failed operation, known reason, safety status, one safe next action, and a diagnostic code.

---

## 6. Directory picker design

- Collect only immediate child directories.
- Store paths and labels in parallel indexed arrays.
- Search labels; select stored paths.
- Preview limits: 20 entries, depth 1.
- Indicators: `[GIT]`, `[SECRET?]`, `[GENERATED]`, `[WIDE]`.
- Layouts: wide (≥100), normal (70–99), narrow (<70).

Keys when single-key input works:

```text
Up/Down     Move
Enter       Open or run action
Left/Backspace  Parent
/           Local search
.           Toggle hidden
m           Manual path
?           Help
Esc         Back or cancel
q           Quit from top-level
```

---

## 7. Git state classification

Decision order:

1. Is the directory in a Git working tree?
2. Does HEAD identify a commit?
3. Is the working tree clean?
4. Does the branch have a remote?
5. Does the branch have an upstream?
6. Is remote information available?
7. What are the ahead and behind counts?

Relation classes: `EQUAL`, `AHEAD`, `BEHIND`, `DIVERGED`, `UNTRACKED`, `UNKNOWN`.

Logical states from SRS §11 remain the lesson routing source of truth.

---

## 8. Build, bootstrap, and release

`build.sh` shall:

1. Verify source order and existence.
2. Join modules into `dist/gitstart.sh`.
3. Remove duplicate shebang lines.
4. Enforce LF line endings.
5. Run `bash -n`.
6. Run tests when requested.
7. Write `dist/gitstart.sh.sha256`.

Bootstrap (`site/run`) shall:

1. Set the base URL and stable version.
2. Create a temporary directory (D-005).
3. Download the versioned application and checksum.
4. Verify SHA-256 when a checksum command exists.
5. On missing checksum command: warn and require confirmation (D-001).
6. Stop on checksum mismatch.
7. Start the application with Bash and pass options.
8. Remove the temporary directory on exit.

Do not edit `dist/gitstart.sh` by hand when it is generated. Change source modules and rebuild.

Version bumps follow D-016. Release folders use `v` plus
`GS_APP_VERSION` (for example `site/releases/v0.3.1/`).

---

## 9. Design decisions

### D-001 Missing checksum command

Warn and require confirmation before start. Do not continue silently.

### D-002 Default branch after `git init`

Teach `git branch -M main` for new repositories. Detect the active branch in existing repositories. Do not assume `main` elsewhere.

### D-003 Commit message length

First line: 72 characters or fewer. Reject empty or space-only messages.

### D-004 Remote URL policy

Accept HTTPS Git URLs. Reject embedded credentials. Reject SSH in the MVP teaching path. SSH is future work in `SRS.md` (FL-006).

### D-005 Bootstrap cache

Use `mktemp -d` when available. Remove on exit. No persistent cache in the MVP.

### D-006 Stash in update lesson

Offer commit changes or stop and review. Do not offer stash until FL-004 exists.

### D-007 `fzf` usage

Built-in picker is default and fallback. Optional `fzf` may enhance selection among immediate children only.

### D-008 Global Git config consent

Prefer `git config --local`. Offer global config only after explicit consent.

### D-009 Picker screen redraw

During interactive directory picking, clear and redraw one frame after each key.
Do not use the alternate screen.
After the picker exits, drain unread TTY bytes so arrow leftovers do not enter later prompts.

### D-011 Lesson board focus

Redraw a lesson board on each focus change when the terminal is interactive.
Completed steps stay on screen as muted `[ok]` lines.
The current step uses `[NOW]`.
This keeps attention on the active step without deleting the path history.

### D-013 Pause before board advance

Before every lesson board redraw that leaves a finished stage, wait for Enter.
Students need time to read the screen, including command output.

### D-014 Commit message typing forms

Teach `git commit -m "message"` when the message has no double quotes.
Accept the same message with double quotes, single quotes, or backslash escapes.

### D-015 Local app messaging

Do not pitch “offline” as a student-facing feature.
The app runs locally (no telemetry, no phone-home after bootstrap).
Students normally use network for launch and for Git remotes.
Keep clear network-failure messages when a remote step needs a connection.
Instructor download docs may describe a standalone file without leading with “offline.”

---

### D-016 Application versioning (Lite stays on 0.x)

GitStart Lite uses Semantic Versioning as `MAJOR.MINOR.PATCH`.
The source of truth is `GS_APP_VERSION` in `src/10_constants.sh`.

Lite remains on major version `0` while it is a transitional Bash
teaching tool ahead of a planned larger Go app (TUI or GUI).
Do not cut `1.0.0` only to mark Lite maturity. A future Go product
may use its own version line.

While major is `0`:

- **patch**: bug fixes, docs-only changes, chore work, and most
  refactors with no student-facing behavior change
- **minor**: new user-facing capability, lesson or UX behavior
  change, or intentional teaching-flow change
- Treat breaking Lite changes as a **minor** bump (major stays
  `0` until an explicit classroom-stable `1.0.0` decision)

Align bumps with Conventional Commits when practical:
`fix` / `docs` / `chore` / most `refactor` → patch; `feat` → minor.

When you bump the version, also update:

- `Version:` headers in project docs (`AGENTS.md`, `PLAN.md`,
  `CURSOR.md`, `GLOSSARY.md`, `SRS.md`)
- `site/stable.txt` and `site/releases/vX.Y.Z/`
- Site and README download links that name a release path

`make release-site` and the Pages workflow read `GS_APP_VERSION`.
Do not change the stable pointer before the versioned artifact exists.

---

## 10. Deferred work

Keep future lessons and platform features listed in `SRS.md` §14 and §15. Keep them disabled in the MVP. Do not expand MVP scope without documenting the change here and in `SRS.md` when a requirement changes.

Interface seams that may remain ready:

- Lesson engine entry points for new lessons
- Forbidden-command list in the safety module

---

## 11. Test and definition of done

Minimum checks for a behavior change:

- Successful path
- One invalid input
- One command failure
- One safety stop
- Path with spaces when paths are involved
- No-color output when user text is involved

Name requirement IDs in test names or comments.

### Automated versus manual terminal tests

The project does not require a PTY development dependency such as `expect`.

Automated tests may stub `input_read_line` to check lesson validation. Those stubs are not TTY tests.

Interactive checks for `/dev/tty`, `stty`, arrow keys, Ctrl+C cleanup, and the directory picker live in `tests/manual/README.md`. Run them on Git Bash and on macOS Terminal before a classroom release.

ShellCheck is optional when installed. It is not a student runtime dependency.

A task is done only when:

1. Named SRS requirements are implemented.
2. Bash 3.2 compatibility holds.
3. Automated tests pass.
4. Required manual tests pass.
5. ShellCheck has no unexplained new issue when available.
6. User-facing text passes the project STE review.
7. No new runtime dependency exists.
8. No unsafe Git operation was added.
9. This tracker and related docs are current.

### Report format

```text
Requirements
- FR-...
- NFR-...

Changed
- path: short description

Tests
- command: result

Manual checks
- check or `None`

Limitations
- limitation or `None`
```

Do not state that a test passed when you did not run it.
