#!/bin/bash

#------------------------------------------------------------------------------
# boilerplate
#------------------------------------------------------------------------------

function minmtime() {
    FILES=$1

    if [ $(uname) == "Darwin" ]; then
        # OS X
        stat -f %m "$FILES" | sort | head -n 1
    else
        # ubuntu
        stat -c %Z "$FILES" | sort | head -n 1
    fi    
}

function outofdate() {
    INPUT_FILES=$1
    OUTPUT_FILES=$2
    if [ $(minmtime $INPUT_FILES) -gt $(minmtime $OUTPUT_FILES) ]; then
        return 1
    else
        return 0
    fi
}

function ext() {
    base=$(basename "$1")
    ext="${base#*.}"
    echo "$ext"
}

function sansext() {
    base=$(basename "$1")
    sans="${base%%.*}"
    echo "$sans"
}

#------------------------------------------------------------------------------
# app specific
#------------------------------------------------------------------------------
function installBower() {
    if $(outofdate bower_components bower.json); then
        bower install
    fi
}

$1
