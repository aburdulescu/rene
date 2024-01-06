#!/bin/sh

set -xe

rm -f *.perf *.time

perf stat -r5 -e instructions,cycles,cache-references,cache-misses,branches,branch-misses busybox "$@" 1>/dev/null 2>busybox.perf
perf stat -r5 -e instructions,cycles,cache-references,cache-misses,branches,branch-misses ./zig-out/bin/rene "$@" 1>/dev/null 2>rene.perf

perf stat -r5 -e instructions,cycles,cache-references,cache-misses,branches,branch-misses --all-user busybox "$@" 1>/dev/null 2>busybox.user.perf
perf stat -r5 -e instructions,cycles,cache-references,cache-misses,branches,branch-misses --all-user ./zig-out/bin/rene "$@" 1>/dev/null 2>rene.user.perf

/usr/bin/time -v busybox "$@" 1>/dev/null 2>busybox.time
/usr/bin/time -v ./zig-out/bin/rene "$@" 1>/dev/null 2>rene.time

diff -y busybox.perf rene.perf | colordiff
diff -y busybox.user.perf rene.user.perf | colordiff
diff -y busybox.time rene.time | colordiff
