#!/usr/bin/env bash

## KDE/Gnome autostart script

for file in ~/.{aliases,functions,path,dockerfunc,extra,exports}; do
    if [[ -r "$file" ]] && [[ -f "$file" ]]; then
        # shellcheck source=/dev/null
        source "$file"
    fi
done
unset file
