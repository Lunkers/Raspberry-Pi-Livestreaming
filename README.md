# Setting up a livestream from a raspberry pi using nginx and FFMPEG #

## Intro
I created this repo in order to help some friends set up higher quality live streams from their rasberry pi's than what can be done using motion. It's a bit more complicated than simply using motion, but in return, you will get the benefits of using h.264 instead of multipart JPEG (which is kinda outdated in 2021.), and an HLS manifest instead of simple GET requests.

## Requirements and setup
We'll assume that you're running a raspberry pi with the standard debian-based OS Rasbian.

To start, connect to your pi via SSH, or use it connected to a monitor, mouse, and keyboard.
In the terminal, write 
```
sudo apt update
```
This will update the package list.

### Installing our web server
Then, we install `nginx` by typing:
```
sudo apt-get install nginx
```
To check that nginx was installed correctly, enter 
```
sudo /etc/init.d/nginx start
```
into the terminal. This will start a web server on your raspberry pi.
To verify that the server is running, enter the pi's ip adress into your web browser of choice; if you're actually on the pi, just enter `localhost`. If everyting is working correctly, you should be greeted by the default nginx web page.
We'll come back to nginx later, but for now this is enough.

### Installing FFMPEG
FFMPEG is a great piece of software for video and audio processing. Provided that you take the time to learn it, it can bascially be your one-stop shop for media processing and encoding.
To install FFMPEG, enter 
```
sudo apt-get install ffmpeg
```
into the terminal.

Next, we need to very that the proper encoders are installed. To do so, enter 
```
ffmpeg -encoders | grep 264
``` 
Into the terminal. The output will be a list of h264 encoders available for use with FFMPEG. `libx264` should be in this list. Depending on the hardware you're using, you should also see `h264_omx` and/or `h264_v4l2m2m`. `libx264` is a *software* encoder made by videoLAN, and is the one we're gonna be using here since it's included in the default distribution of FFMPEG. Since it's not hardware accelerated, you might want to switch to using `h264_omx` or `h264_v4l2m2m` depending on the model and OS of your pi. We'll go over how to to that later.

## Setting up our folder structure
Now that our dependencies are installed, we need to set up our folder structure for the web server. The nginx configs are stored in the directory `/var/www/html/`. To get there, enter 
```
cd /var/www/html
```
into the terminal.

Now we need to add a folder to store our video files and playlists in. Enter
```
mkdir live
```
into the terminal.

