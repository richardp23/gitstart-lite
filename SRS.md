# GitStart Software Requirements Specification

Document ID: GS-SRS-001  
Version: 0.5.0
Status: Draft for implementation  
Date: 2026-07-30
Primary audience: Project owner, developers, testers, and instructors

## 1. Purpose

This document defines the requirements for GitStart.

GitStart is a local command-line teaching tool. It teaches a student how to use Git from Git Bash on Windows or from a terminal on macOS. The tool guides the student through repository setup, local updates, and remote synchronization.

The first release uses Bash. The release has no required runtime dependency other than Bash and Git.

## 2. Writing standard

All project documentation and all user-facing text shall follow ASD-STE100 Simplified Technical English, Issue 9.

The project shall use these additional rules:

1. Use short sentences.
2. Use the active voice when possible.
3. Give one instruction in each sentence.
4. Use the same term for the same item.
5. Do not use informal idioms.
6. Do not use humor in warnings or error messages.
7. Define a technical term before the first use.
8. Use a project glossary for necessary software terms.
9. Do not claim formal ASD-STE100 certification unless an authorized review confirms it.

Necessary software terms can be project-approved technical nouns. Examples are `Git`, `repository`, `remote`, `branch`, `commit`, `bootstrap`, `fuzzy search`, and `working tree`.

## 3. Product scope

### 3.1 In-scope functions for the minimum viable product

GitStart shall:

- Start from one terminal command.
- run as a local Bash program.
- let the student select a project directory.
- show the files in the selected directory.
- teach `cd` when the selected directory differs from the launch directory.
- verify the working directory with `pwd`.
- inspect the Git state of the directory.
- initialize a new local repository.
- stage files.
- create a commit.
- connect a local repository to a remote repository.
- push a branch to a remote repository.
- save and push changes in an existing repository.
- update an existing clone with a fast-forward operation.
- configure and use an `upstream` remote for a fork.
- stop before a destructive or ambiguous Git operation.
- work without color.
- work without a network connection for local Git lessons.

### 3.2 Out-of-scope functions for the minimum viable product

The minimum viable product shall not:

- create a GitHub repository through an API.
- create a pull request.
- teach a full branching workflow.
- resolve a merge conflict.
- perform a rebase.
- configure SSH keys.
- force-push.
- run `git reset --hard`.
- run `git clean -fd`.
- delete a branch with force.
- grade a student.
- send telemetry.
- install third-party command-line tools.

## 4. Product overview

### 4.1 Product model

GitStart has two parts:

1. A small online bootstrap script.
2. A versioned local Bash application.

The bootstrap script shall download the application and start it. The application shall run on the local machine. The application shall not contact the GitStart host after startup.

Git can contact a remote Git service when the student uses `fetch`, `pull`, or `push`.

### 4.2 Distribution model

GitHub Pages shall host these static files:

- the bootstrap script.
- the versioned application script.
- a checksum file.
- release metadata.
- project documentation.
- offline download instructions.

The normal launch command shall have this form:

```bash
bash -c "$(curl -fsSL https://ACCOUNT.github.io/PROJECT/run)"
```

The project owner can use a custom domain later. A custom domain shall not be a requirement.

### 4.3 Offline model

The complete application shall be available as one Bash file.

A user shall be able to run the file with this command:

```bash
bash gitstart.sh
```

The local lessons shall work without a network connection. A remote Git action can fail when the network is not available. GitStart shall explain this condition and shall preserve all local work.

## 5. Users

### 5.1 Student

A student has little or no Git experience. The student can use Git Bash or a macOS terminal. The student needs direct instructions and clear explanations.

### 5.2 Instructor

An instructor starts the lesson, helps students, and diagnoses blocked states. The instructor can use a diagnostic summary that contains no file contents and no credentials.

### 5.3 Maintainer

A maintainer changes the source files, runs tests, builds one release script, and publishes the release through GitHub Actions.

## 6. Operating environment

### 6.1 Supported systems

The minimum viable product shall support:

- Git Bash on a supported Windows system.
- the system Bash environment on macOS.
- a current Bash environment on Linux for development and tests.

