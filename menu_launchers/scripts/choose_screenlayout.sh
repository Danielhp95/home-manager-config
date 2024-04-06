#!/bin/bash

layouts_dir=~/.screenlayout/
icon=
choosen_layout=$(ls $layouts_dir | sed "s/^/$icon /" | rofi -dmenu | sed "s/^$icon\ //")
bash $layouts_dir/$choosen_layout
