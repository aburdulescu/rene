#!/bin/sh

set -xe

rm -f *.perf *.time *.turbostat

sudo perf stat -r5 -e instructions,cycles,cache-references,cache-misses,branches,branch-misses busybox "$@" 1>/dev/null 2>busybox.perf
sudo perf stat -r5 -e instructions,cycles,cache-references,cache-misses,branches,branch-misses ./zig-out/bin/rene "$@" 1>/dev/null 2>rene.perf

sudo perf stat -r5 -e instructions,cycles,cache-references,cache-misses,branches,branch-misses --all-user busybox "$@" 1>/dev/null 2>busybox.user.perf
sudo perf stat -r5 -e instructions,cycles,cache-references,cache-misses,branches,branch-misses --all-user ./zig-out/bin/rene "$@" 1>/dev/null 2>rene.user.perf

/usr/bin/time -v busybox "$@" 1>/dev/null 2>busybox.time
/usr/bin/time -v ./zig-out/bin/rene "$@" 1>/dev/null 2>rene.time

sudo turbostat --Summary --Joules --show Pkg_J busybox "$@" 1>/dev/null 2>busybox.turbostat
sudo turbostat --Summary --Joules --show Pkg_J ./zig-out/bin/rene "$@" 1>/dev/null 2>rene.turbostat

diff -y busybox.perf rene.perf | colordiff
diff -y busybox.user.perf rene.user.perf | colordiff
diff -y busybox.time rene.time | colordiff
diff -y busybox.turbostat rene.turbostat | colordiff
