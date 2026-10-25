#!/bin/sh
# Runs every unit test under plain luajit; no KOReader needed.
cd "$(dirname "$0")/unit" || exit 1
status=0
for t in *_test.lua; do
    luajit "$t" || status=1
done
exit $status
