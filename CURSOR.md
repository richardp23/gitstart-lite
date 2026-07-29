# Cursor Project Instructions for GitStart

Version: 0.3.1
Date: 2026-07-28

## 1. Mission

Build GitStart as a safe Bash teaching tool.

GitStart shall help a student learn Git by typing real Git commands. The tool shall validate the typed command. The tool shall run a predefined safe operation. The tool shall inspect the result before it continues.

The minimum viable product shall start from one command. It shall have no student runtime dependency other than Bash and Git.

## 2. Read order

Before you change code, read these files in this order:

1. `SRS.md`
2. `AGENTS.md`
3. `CURSOR.md`
4. the files that the task changes
5. the related tests

`SRS.md` is the source of truth for product behavior.

`AGENTS.md` is the source of truth for implementation structure, design decisions, and MVP progress.

This file defines how you shall work in this repository.

When two instructions conflict, use this order:

1. A direct instruction from the project owner.
2. `SRS.md`.
3. `AGENTS.md`.
4. `CURSOR.md`.
5. existing code conventions.

Do not change a requirement silently. Report the conflict.

## 3. Language requirement

Use ASD-STE100 Simplified Technical English principles for:

- documentation.
- comments.
- user-interface text.
- help text.
- warnings.
- errors.
- test descriptions when practical.

Use these project rules:

1. Use short sentences.
2. Use the active voice when possible.
3. Give one instruction in each sentence.
4. Use one term for one item.
5. Define a new technical term.
6. Use a project-approved technical noun when necessary.
7. Do not use idioms.
8. Do not use jokes in errors.
9. Give a safe next action after an error.
10. Do not claim formal STE certification.

Before you finish a task, review each new user-facing sentence for these rules.

## 4. Product constraints

Do not add a student runtime dependency.

Do not require:

- Go.
- Python.
- Node.js.
- `jq`.
- `fzf`.
- GitHub CLI.
- a package manager.

You can use development tools in tests and continuous integration. A student shall not need these tools to run `dist/gitstart.sh`.

Support Bash 3.2 or later.

Do not use Bash 4-only or Bash 5-only features.

The final release shall be one Bash file.

## 5. Safety rules

These rules are mandatory.

### 5.1 Do not execute student text

Do not use:

```bash
eval "$student_input"
bash -c "$student_input"
sh -c "$student_input"
```

The typed command is a knowledge check. It is not executable code.

After validation, call a predefined function with a fixed argument structure.

### 5.2 Treat user values as data

Treat these values as data:

- paths.
- commit messages.
- branch names.
- remote URLs.
- search text.

Quote each value.

Use `--` before a user-controlled path when the command supports it.

### 5.3 Do not add destructive operations

Do not add or expose:

```text
git push --force
git reset --hard
git clean -fd
git restore .
git checkout -- .
git branch -D
```

Do not resolve merge conflicts automatically.

Do not merge unrelated histories.

Do not replace an existing remote without an explicit approved requirement.

### 5.4 Protect credentials and files

Do not request a password or token.

Do not print a credential-bearing remote URL.

Do not read the contents of a suspected secret file.

Do not upload repository data.

Do not add telemetry.

## 6. Work method

For each task, use this sequence.

### Step 1: Identify requirements

List the SRS requirement IDs that apply to the task.

Do not implement a feature that has no requirement. Add or request a requirement first.

### Step 2: Inspect the current code

Read the complete function that you will change.

Read its callers.

Read its tests.

Do not assume that a function name describes all behavior.

### Step 3: Plan the smallest change

Keep the task inside the requested scope.

Do not refactor unrelated code.

Do not add a framework.

Do not add a dependency when Bash can meet the requirement safely.

### Step 4: Implement

Follow `AGENTS.md`.

Keep data output separate from display output.

Check each command status explicitly.

Inspect Git state after a state-changing command.

### Step 5: Test

Run the narrowest relevant tests first.

Then run the complete test suite.

Run at least:

```bash
bash -n dist/gitstart.sh
```

Run ShellCheck when it is available.

### Step 6: Review text

Review new user-facing text for STE rules.

Check that each error has a safe next action.

Check that color is not the only state indicator.

### Step 7: Report

Report:

- the requirement IDs.
- the files that changed.
- the tests that ran.
- the test result.
- any known limitation.
- any manual test that remains necessary.

