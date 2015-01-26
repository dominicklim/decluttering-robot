## Decluttering Robot

### What it does
Identify "clutter" (an orange ping pong ball) and command Romo to push the clutter to a predetermined goal. The environment is very constrained and impractical--an upside down cardboard box with a webcam looking down from above.

### Video Demos

- [Object Tracking Using HSV's](http://youtu.be/IdA2u4sJAFY)
- [First Successful Run](http://youtu.be/xFQaJ5nQa0w)
- [Declutter Without Clutter Disturbance Avoidance](http://youtu.be/0DbK_FhmDXU)
- [Declutter With Clutter Disturbance Avoidance](http://youtu.be/uf4tnYWgKqA)
### Current Planning Algorithm1. Find the line that passes through the ping pong ball and goal2. Get Romo's center on that line found in step 13. Move Romo towards the goal4. If the ball or Romo are no longer on the same line, go back to step 1

### Dependencies
Works with python 2.7

Stuff you need to pip install:

- [numpy](https://pypi.python.org/pypi/numpy)
- [cv2](http://sourceforge.net/projects/opencvlibrary/files/)
- [websocket](https://pypi.python.org/pypi/websocket)

### Usage
1. Place the clutter in environment.
2. Dock the iDevice and start up the iOS app, RomoComm, and place Romo in the environment.
3. Start the client-side script.

		$ python client/declutter.py

### Contents
- client
	- declutter.py: Main script. Finds the clutter and commands Romo to push it toward the goal.
	- rmsocket.py: Means of communication with Romo. Use websockets to communicate with Romo.
	- video.py: Interfaces with the webcam and provides OpenCV functionality. I did not write this, it is an [opencv sample](https://github.com/nielsgm/opencv/blob/master/samples/python2/video.py).
	- common.py: video.py depends on this. I did not write this, it is an [opencv sample](https://github.com/nielsgm/opencv/blob/master/samples/python2/common.py).
- ios: App for Romo to receive commands from client.

### Environment
Box: The round hole is for the light source. The square hole is for reaching into and manipulating the environment.

![image](http://i.imgur.com/rO1asGh.jpg =480x)

Light source: By closing the box off from all other light sources and providing the same light source every time, the HSV's are consistent at all times of day.

![image](http://i.imgur.com/6vhKcOS.png =480x)

Clutter:

![image](http://i.imgur.com/TI4FZ0n.jpg =480x)

Romo: The bright yellow index card on the back provides a unique color whose HSV is easy to find. The cardboard wedge attached to the front makes pushing the clutter easier.

![image](http://i.imgur.com/fwHzHF2.jpg =480x)