#!/usr/bin/env bash
# Precondition probe for the two required jobs: fails unless this process is subject to
# file permission bits (#341).
#
# Seven verification cases across five sites stop testing anything when the running
# process can bypass file modes, and every one of them leaves its job green. This probe
# makes that precondition mechanical: it builds mode-restricted fixtures and fails if
# this process can still use them. It is deliberately not a uid comparison: a process
# holding CAP_DAC_OVERRIDE without being uid 0 bypasses file modes too, and a uid test
# would miss it. It is the shape the two shell self-tests already use, which probe
# whether they can still read a fixture they just made unreadable.
#
# The four denials below cover all seven cases, the two that produce no skip record
# included, because every one of the seven guards is a privilege test over a
# mode-restricted fixture:
#
#   A  a mode-000 regular file cannot be read
#      internal/bundle/input_test.go        TestReadRegular/unreadable
#      scripts/process/test-check-readiness.sh  unreadable docs/process/labels.md
#   B  a mode-000 directory cannot be listed or traversed
#      internal/bundle/input_test.go        TestReadRegular/unreadable-directory
#      internal/bootstrap/fetch_test.go     TestCheckFetched, unreadable directory
#      scripts/docs/test-check-links.sh     unreadable directory ... skipping documents
#   C  a mode-600 directory is not searchable, so lstat of an entry inside it fails
#      internal/bootstrap/fetch_test.go     TestCheckFetched, listable but not searchable
#   D  an entry inside a mode-500 directory cannot be removed
#      internal/bootstrap/decrypt_test.go   TestClaimWorkDir/unremovable leftover
#
# Two controls run alongside them, so a fixture the probe failed to build cannot be
# mistaken for an enforced mode: a mode-644 file under a mode-755 directory must be
# readable, and an entry in a writable directory must be removable.
#
# Limitation, stated next to the probe rather than left implicit: it catches a case that
# cannot exercise its permission fixture. It does not catch a case that begins skipping
# for some other reason. Making TestCheckFetched's two table entries subtests, so that
# any skip becomes observable, is a possible later filing and is not this probe's job.
#
# Fails closed. Exit 0 every denial and both controls hold; 1 this process bypasses file
# modes, naming the precondition; 2 usage error; 3 the probe could not build its fixture,
# or a control did not hold, so its result would be vacuous.
set -euo pipefail

while (($#)); do
  case "$1" in
    -h|--help) echo "usage: $0"; exit 0 ;;
    *) echo "check-mode-enforcement: unknown argument: $1" >&2; exit 2 ;;
  esac
done

unusable() { echo "MODE_PROBE_UNUSABLE: $*" >&2; exit 3; }
bypassed() {
  echo "MODE_ENFORCEMENT_BYPASSED: $*" >&2
  echo "MODE_ENFORCEMENT_BYPASSED: this process is not subject to file permission bits, so every permission case listed in docs/process/testing.md would self-disable and this job would report success without testing them; run this job as a process that does not bypass file modes." >&2
  exit 1
}

fixture="$(mktemp -d "${TMPDIR:-/tmp}/prifly-mode-probe.XXXXXX")" ||
  unusable "cannot create a fixture directory under ${TMPDIR:-/tmp}"
# This exact mktemp-owned directory contains only generated fixtures.
trap 'chmod -R u+rwX -- "$fixture" >/dev/null 2>&1 || true; rm -rf -- "$fixture"' EXIT

mkdir -p -- "$fixture/open" "$fixture/locked-dir" "$fixture/listable" "$fixture/readonly-dir/sub" ||
  unusable "cannot create the fixture tree under $fixture"
for f in open/readable locked-file locked-dir/inside listable/entry; do
  printf 'probe\n' >"$fixture/$f" || unusable "cannot write the fixture file $f"
done

# Controls first: the probe's own mechanism has to work before a denial means anything.
[[ -d "$fixture/open" && -f "$fixture/open/readable" ]] ||
  unusable "control: the fixture tree is not the shape the probe built"
chmod 755 "$fixture/open" && chmod 644 "$fixture/open/readable" ||
  unusable "control: cannot set the permissive control modes"
cat -- "$fixture/open/readable" >/dev/null 2>&1 ||
  unusable "control: a mode-644 file under a mode-755 directory is not readable, so a denial below would prove nothing"
: >"$fixture/open/removable" || unusable "control: cannot create the removable control entry"
rm -f -- "$fixture/open/removable" ||
  unusable "control: an entry in a writable directory cannot be removed, so denial D would prove nothing"

chmod 000 "$fixture/locked-file" || unusable "cannot make the regular-file fixture mode-000"
chmod 600 "$fixture/listable" || unusable "cannot make the listable-directory fixture mode-600"
chmod 500 "$fixture/readonly-dir" || unusable "cannot make the read-only-directory fixture mode-500"
chmod 000 "$fixture/locked-dir" || unusable "cannot make the directory fixture mode-000"

# The filesystem has to have honoured those modes; a mount that ignores them makes every
# denial below vacuous, which is a probe that cannot run rather than a passing one.
for pair in "locked-file:0" "locked-dir:0" "listable:600" "readonly-dir:500"; do
  path="$fixture/${pair%%:*}"
  want="${pair##*:}"
  got="$(stat -c '%a' -- "$path" 2>/dev/null)" ||
    unusable "cannot read back the mode of ${pair%%:*}"
  [[ "$got" == "$want" ]] ||
    unusable "the filesystem under ${TMPDIR:-/tmp} did not honour chmod on ${pair%%:*}: mode is $got, not $want"
done

# A: a mode-000 regular file must not be readable.
if cat -- "$fixture/locked-file" >/dev/null 2>&1; then
  bypassed "read a mode-000 regular file (denial A)"
fi

# B: a mode-000 directory must be neither listable nor traversable.
if ls -- "$fixture/locked-dir" >/dev/null 2>&1; then
  bypassed "listed a mode-000 directory (denial B)"
fi
if cat -- "$fixture/locked-dir/inside" >/dev/null 2>&1; then
  bypassed "traversed a mode-000 directory (denial B)"
fi

# C: a mode-600 directory carries no search bit, so lstat of an entry must fail.
if stat -- "$fixture/listable/entry" >/dev/null 2>&1; then
  bypassed "stat'd an entry through a mode-600 directory, which grants no search (denial C)"
fi

# D: an entry inside a mode-500 directory must not be removable.
if rmdir -- "$fixture/readonly-dir/sub" >/dev/null 2>&1; then
  bypassed "removed an entry from a mode-500 directory (denial D)"
fi

echo "check-mode-enforcement: file modes are enforced for this process (4 denials held, 2 controls held)"
