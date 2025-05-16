#!/usr/bin/env bash

## KDE/Gnome autostart script

## Set all the relevant environment vars, functions, aliases, etc
for file in ~/.{aliases,functions,path,dockerfunc,extra,exports}; do
    if [[ -r "${file}" ]] && [[ -f "${file}" ]]; then
        # shellcheck source=/dev/null
        source "${file}"
    fi
done
unset file

## Execute scripts
for file in ~/.{startup_apps_cli,startup_apps_gui}; do
    if [[ -r "${file}" ]] && [[ -f "${file}" ]]; then
        "${file}"
    fi
done
unset file