### 6.2 Bash compatibility

The release script shall be compatible with Bash 3.2 or later.

The implementation shall not require:

- associative arrays.
- `mapfile`.
- `readarray`.
- `globstar`.
- negative array indexes.
- a Bash 4 or Bash 5 feature.

### 6.3 Required commands

The application requires:

- `bash`.
- `git` for Git lessons.

The bootstrap requires:

- `curl`.
- a checksum command when checksum verification is available.

The application can use common local commands when they are available. It shall provide a fallback when a nonessential command is not available.

### 6.4 Optional commands

The application can use `fzf` when it is already installed. The application shall not require `fzf`. The application shall not install `fzf`.

## 7. Definitions

**Application**: The complete local `gitstart.sh` file.

**Bootstrap**: The small script that downloads and starts the application.

**Clone**: A local copy of a remote repository.

**Commit**: A saved Git snapshot.

**Current directory**: The directory in which the application starts or operates.

**Fork**: A remote repository that is based on another remote repository.

**Lesson**: A guided sequence that teaches one Git task.

**Origin**: The normal name of the primary remote repository.

**Remote**: A named connection to another Git repository.

**Repository**: A directory that Git tracks.

**Upstream**: The normal name of the original repository for a fork.

**Working tree**: The files that the user can edit in a local repository.

## 8. Functional requirements

The word `shall` identifies a mandatory requirement.

### 8.1 Bootstrap and release

**FR-001** The project shall provide one public launch command.

**FR-002** The launch command shall use HTTPS.

**FR-003** The bootstrap shall be a small Bash script.

**FR-004** The bootstrap shall download a versioned application file.

**FR-005** The bootstrap shall use a temporary directory or a local cache.

**FR-006** The bootstrap shall verify a SHA-256 checksum when a supported checksum command is available.

**FR-007** The bootstrap shall stop when a checksum does not match.

**FR-008** The bootstrap shall keep terminal input connected to the application.

**FR-009** The bootstrap shall pass command-line options to the application.

**FR-013** When the bootstrap cannot download or read `stable.txt`, it shall stop with a clear error that names the `stable.txt` URL and a troubleshooting URL. It shall remove its temporary directory. It shall not fall back to an obsolete release version.

**FR-010** The project shall publish the standalone application file for offline use.

**FR-011** The application shall not require a second download after it starts.

**FR-012** The release process shall support a fixed version and a stable version.

### 8.2 Startup and capability checks

**FR-020** The application shall detect whether standard output is a terminal.

**FR-021** The application shall detect the terminal width when possible.

**FR-022** The application shall detect whether color is permitted.

**FR-023** The application shall disable color when `NO_COLOR` is set.

**FR-024** The application shall support `--no-color`.

**FR-025** The application shall support `--plain`.

**FR-026** The application shall support `--ascii`.

**FR-027** The application shall support `--no-animation`.

**FR-028** The application shall show a readable error when Bash is not compatible.

**FR-029** The application shall show installation guidance when Git is not available.

**FR-030** The application shall restore the terminal state when it exits.

**FR-031** The application shall restore the terminal state after `INT`, `TERM`, and `HUP` signals.

### 8.3 Visual interface

**FR-040** The application shall use color by default when the terminal supports color.

**FR-041** The application shall use text symbols in addition to color.

**FR-042** The application shall show original ASCII or Unicode art at startup.

**FR-043** The application shall use ASCII art when Unicode output is not safe.

**FR-044** The application shall show the current lesson step.

**FR-045** The application shall show completed lesson steps.

**FR-046** The application shall show the next safe action.

**FR-047** The application shall not clear useful command output without user consent.

**FR-048** The application shall not use the alternate screen in the minimum viable product.

### 8.4 Main menu and mode selection

**FR-050** The application shall provide a Learn mode.

**FR-051** Learn mode shall require the student to type each teaching command.

**FR-052** The application shall provide an Assisted mode.

**FR-053** Assisted mode shall show a command and request confirmation before the application runs it.

**FR-054** Learn mode shall be the default mode.

**FR-055** The main menu shall include these choices:

