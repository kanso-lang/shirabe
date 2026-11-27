#!/bin/sh
# The cost guard prices a project as Hetzner would, and fails one that
# would cost more than the budget. Each directory under answers/ holds what
# the API answered for a project, and the .out beside it what the guard
# prints for it on 2026-11-27. Run from the repository's root:
#
#   sh deploy/cost/cost_test.sh
#
# `within` is the project as it stands, one small server and its IPs.
# `over` adds a larger server with backups and traffic past what it
# includes, a volume and a snapshot.
set -u
fail=0
check() {
  name=$1
  want_exit=$2
  got=$(HCLOUD_ANSWERS="deploy/cost/answers/$name" TODAY=2026-11-27 sh deploy/cost/cost.sh)
  code=$?
  if [ "$code" != "$want_exit" ]; then
    echo "FAIL: $name exited $code, not $want_exit"
    fail=1
  fi
  if [ "$got" != "$(cat "deploy/cost/answers/$name.out")" ]; then
    echo "FAIL: $name printed:"
    echo "$got"
    fail=1
  fi
}
check within 0
check over 1
[ "$fail" = 0 ] && echo "ok: the cost guard prices both projects and fails the one over budget"
exit "$fail"
