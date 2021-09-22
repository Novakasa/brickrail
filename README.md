# Brickrail
Work in progress lego train automation software

Intended to be used with lego trains and layout controllers (for motorized lego switches) based on Lego PoweredUp hubs with pybricks firmware.
This project contains microphython programs running on the lego hardware, a python server that handles BLE communication with the lego hardware, and a GUI running in Godot game engine.
Communication between GUI and python server is done through websockets.
As of now, trains detect their location via a Boost Color sensor pointed dowwards toward the track. Colored markers signal the bounds of block sections.

![GUI screenshot](screenshot.PNG)

# How to run
Download godot engine binary from the official website. Open the project `brickrail-gui/project.godot`, hit F5.