1. Publish an existing directory as a new repository.
2. Save and push changes in an existing repository.
3. update an existing clone.
4. synchronize a fork.
5. diagnose a Git problem.

The menu shall show a short purpose line under each lesson choice so the student can tell local-to-remote work from remote-to-local work and fork sync.

### 8.5 Directory selection

**FR-060** The application shall start the directory picker in the current directory.

**FR-061** The picker shall list the immediate child directories.

**FR-062** The picker shall include an action that selects the current directory.

**FR-063** The picker shall include an action that opens the parent directory.

**FR-064** The picker shall let the user move the selection with the Up Arrow and Down Arrow keys.

**FR-065** The picker shall open a selected directory when the user presses Enter.

**FR-066** The picker shall let the user select the current directory with a clear key or menu action.

**FR-067** The picker shall support manual path entry.

**FR-068** The picker shall support a local search of the visible directory list.

**FR-069** The built-in search shall prefer an exact substring match.

**FR-070** The built-in search shall also support an ordered character match.

**FR-071** The picker shall not scan the full file system by default.

**FR-072** The picker shall let the user show or hide hidden directories.

**FR-073** The picker shall handle a path that contains spaces.

**FR-074** The picker shall not parse the output of `ls` to identify files.

**FR-075** The picker shall provide a plain numbered menu when single-key input is not available.

**FR-076** The application can use `fzf` when `fzf` is already available.

**FR-077** The built-in picker shall remain available when `fzf` is not available.

### 8.6 Directory preview and confirmation

**FR-080** The application shall show the selected path.

**FR-081** The application shall show a limited first-level file preview.

**FR-082** The preview shall show whether a `.git` directory is present.

**FR-083** The preview shall show a warning when a likely secret file is present.

**FR-084** The preview shall show a warning when a generated dependency directory is present.

**FR-085** The application shall warn when the selected directory is a broad or dangerous location.

Examples include the file-system root, the user home directory, and a top-level Desktop or Documents directory.

**FR-086** The application shall ask the user to confirm the selected directory.

**FR-087** After visual selection, the application shall teach `cd` only when the selected directory differs from the current application working directory. When the selected directory equals the current application working directory, the application shall explain that `cd` is not necessary and shall continue to directory verification. When `cd` is taught, a predefined safe runner shall change to the selected directory. The application shall not execute the student text as shell code. The session start directory is separate and shall not decide whether `cd` is required.

**FR-088** On Git Bash, the application shall show a Git Bash path when it can convert the selected Windows path safely.

**FR-089** Displayed `cd` commands shall be valid Bash forms. For the home directory use `cd -- ~`. For a path under the home directory preserve an unquoted `~/` prefix and escape the remainder. For a path outside the home directory use an escaped absolute path. The application shall reject paths that contain unsupported control characters.

### 8.7 Command teaching engine

**FR-100** The application shall show one teaching command at a time.

**FR-101** The application shall explain why the command is necessary.

**FR-102** The application shall explain the expected result.

**FR-103** In Learn mode, the application shall read the command that the student types.

**FR-104** The application shall compare the typed command with an approved command form.

**FR-105** The application shall not execute the typed text as shell code.

**FR-106** The application shall not use `eval` on student input.

**FR-107** The application shall run a predefined function after successful validation.

**FR-108** The application shall pass Git arguments as separate arguments.

**FR-109** The application shall give a useful correction when a command does not match.

**FR-110** The application shall let the student open detailed help for the current command or substep. After help, the application shall return to the same unfinished step without running the command and without marking the step complete.

**FR-111** The application shall let the student stop before the command runs.

**FR-112** The application shall show the command result.

**FR-113** The application shall inspect the Git state after a state-changing command.

**FR-114** When teaching data is available, the normal command screen shall use short GOAL, CONCEPT, TYPE, and LOOK FOR sections. Color shall not be the only state indicator. Plain and no-color modes shall remain usable.

**FR-115** The lesson board shall support conceptual stages with current substeps. Completed stages shall remain visible. The board may redraw. A mandatory pause shall apply when leaving a finished conceptual stage.

