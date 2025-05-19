#!/usr/bin/env bash

## KDE/Gnome autostart script

# Ensure the log dir exists
mkdir -p "${HOME}/log"

## Set all the relevant environment vars, functions, aliases, etc
for file in ~/.{aliases,functions,path,dockerfunc,exports,extra}; do
    if [[ -r "${file}" ]] && [[ -f "${file}" ]]; then
	    printf "%s %s %s:%s\n" $(date -u +'%T') "${0}" 'INFO' "Sourcing ${file}" >> ${HOME}/log/$(date +%F)-userscript.log
        # shellcheck source=/dev/null
        source "${file}"
    fi
done
unset file

## Execute scripts
for file in ~/.{startup_apps_cli,startup_apps_gui}; do
    if [[ -r "${file}" ]] && [[ -f "${file}" ]]; then
	    printf "%s %s %s:%s\n" $(date -u +'%T') "${0}" 'INFO' "Executing ${file}" >> ${HOME}/log/$(date +%F)-userscript.log
        "${file}"
    fi
done
unset file
