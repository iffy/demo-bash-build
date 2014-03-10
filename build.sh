#!/bin/bash

#------------------------------------------------------------------------------
# boilerplate
#------------------------------------------------------------------------------
BUILDSCRIPT="$0"
if [ ! -z "$IGNORE_BUILDSCRIPT" ]; then
    BUILDSCRIPT=""
fi 


function mtime() {
    FILES=$1
    RET=""
    RC=""
    if [ $(uname) == "Darwin" ]; then
        # OS X
        RET=$(stat -f %m $FILES 2>/dev/null)
        RC=$?
    else
        # ubuntu
        RET=$(stat -c %Z $FILES 2>/dev/null)
        RC=$?
    fi
    if [ "$RC" == "0" ]; then
        echo "$RET"
    else
        echo ""
    fi
}

function minmtime() {
    FILES="$1"
    mtime "$FILES" | sort | head -n 1
}

function maxmtime() {
    FILES="$1"
    mtime "$FILES" | sort | tail -n 1
}

function outofdate() {
    INPUT_FILES="$1 $BUILDSCRIPT"
    OUTPUT_FILES=$2

    IN_MAX=$(maxmtime "$INPUT_FILES")
    OUT_MIN=$(minmtime "$OUTPUT_FILES")

    if [ -z "$IN_MAX" ] || [ -z "$OUT_MIN" ]; then
        # out of date - missing file
        return 0
    fi

    if [ $IN_MAX -gt $OUT_MIN ]; then
        return 0
    else
        return 1
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

function do_clean() {
    rm -r node_modules
    rm -r bower_components
    rm -r .tmp
    rm -r production
}

function do_npm() {
    if $(outofdate package.json node_modules); then
        npm install
    fi
}

function do_bower() {
    if $(outofdate bower.json bower_components); then
        bower install
    fi
}

# scss -> intermediate, unminified css
function do_scss() {
    mkdir -p css
    if $(outofdate scss/base.scss css/base.css); then
        echo "-> css/base.css"
        sass scss/base.scss css/base.css
    fi
}

# scss -> minified css
function do_css() {
    mkdir -p production/css
    do_scss
    if $(outofdate css/base.css production/css/base.css); then
        echo "-> production/css/base.css"
        cssmin css/base.css > production/css/base.css
    fi
}

# html -> production html + script groups
function do_html() {
    mkdir -p production
    mkdir -p .tmp/groups
    for htmlfile in $(ls *.html); do
        group_filename=".tmp/groups/${htmlfile}.json"
        output_html="production/${htmlfile}"

        if $(outofdate "minsrc.py $htmlfile" "$output_html $group_filename"); then
            echo "-> $output_html"
            echo "-> $group_filename"
            python minsrc.py --groups-file $group_filename $htmlfile > $output_html
        fi
    done
}

# js -> combined, minified js
function do_js() {
    do_html

    tmp_ngmin=".tmp/js.ngmin"
    tmp_cat=".tmp/js.cat"
    mkdir -p $tmp_ngmin    
    for groupfile in $(ls .tmp/groups/); do
        
        # read the scripts that need to be combined
        groupfile=".tmp/groups/$groupfile"
        # hard-coded to single group for now
        src_files=$(python rjson.py $groupfile 'x[0]["inputs"]')
        final_name="production/$(python rjson.py $groupfile 'x[0]["options"]["output"]')"
        mkdir -p $(dirname $final_name)

        # ngmin
        # since ngmin doesn't work on stdin/stdout, we need an intermediate
        # file.  We'll want one for pre-concatenating anyway
        ngmin_files=""
        for srcfile in $src_files; do    
            ngmin_filename="${tmp_ngmin}/$(basename $srcfile)"
            ngmin_files="$ngmin_files $ngmin_filename"
            if $(outofdate $srcfile $ngmin_filename); then
                echo "-> $ngmin_filename"
                ngmin $srcfile $ngmin_filename
            fi
        done

        # concat + uglify
        if $(outofdate "$ngmin_files" $final_name); then
            echo "-> $final_name"
            cat $ngmin_files | uglifyjs > $final_name
        fi
    done
}

function do_all() {
    do_npm
    do_bower
    do_scss
    do_css
    do_js
}

PATH=$(pwd)/node_modules/.bin:${PATH}

CMD=${1:-all}
do_$CMD
