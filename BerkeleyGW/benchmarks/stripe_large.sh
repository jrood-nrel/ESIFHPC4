#!/usr/bin/env bash

if [[ "$#" < 1 ]]; then
    echo "$(basename $0) requires a file or directory argument"
    echo "usage: $(basename $0) <mydir>"
else
    /usr/bin/lfs setstripe -S 1048576 -c 72 $@
fi

