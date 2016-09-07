#!/usr/bin/env sh
 
tmpfile=$(mktemp)
zopflipng -m -y $1 $tmpfile
mv $tmpfile $1