**FR-116** At application startup, the application shall record the resolved working directory once. That value shall not change during the session. Directory comparisons shall use resolved paths.

**FR-117** Reserved. See FR-089 for safe `cd` command formatting.

**FR-118** When the lesson used a directory other than the session start directory, the completion screen shall explain that the parent terminal returns to the start directory after GitStart closes, and shall show a safe `cd` command for the project folder.

### 8.8 Git preflight checks

**FR-120** The application shall use Git commands to detect whether the selected directory is in a working tree.

**FR-121** The application shall find the repository root when the selected directory is inside a repository.

**FR-122** The application shall warn when the selected directory is inside a parent repository.

**FR-123** The application shall check the current branch.

**FR-124** The application shall check the configured remotes.

**FR-125** The application shall check for an upstream tracking branch.

**FR-126** The application shall use a stable machine-readable Git status format.

**FR-127** The application shall classify the working tree as clean or changed.

**FR-128** The application shall classify the local branch as equal, ahead, behind, diverged, or not tracked when enough data is available.

**FR-129** The application shall not assume that the branch name is `main`.

**FR-130** The application shall check the effective Git author identity (user name and email) in the selected repository before the first commit. The application shall prefer local repository configuration. A local identity from another directory shall not satisfy the selected repository.

### 8.9 Secret and generated-file checks

**FR-140** The application shall check for common secret file names before `git add .`.

The first list shall include:

- `.env`.
- `.env.*`.
- private key file patterns.
- common service account files.
- common credential files.

**FR-141** The application shall check for common generated directories before `git add .`.

The first list shall include:

- `node_modules`.
- `.venv`.
- `venv`.
- `__pycache__`.
- common build output directories.

**FR-142** The application shall not read the contents of a suspected secret file.

**FR-143** The application shall recommend a `.gitignore` review when a suspected secret or generated file is present. Before that decision, the application shall explain what a `.gitignore` file is.

**FR-144** The application shall not upload a file name or file content to the GitStart host.

### 8.10 New repository lesson

**FR-160** The lesson shall confirm the project directory.

**FR-161** The lesson shall teach `pwd`.

**FR-162** The lesson shall teach a file-list command that is suitable for the current shell.

**FR-163** The lesson shall review likely secret and generated files.

**FR-164** The lesson shall check the Git user name.

**FR-165** The lesson shall check the Git user email.

**FR-166** The lesson shall request explicit consent before it changes global Git configuration.

**FR-167** The lesson shall teach `git init`.

**FR-168** The lesson shall teach the branch-name operation that the project selects.

**FR-169** The lesson shall teach `git status`.

**FR-170** The lesson shall teach `git add .` only after the safety review passes.

**FR-171** The lesson shall show the staged files.

**FR-172** The lesson shall request a commit message as data.

**FR-173** The lesson shall validate that the commit message is not empty.

**FR-174** The lesson shall teach `git commit -m` with the approved message.

**FR-175** The lesson shall request an HTTPS remote URL.

**FR-176** The lesson shall validate the remote URL format.

**FR-177** The lesson shall detect an existing `origin` remote.

**FR-178** The lesson shall not replace an existing remote without explicit instructor-level action.

**FR-179** The lesson shall teach `git remote add origin` when `origin` does not exist.

**FR-180** The lesson shall teach `git remote -v`.

**FR-181** The lesson shall determine whether the remote has existing references when the network is available.

**FR-182** The lesson shall stop before it combines unrelated local and remote histories.

**FR-183** The lesson shall teach the first push with upstream tracking.

**FR-184** The lesson shall verify the final local branch and remote configuration.

### 8.11 Existing repository commit and push lesson

**FR-200** The lesson shall identify the repository root.

**FR-201** The lesson shall show the current branch.

**FR-202** The lesson shall show the working-tree state.

**FR-203** The lesson shall teach `git status`.

**FR-204** The lesson shall complete the safety review before staging all files.

**FR-205** The lesson shall teach the staging operation.

**FR-206** The lesson shall teach the commit operation.

**FR-207** The lesson shall fetch remote information before it classifies the branch relationship when the network is available.

