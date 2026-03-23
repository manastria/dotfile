#!/usr/bin/env bash

xkbcomp -I$HOME/.xkb -R$HOME/.xkb ~/.xkb/keymap/minimal.xkb $DISPLAY