Do not state that a test passed when you did not run it.

## 7. Implementation rules

### 7.1 Shell compatibility

Use `#!/usr/bin/env bash` in the release.

Use Bash 3.2-compatible syntax.

Do not use associative arrays.

Do not use `mapfile` or `readarray`.

Do not require GNU-only command flags without a fallback.

Use `printf` for controlled output.

Quote variable expansions.

Use `local` for function variables.

Use a project prefix for mutable global variables.

### 7.2 Error handling

Do not depend on `set -e` for normal control flow.

Check the exit status of an important command.

Use an error code from the project diagnostic groups.

Each user error shall contain:

1. The failed operation.
2. The known reason.
3. The safety status of the student's work.
4. One safe next action.
5. A diagnostic code.

### 7.3 Git commands

Put all Git execution in the Git execution module.

Prefer machine-readable Git output.

Do not parse localized human-readable output when a stable format exists.

Use a new state inspection after a Git change.

Do not assume that the branch is named `main`.

Do not assume that a remote is named `origin` unless the lesson first confirms it.

### 7.4 Directory code

Do not parse `ls` output.

Do not recursively scan a full drive.

Store a display label separately from its full path.

Test paths that contain spaces.

Test a directory that has no child directory.

Test hidden-directory behavior.

### 7.5 User interface

Use semantic UI functions.

Do not put raw color codes in lesson files.

Support:

- normal color mode.
- no-color mode.
- plain mode.
- ASCII mode.
- no-animation mode.

Do not use the alternate terminal screen in the minimum viable product.

Restore the terminal after Ctrl+C.

## 8. Test requirements

Add tests with each behavior change.

Use local temporary repositories and local bare remotes.

Do not require a live GitHub account for the normal test suite.

At minimum, test:

- the successful path.
- one invalid input.
- one command failure.
- one safety stop.
- one path with spaces when a path is involved.
- no-color output when user text is involved.

A bug fix shall include a test that fails before the fix and passes after the fix.

Name the applicable requirement IDs in the test name or comment.

Do not delete a failing test only to make the test suite pass.

## 9. Scope control

The following items are future work unless the project owner requests them:

- a Go terminal application.
- pull request creation.
- full branch lessons.
- merge conflict resolution.
- rebase lessons.
- SSH setup.
- recursive fuzzy file search.
- mouse input.
- plugin support.
- automatic repository creation through an API.
- grading.
- telemetry.

Do not implement these items during an MVP task.

You can add an interface seam for a future feature only when the current requirement needs that seam. Keep the seam small.

## 10. Documentation rules

Update documentation when behavior changes.

Keep `SRS.md` requirement IDs stable. Do not reuse a deleted ID for a different requirement.

Add a new ID when you add a requirement.

Mark a changed requirement in the document history.

Update `AGENTS.md` when the architecture, decisions, or module status changes.

Update `CURSOR.md` only when the agent workflow changes.

## 11. Build and release rules

Do not edit `dist/gitstart.sh` by hand when it is a generated file.

Change the source modules. Run the build.

The build shall produce:

```text
dist/gitstart.sh
dist/gitstart.sh.sha256
```

The release shall use LF line endings.

Do not deploy when tests fail.

Do not change the stable version before the versioned artifact exists.

Follow D-016 in `AGENTS.md` for version bumps. GitStart Lite stays
on major `0` unless the project owner declares a classroom-stable
`1.0.0`.

## 12. Required response format for code tasks

Use this structure in the final task report:

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

Keep the report factual.

Do not include a test result that you did not observe.

## 13. Stop conditions

Stop and report the issue when:

- the requested change conflicts with `SRS.md`.
- the change needs a new runtime dependency.
- the change needs a destructive Git command.
- the change cannot support Bash 3.2.
- the correct behavior is ambiguous and a wrong choice can cause data loss.
- a test shows possible data loss.
- credentials appear in output.

Do not make a silent safety exception.

## 14. Completion checklist

Before you mark a task complete, confirm:

- The code maps to named requirements.
- The code is compatible with Bash 3.2.
- The code adds no student runtime dependency.
- The code does not execute student input.
- The code adds no destructive Git operation.
- Paths and values are quoted.
- Git state is verified after a change.
- Terminal cleanup still works.
- New tests pass.
- Existing tests pass.
- User text follows the project STE rules.
- Documentation is current.