**FR-208** The lesson shall allow a normal push when the local branch is ahead and not behind.

**FR-209** The lesson shall route a behind branch to the update lesson.

**FR-210** The lesson shall stop when the branch histories diverge.

**FR-211** The lesson shall show a diagnostic summary when it stops.

### 8.12 Existing clone update lesson

**FR-220** The lesson shall require a clean working tree before a normal update.

**FR-221** When the working tree has changes, the lesson shall offer these safe choices:

1. commit the changes.
2. stop and review the changes.
3. use a future advanced stash lesson when that lesson exists.

**FR-222** The minimum viable product shall not discard local changes.

**FR-223** The lesson shall teach `git fetch`.

**FR-224** The lesson shall show the relationship between the local branch and its upstream branch.

**FR-225** The lesson shall teach a fast-forward-only update.

**FR-226** The lesson shall stop when a fast-forward-only update is not possible.

**FR-227** The lesson shall show the commits and file changes after a successful update.

### 8.13 Fork synchronization lesson

**FR-240** The lesson shall explain the difference between `origin` and `upstream`.

**FR-241** The lesson shall show all configured remotes.

**FR-242** The lesson shall request the original repository URL when `upstream` does not exist.

**FR-243** The lesson shall teach `git remote add upstream`.

**FR-244** The lesson shall teach `git fetch upstream`.

**FR-245** The lesson shall identify the default branch or request confirmation.

**FR-246** The lesson shall use a fast-forward-only operation to update the local branch.

**FR-247** The lesson shall teach a normal push to `origin` after a successful update.

**FR-248** The lesson shall stop when the local branch and the upstream branch diverge.

### 8.14 Diagnosis lesson

**FR-260** The diagnosis lesson shall collect local Git state without file contents.

**FR-261** The diagnosis lesson shall show:

- the application version.
- the operating-system family.
- the Bash version.
- the Git version.
- the repository root.
- the current branch.
- the configured remote names and sanitized URLs.
- the clean or changed state.
- the upstream branch.
- the ahead and behind counts.
- the last command exit status when applicable.

**FR-262** The diagnosis lesson shall remove credentials and tokens from a remote URL before display.

**FR-263** The diagnosis lesson shall provide a copyable text report.

**FR-264** The application shall not send the report automatically.

### 8.15 Network and authentication

**FR-280** The application shall not request a GitHub password.

**FR-281** The application shall not request a personal access token.

**FR-282** The application shall let Git and the installed credential helper manage authentication.

**FR-283** The application shall identify an offline condition when possible.

**FR-284** The application shall explain which step requires a network connection.

**FR-285** The application shall preserve the local repository state after a network failure.

**FR-286** The application shall let the user restart and continue from the detected state.

**FR-287** The application shall classify a failed remote Git operation conservatively. Supported categories include NETWORK, TLS, AUTHENTICATION, PERMISSION, REMOTE_NOT_FOUND, NON_FAST_FORWARD, DIVERGED, and UNKNOWN. The application shall not describe every remote failure as an offline condition. AUTHENTICATION requires strong credential evidence. PERMISSION requires strong access-denial evidence after authentication is plausible. A generic permission-denied message without enough evidence shall be UNKNOWN. When evidence is weak, the application shall use UNKNOWN.

**FR-288** For network Git operations that can request credentials, the Git execution layer shall set `GIT_TERMINAL_PROMPT=0` so an invisible username or password prompt cannot block captured output. When authentication fails, the application shall explain that GitStart does not request passwords or tokens, shall keep local work safe, and shall not retry automatically.

### 8.16 Safety controls

**FR-300** The minimum viable product shall not run a force-push.

**FR-301** The minimum viable product shall not run `git reset --hard`.

**FR-302** The minimum viable product shall not run `git clean -fd`.

**FR-303** The minimum viable product shall not run a command that discards all working-tree changes.

**FR-304** The minimum viable product shall not delete a branch with force.

**FR-305** The minimum viable product shall not resolve a merge conflict automatically.

**FR-306** The minimum viable product shall not merge unrelated histories.

**FR-307** The application shall use `--` before a user-controlled path when the command supports it.

