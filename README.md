# Brickrail
Work in progress LEGO train automation software

Intended to be used with LEGO PoweredUp trains and LEGO PoweredUp hubs as stationary controllers (for motorized switches) with easy to install and uninstall [`pybricks`](https://pybricks.com/) firmware.
This project contains microphython programs running on the LEGO hardware, a python server that handles BLE communication with the devices, and a GUI running in Godot game engine that also handles the Train route and scheduling logic.
Communication between GUI and python server is done through websockets.
As of now, trains detect their location via a Boost Color and Distance Sensor pointed dowwards onto the track. Colored markers signal the bounds of block sections.

![GUI screenshot](screenshot2.PNG)

[Here](https://www.youtube.com/watch?v=cBF-G4d4vw8)'s a video of brickrail in action with a multi-layered layout.

Head to the https://github.com/Novakasa/brickrail/wiki to learn more about how to run brickrail with your LEGO train layout.
