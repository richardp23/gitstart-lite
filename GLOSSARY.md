# GitStart Lite Glossary

Version: 0.2.0
Date: 2026-07-29

This glossary defines approved terms for GitStart Lite. Text uses ASD-STE100 principles. This document is not a formal STE certification.

## A

**Application**  
The complete local `gitstart.sh` file that runs on the student machine.

**Assisted mode**  
A teaching mode. The application shows each command and asks for confirmation before it runs the command.

## B

**Bootstrap**  
A small script that downloads a versioned release, verifies the checksum when possible, and starts the application.

**Branch**  
A named line of development in a repository. A branch points to a commit.

## C

**Clone**  
A local copy of a remote repository.

**Commit**  
A saved Git snapshot. A commit records changes in the repository history.

**Current directory**  
The directory in which the application starts or operates.

## D

**Diagnostic code**  
A stable ID such as `GS-GIT-001`. It identifies an error type and a safe next action.

**Directory picker**  
A built-in tool that lists immediate child directories. The student selects a project directory.

## F

**Fast-forward update**  
An update that moves the branch pointer forward without a merge commit. GitStart teaches fast-forward-only updates when possible.

**Fork**  
A remote repository that is based on another remote repository. A fork is usually the student copy on a hosting site.

**Fuzzy search**  
A built-in filter for directory names. It matches exact names, prefixes, substrings, and ordered characters.

## G

**Git**  
A version control system. GitStart teaches safe local Git workflows.

## L

**Learn mode**  
The default teaching mode. The student types each approved command. The application validates the text and runs a predefined function. It does not run student text as shell code.

**Lesson**  
A guided sequence that teaches one Git task step by step.

## O

**Origin**  
The normal name of the primary remote repository. GitStart uses `origin` for the student remote.

## P

**Plain mode**  
Output without color art. Use `--plain` or `--no-color` when color is not useful.

**Pull**  
A Git operation that fetches remote changes and integrates them into the local branch. GitStart teaches fetch and fast-forward steps separately in the MVP.

**Push**  
A Git operation that sends local commits to a remote repository.

## R

**Remote**  
A named connection to another Git repository. Examples are `origin` and `upstream`.

**Repository**  
A directory that Git tracks. It contains project files and Git history.

## S

**Safety stop**  
A controlled stop when GitStart detects an unsafe state. The application explains the reason and one safe next action.

**Staging**  
The step that prepares file changes for a commit. GitStart teaches `git add` after a safety review.

## U

**Upstream**  
The normal name of the original repository for a fork. GitStart uses `upstream` for the source repository in fork sync lessons.

**Upstream tracking branch**  
The remote branch that a local branch follows. GitStart checks this relationship before push and update lessons.

## W

**Working tree**  
The files that the user can edit in a local repository. GitStart classifies the working tree as clean or changed.