**FR-308** The application shall quote each user-controlled value.

**FR-309** The application shall treat a remote URL, path, branch, and commit message as data.

**FR-310** The application shall request confirmation before each state-changing Git command.

## 9. Nonfunctional requirements

### 9.1 Usability

**NFR-001** A new student shall be able to start the application with one pasted command.

**NFR-002** Each screen shall have one primary task.

**NFR-003** Each instruction shall use ASD-STE100 principles and the project glossary.

**NFR-004** The application shall explain a Git term before it uses the term in a decision.

**NFR-005** The application shall show the reason for a safety stop.

**NFR-006** The application shall show a safe next action after a safety stop.

### 9.2 Accessibility

**NFR-020** All important states shall have a text label.

**NFR-021** Color shall not be the only state indicator.

**NFR-022** Plain mode shall remain fully usable.

**NFR-023** The application shall avoid essential animation.

**NFR-024** The application shall let the user disable animation.

**NFR-025** The application shall keep normal terminal focus behavior.

### 9.3 Portability

**NFR-040** The application shall run with Bash 3.2 or later.

**NFR-041** The application shall not require a package manager.

**NFR-042** The application shall not require Go, Python, Node.js, `jq`, `fzf`, or GitHub CLI.

**NFR-043** The release file shall use LF line endings.

**NFR-044** The application shall handle spaces in paths.

**NFR-045** The application shall handle normal Unicode file names without parsing display output.

### 9.4 Performance

**NFR-060** The main menu shall appear within two seconds on a normal local machine, unless a required command is blocked.

**NFR-061** The local directory picker shall show the first page within one second for a directory with 1,000 immediate child entries on a normal local file system.

**NFR-062** The picker shall limit preview work.

**NFR-063** The application shall not perform a recursive full-drive scan in the minimum viable product.

### 9.5 Security and privacy

**NFR-080** The application shall not use `eval` with user input.

**NFR-081** The application shall not use `source` on an untrusted downloaded data file.

**NFR-082** The application shall not send telemetry.

**NFR-083** The application shall not upload repository data.

**NFR-084** The application shall verify the downloaded application when checksum verification is available.

**NFR-085** The project shall publish the source that produces each release.

**NFR-086** The application shall sanitize credentials in displayed remote URLs.

### 9.6 Reliability

**NFR-100** The application shall restore terminal echo after an interruption.

**NFR-101** The application shall restore cursor visibility after an interruption.

**NFR-102** The application shall not report success only from command output text.

**NFR-103** The application shall use exit status and a new state inspection to confirm success.

**NFR-104** A rerun shall not damage a valid repository.

### 9.7 Maintainability

**NFR-120** The source shall use separate modules for terminal control, directory selection, Git state, safety checks, lessons, and text.

**NFR-121** A build script shall produce one standalone release file.

**NFR-122** Each functional requirement shall map to one or more automated or manual tests.

**NFR-123** All public functions shall have a short comment that states their purpose and return contract.

**NFR-124** All user-facing text shall be stored in identifiable functions or data sections.

**NFR-125** A project glossary shall define approved terms.

## 10. External interface requirements

### 10.1 Command-line interface

The application shall accept these initial options:

```text
--learn
--assisted
--no-color
--plain
--ascii
--no-animation
--version
--help
```

The application can add an instructor diagnostic option after the minimum viable product is stable.

### 10.2 Keyboard interface

The interactive picker shall support these keys when the terminal supports single-key input:

```text
Up Arrow       Move up
Down Arrow     Move down
Enter          Open the selected directory or run the selected action
Left Arrow     Open the parent directory
Backspace      Open the parent directory
/              Start local search
.              Show or hide hidden directories
m              Enter a path manually
?              Show help
Esc            Go back or cancel
q              Quit from a top-level screen
```

The application shall show the active keys on the screen.

### 10.3 Git interface

The application shall prefer machine-readable commands and exit status.

The initial Git state commands shall include:

```bash
git rev-parse --is-inside-work-tree
git rev-parse --show-toplevel
git status --porcelain=v1
git branch --show-current
git remote -v
git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'
git rev-list --left-right --count HEAD...@{upstream}
```

