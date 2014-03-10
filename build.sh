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
    IN_MIN=$(minmtime $INPUT_FILES)
    OUT_MIN=$(minmtime $OUTPUT_FILES)
    if [ $IN_MIN -gt $OUT_MIN ]; then
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

function do_npm() {
    if $(outofdate node_modules package.json); then
        npm install
    fi
}

function do_bower() {
    if $(outofdate bower_components bower.json); then
        bower install
    fi
}

# scss -> intermediate, unminified css
function do_scss() {
    mkdir -p css
    if $(outofdate css/base.css scss/base.scss); then
        sass scss/base.scss css/base.css
    fi
}

# scss -> minified css
function do_css() {
    mkdir -p production/css
    do_scss
    if $(outofdate production/css/base.css css/base.css); then
        cssmin css/base.css > production/css/base.css
    fi
}

function do_all() {
    do_npm
    do_bower
    do_scss
    do_css
}

PATH=$(pwd)/node_modules/.bin:${PATH}

CMD=${1:-all}
do_$CMD