## Running FFMPEG to create a manifest
For the live stream, we will need to create a *manifest*. To explain it shortly, a manifest is a file that tells the player what quality levels are available for a stream, and where to find them. If you want to learn more about manifests and adaptive bitrate streaming in general, [this series of blog posts are a good place to start](https://eyevinntechnology.medium.com/internet-video-streaming-abr-part-1-b10964849e19). For this small-scale project, we will only generate one quality level, but a manifest is still needed for the player to know which files to fetch and from where. We'll be using the [HLS](https://developer.apple.com/streaming/) standard for our manifest.

Copy the file `stream.sh` from this folder into the nginx `live` folder that you made in the previous step.

To start capturing video from your camera and generating a manifest (and segments), simply enter the `live` folder and type 
```
./stream.sh
```
into the terminal. This will run the bash script which captures video from your webcam, encodes it, and writes it to a segment file. FFMPEG will automatically generate a master playlist called `livestream.m3u8`, which should show up in the `live` folder, as well as segments named `livestream1.ts`, `livestream2.ts`, etc.

We'll discuss the anatomy of the FFMPEG command later.

## Serving a player

Now that you have a stream going, you will need a player to display it to visitors. To do this, we'll serve a static HTML page, using [HLS.js](https://github.com/video-dev/hls.js) to parse our manifest and load the segments.

Return to the `/var/www/html` directory. You will need to do two things. First, replace the `index.html` file that's already there with the one found in this directory. Once you've done that, you'll need to edit the file in your favorite text editor. Replace 
```
{YOUR_SERVER_ADRESS}
```
with the ip adress of your webserver (don't use localhost here!).

Now you should be able to enter the IP adress of your pi in into your browser, and the stream should start playing! There might be a slight delay depending on how fast FFMPEG encodes the stream and generates the manifest and video segments, but that should be fine.


## Extra: Dechiphering the FFMPEG command
As bonus, let's walk through the bash script in `stream.sh`!
We begin by defining the video source with:
```
VIDEOSOURCE="/dev/video0"
```
This defines the video source as the first video input to the machine. If your camera is not running on `video0`, you will need to change the index. If you're using an IP camera, replace `/dev/vide0/` with the camera's adress.

Next, we define our audio settings with:
```
AUDIO_OPTIONS="-c:a aac -b:a 192000 -ac 2"
```
Let's walk through each argument: `-c:a aac` specifies that audio should be encoded with the [AAC](https://en.wikipedia.org/wiki/Advanced_Audio_Coding) audio codec. 

`-b:a 192000` specifies the audio bitrate 192kbps. If we did not specify this, FFMPEG would try to guess which bitrate to use, which might be too high or too low. Feel free to change this value if you feel like you need higher or lower audio bitrates.

`-ac 2` specifies that we are using 2 channels.

If you don't want to stream any audio, modify the script such that:
```
AUDIO_OPTIONS="-an"
```
This tells FFMPEG to discard any audio and only mux video in the output container.

Our video options are set with:
```
VIDEO_OPTIONS="-vf scale=1280:720 -c:v libx264 -b:v 1M -pix_fmt yuv420p -r 30"
```
`-vf scale=1280:720` scales the input video so the output is 1280x720 pixels. If you want to change the output resolution, change this setting. NOTE: I don't recommend setting this to a resolution higher than that of your input. 1280x720 is a common resolution for webcams, and also a good resolution for streaming, and is thus the default. If your camera has a lower resolution, change this value to match it.

`-c:v libx264` tells FFMPEG to encode the video stream using the libx264 encoder by videoLAN. If you want to use hardware encoding, change the value to `h264_omx` if running a 32-bit OS, or `h264_v4l2m2m` if using 64 bit. NOTE: `h264_v4l2m2m` [seems to have some issues](https://www.willusher.io/general/2020/11/15/hw-accel-encoding-rpi4), so you might need to rebuild FFMPEG as shown in the link.

`-b:v 1M` sets the video bitrate to 1Mbps. You can change this value if you want to; higher values will lead to higher quality video (but larger files!) and vice versa for lower values.

`-pix_fmt yuv420p` sets the pixel format to 4:2:0 YUV. We specify this here for compatibility. Some players need this information to be encoded in the header, or else they will refuse to play the file. If we do not set this, the pixel format of the input stream will be copied.

`-r 30` sets the frame rate to 30fps. You can change this value depending on what framerate you want for your stream. NOTE: if you raise the frame rate, you'll probably want to raise your bitrate as well.

There's a lot of room for tweaking and experimentation here! Look into encoder-specific settings and see what you can do to save bitrate or include quality! (for example, try specifying a GOP length, or number of b-frames)

```
HLS_OUTPUT="-hls_time 10 -hls_list_size 10 -start_number 1"
```
Specifies the settings for our HLS manifest.
`-hls_time 10` specifies the segment length to 10 seconds.

`-hls_list_size 10` sets the max length of our manifest to 10 segments. After this, we will start overwriting old segments.

`-start_number 1` sets the start number of the manifest to 1.

Finally, we execute the FFMPEG command:
```
ffmpeg -i "$VIDEOSOURCE" -y $AUDIO_OPTIONS $VIDEO_OPTIONS $HLS_OUTPUT livestream.m3u8
```
There's not much to unravel here. `-i "$VIDEOSOURCE"` specifies that the video source we defined earlier, `-y` overwrites any conflicting files, and `livestream.m3u8` specifies the name of our master playlist.