The implementation shall handle a Git version that does not support `git branch --show-current`. The fallback shall use another machine-readable Git command.

## 11. Logical state model

GitStart shall classify the selected directory with these states:

```text
NOT_A_REPOSITORY
REPOSITORY_NO_COMMIT
REPOSITORY_NO_REMOTE
REPOSITORY_NO_UPSTREAM
WORKTREE_CHANGED
BRANCH_EQUAL
BRANCH_AHEAD
BRANCH_BEHIND
BRANCH_DIVERGED
REMOTE_UNAVAILABLE
AUTHENTICATION_REQUIRED
UNKNOWN_OR_UNSAFE
```

A lesson shall select its next step from the observed state. A lesson shall not select its next step only from a previous screen response.

## 12. Error handling

Each error shall contain:

1. A short error title.
2. The operation that failed.
3. The known reason, when available.
4. A safe next action.
5. A diagnostic code.

Example:

```text
[STOPPED] The push did not complete.

Git could not contact the remote repository.
Your local commit is safe.
Connect to the network and run this lesson again.

Code: GS-NET-001
```

The project shall keep a list of diagnostic codes in the source repository.

## 13. Acceptance criteria

### 13.1 Launch

- A student can paste one command into Git Bash.
- A student can paste one command into a macOS terminal.
- The bootstrap starts the local application.
- The application can read interactive input.
- A checksum error stops the launch.

### 13.2 Offline use

- A user can download `gitstart.sh`.
- A user can run `bash gitstart.sh` without a network connection.
- The directory picker works offline.
- The new repository lesson works through the first local commit offline.
- A remote action gives a clear network message when the machine is offline.

### 13.3 Directory picker

- The picker shows immediate child directories.
- Arrow keys move the selection.
- Enter opens a directory.
- The user can select the current directory.
- Local search filters or ranks the list.
- Manual path entry works.
- A path with spaces works.
- Plain numbered mode works.

### 13.4 New repository

- The lesson initializes a non-repository directory.
- The lesson stages safe files.
- The lesson creates one commit.
- The lesson adds an empty HTTPS remote.
- The lesson pushes the selected branch when the network and authentication are available.
- The lesson stops when the remote has an incompatible history.

### 13.5 Existing repository

- The application identifies clean and changed states.
- The application identifies ahead and behind counts.
- The application pushes an ahead-only branch.
- The application updates a behind-only branch with a fast-forward operation.
- The application stops when histories diverge.

### 13.6 Safety

- No student input reaches `eval`.
- No lesson runs a force-push.
- No lesson runs a hard reset.
- No lesson discards all local changes.
- The terminal returns to normal after Ctrl+C.
- A displayed remote URL does not contain a credential.

### 13.7 Text quality

- User-facing text follows the project STE rules.
- The same term identifies the same item.
- Each warning gives one safe next action.
- Color is not the only state indicator.

## 14. Future lessons

The project shall keep these lessons outside the minimum viable product. A future lesson shall use the same command teaching engine and safety model.

### FL-001 Branch creation and selection

Teach:

- why a branch is useful.
- how to list branches.
- how to create a branch.
- how to switch branches.
- how to publish a branch.

### FL-002 Pull request workflow

Teach:

- how a pull request differs from a Git push.
- how to prepare a branch.
- how to inspect the branch diff.
- how to create a pull request with a web link or an optional supported tool.
- how to respond to review changes.

### FL-003 Merge conflict resolution

Teach:

- why a conflict occurs.
- how to identify conflicted files.
- how to read conflict markers.
- how to select or combine changes.
- how to test the result.
- how to stage and commit the resolution.
- how to stop safely before data loss.

### FL-004 Stash workflow

Teach:

- when a stash is useful.
- how to create a named stash.
- how to list stashes.
- how to apply a stash.
- how to recover from a stash conflict.

### FL-005 Rebase fundamentals

Teach:

- the purpose of a rebase.
- the difference between merge and rebase.
- how to rebase a private branch safely.
- why a user must not rebase shared published history without coordination.

### FL-006 SSH authentication

