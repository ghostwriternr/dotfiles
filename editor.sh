#!/bin/bash

export EDITOR="$(if [[ -n $DISPLAY ]]; then echo 'atom'; else echo 'nano'; fi)"
