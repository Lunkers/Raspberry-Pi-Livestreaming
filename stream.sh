#!/bin/bash
VIDEOSOURCE="/dev/video0"
AUDIO_OPTIONS="-c:a aac -b:a 192000 -ac 2 "
VIDEO_OPTIONS="-vf scale=1280:720 -c:v libx264 -b:v 1M -pix_fmt yuv420p -r 30 "
HLS_OUTPUT="-hls_time 10 -hls_list_size 10 -start_number 1"
ffmpeg -i "$VIDEOSOURCE" -y $AUDIO_OPTIONS $VIDEO_OPTIONS $HLS_OUTPUT livestream.m3u8