Teach:

- the difference between HTTPS and SSH remotes.
- how to create an SSH key.
- how to protect a private key.
- how to add a public key to a Git service.
- how to test the connection.
- how to change a remote URL safely.

### FL-007 Repository creation

Teach:

- how to create an empty GitHub repository in the browser.
- how to use an optional GitHub API or GitHub CLI integration.
- how to select repository visibility.
- why a new remote must remain empty before the first push from an existing local project.

The minimum viable product shall use browser instructions. It shall not require an API token.

### FL-008 Advanced `.gitignore`

Teach:

- how ignore patterns work.
- how to create a project-specific `.gitignore`.
- how to use approved templates.
- how to remove an already tracked generated file without deleting the local file.

### FL-009 Commit history and correction

Teach:

- how to read a concise log.
- how to inspect a commit.
- how to amend the most recent private commit.
- how to revert a published commit.
- why `revert` is safer than history replacement for shared work.

### FL-010 Tags and releases

Teach:

- the purpose of a tag.
- how to create an annotated tag.
- how to push a tag.
- how a tag can identify a classroom submission or release.

### FL-011 Collaboration and remote branches

Teach:

- how to list remote branches.
- how to create a local tracking branch.
- how to fetch a collaborator branch.
- how to compare branches.

### FL-012 Submodules and large files

Teach the concepts only in the first version of this lesson. Do not automate these features until the safety design is complete.

Teach:

- when a submodule is appropriate.
- when Git Large File Storage can be appropriate.
- the risks of adding large binary files to normal Git history.

### FL-013 Recovery and reflog

Teach:

- that Git can record recent reference changes.
- how to inspect the reflog.
- how to identify a lost commit.
- when to request instructor help before a recovery operation.

### FL-014 Advanced and destructive operations

This lesson shall be instructor-gated.

Teach:

- why force operations are dangerous.
- the difference between `--force` and `--force-with-lease`.
- the effect of a hard reset.
- the effect of a clean operation.
- how to make a backup reference before an advanced operation.

The lesson shall use a disposable practice repository by default.

### FL-015 Automated assessment

A future optional classroom system can check lesson completion. It shall remain separate from the local tool by default.

The design shall require:

- clear instructor consent.
- clear student notice.
- minimum necessary data.
- no file-content collection.
- a mode that has no telemetry.

## 15. Future platform features

These items can be part of a later native application. They are not requirements for the Bash minimum viable product.

- A Go-based terminal user interface.
- Recursive fuzzy directory search.
- Mouse input.
- Multiple responsive panes.
- rich scrollable command logs.
- a lesson plugin system.
- a larger lesson catalog.
- more animation.
- signed native executables.
- automatic update checks.

A future native application shall keep an offline mode. It shall keep the safe command execution model.

## 16. Release phases

### Phase 0.1: Foundation

- Add the bootstrap.
- Add terminal capability checks.
- Add the visual shell.
- Add cleanup traps.
- Add the directory picker.
- Add Git state detection.

### Phase 0.2: Local repository lesson

- Add directory confirmation.
- Add Git identity checks.
- Add secret and generated-file warnings.
- Add initialization.
- Add staging.
- Add the first local commit.

### Phase 0.3: Remote publishing

- Add remote URL validation.
- Add empty-remote checks.
- Add the first push.
- Add authentication and network errors.

### Phase 0.4: Existing repositories

- Add commit and push.
- Add fast-forward update.
- Add fork synchronization.
- Add diagnosis output.

### Phase 1.0: Classroom release

- Complete the test matrix.
- Complete the STE text review.
- Complete the accessibility review.
- Complete the security review.
- Publish offline packages and instructor documentation.

## 17. Traceability rule

Each implementation task shall name the applicable requirement IDs. Each test shall name the applicable requirement IDs. A pull request shall not state that a requirement is complete unless the related tests pass.

## 18. References

- ASD-STE100 official site: https://www.asd-ste100.org/
- ASD-STE100 Issue 9: https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf
- Git documentation: https://git-scm.com/docs
- GitHub Pages documentation: https://docs.github.com/pages
