#!/bin/zsh
# contact sheet of the stills of one scenario:  sheet.sh PREFIX OUT.png [WIDTH]
W=${3:-220}
files=(${1}_[0-9]*.png)
args=(); filt=""; n=0
for f in $files; do args+=(-i $f); filt+="[$n]scale=$W:-1[s$n];"; n=$((n+1)); done
in=""; for i in $(seq 0 $((n-1))); do in+="[s$i]"; done
ffmpeg -v error -y $args -filter_complex "${filt}${in}hstack=$n" $2
