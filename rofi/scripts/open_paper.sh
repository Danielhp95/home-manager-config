PAPERS_LOCATION=~/papers
# TODO: add icon to entries, maybe by processing output of ls?
icon=
bash remove first word of line
PAPER=$(ls $PAPERS_LOCATION | sed "s/^/$icon /" | rofi -dmenu -p "Choose paper" | sed "s/^$icon\ //")
# $? checks the return code of the last program
(($? == 0 )) && zathura $PAPERS_LOCATION/$PAPER
