#!/bin/sh
# Starts the build with the recompiler. If that one dies from a signal (a crash), the interpreter is
# started with the same game instead, so a game the recompiler cannot handle still runs, more slowly.
# What either prints is in last-run.log in this folder.
./gba "$@"
status=$?
if [ "$status" -ge 128 ]; then
	echo "gba: the recompiler stopped with status $status; starting the interpreter" >&2
	exec ./gba-interp "$@"
fi
exit "$status"
