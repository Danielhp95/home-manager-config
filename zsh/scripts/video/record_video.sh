#!/usr/bin/env bash
# TODO: Make this into a nix file using writeSriptBin
# TODO: make these go to a folder
# TODO: figure out how to get audio WITHOUT READING FROM MICROPHONES

getdate() {
    date '+%Y%m%d_%H-%M-%S'
}

cd ~/Videos || exit
if pgrep wf-recorder > /dev/null; then
    notify-send "Recording Stopped" "Stopped" -a 'record-script.sh' &
    pkill wf-recorder &
else
    notify-send "Starting recording" 'recording_'"$(getdate)"'.mp4' -a 'record-script.sh'
    if [[ "$1" == "--sound" ]]; then
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$(slurp)" --audio & disown
    elif [[ "$1" == "--fullscreen-sound" ]]; then
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t & disown
    elif [[ "$1" == "--fullscreen" ]]; then
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t & disown
    else 
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$(slurp)" & disown
    fi
fi
