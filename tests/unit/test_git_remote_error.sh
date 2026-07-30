#!/usr/bin/env bash
# Unit tests: remote Git error classification (FR-283, FR-287).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"
source_core

msg=""
got=""

msg='fatal: unable to access https://example.com/r.git/: Could not resolve host: example.com'
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "NETWORK" "${got}" "NETWORK: resolve host"

msg='Failed to connect to github.com port 443: Connection timed out'
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "NETWORK" "${got}" "NETWORK: timed out"

msg='fatal: unable to access https://example.com/r.git/: SSL certificate problem: unable to get local issuer certificate'
got="$(git_classify_remote_error 35 "${msg}")"
assert_eq "TLS" "${got}" "TLS: certificate"

msg='schannel: next InitializeSecurityContext failed: Unknown error'
got="$(git_classify_remote_error 60 "${msg}")"
assert_eq "TLS" "${got}" "TLS: schannel"

msg='remote: Invalid username or password.
fatal: Authentication failed for https://example.com/r.git/'
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "AUTHENTICATION" "${got}" "AUTHENTICATION: failed"

msg="fatal: could not read Username for 'https://github.com': terminal prompts disabled"
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "AUTHENTICATION" "${got}" "AUTHENTICATION: prompts disabled"

msg='remote: Write access to repository not granted.
fatal: unable to access'
got="$(git_classify_remote_error 1 "${msg}")"
assert_eq "PERMISSION" "${got}" "PERMISSION: write access"

msg='remote: Push not permitted
error: failed to push some refs'
got="$(git_classify_remote_error 1 "${msg}")"
assert_eq "PERMISSION" "${got}" "PERMISSION: push not permitted"

msg='remote: error: GH006: Protected branch update failed'
got="$(git_classify_remote_error 1 "${msg}")"
assert_eq "PERMISSION" "${got}" "PERMISSION: protected branch"

msg='The requested URL returned error: 403'
got="$(git_classify_remote_error 1 "${msg}")"
assert_eq "PERMISSION" "${got}" "PERMISSION: HTTP 403"

msg='remote: Repository not found.
fatal: repository https://example.com/missing.git/ not found'
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "REMOTE_NOT_FOUND" "${got}" "REMOTE_NOT_FOUND"

msg='fatal: Authentication failed for https://example.com/r.git/'
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "AUTHENTICATION" "${got}" "AUTHENTICATION: failed"

msg="fatal: could not read Username for 'https://github.com': terminal prompts disabled"
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "AUTHENTICATION" "${got}" "AUTHENTICATION: prompts disabled"

msg='Permission denied (publickey).'
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "AUTHENTICATION" "${got}" "AUTHENTICATION: publickey"

msg='The requested URL returned error: 401'
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "AUTHENTICATION" "${got}" "AUTHENTICATION: HTTP 401"

msg='fatal: Permission denied'
got="$(git_classify_remote_error 128 "${msg}")"
assert_eq "UNKNOWN" "${got}" "UNKNOWN: generic permission denied"

msg='! [rejected]        main -> main (non-fast-forward)
error: failed to push some refs'
got="$(git_classify_remote_error 1 "${msg}")"
assert_eq "NON_FAST_FORWARD" "${got}" "NON_FAST_FORWARD"

msg='hint: Diverging branches cannot be fast-forwarded'
got="$(git_classify_remote_error 1 "${msg}" "DIVERGED")"
assert_eq "DIVERGED" "${got}" "DIVERGED: relation hint"

msg="Your branch and 'origin/main' have diverged"
got="$(git_classify_remote_error 1 "${msg}")"
assert_eq "DIVERGED" "${got}" "DIVERGED: message"

msg='fatal: something unexpected happened'
got="$(git_classify_remote_error 1 "${msg}")"
assert_eq "UNKNOWN" "${got}" "UNKNOWN: weak evidence"

got="$(git_classify_remote_error 128 "")"
assert_eq "UNKNOWN" "${got}" "UNKNOWN: empty message"

test_summary
