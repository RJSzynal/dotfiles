#!/bin/bash

for file in ~/.{aliases,functions,path,dockerfunc,exports,extra}; do
    if [[ -r "${file}" ]] && [[ -f "${file}" ]]; then
        # shellcheck source=/dev/null
        source "${file}"
    fi
done
unset file
