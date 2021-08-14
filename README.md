# BrickRail
Work in progress lego train automation software

Intended to be used with lego trains and layout controllers based on Lego PoweredUp hubs with pybricks firmware.
This project contains microphython programs running on the lego hardware, a python server that handles communication
with the lego hardware, and a GUI running in Godot game engine.
Communication between GUI and python server is done through websockets.

This is work in progress. Communication between GUI and trains is working, but full automation of lego trains is not working yet. A lot of work went into the track layout editor.

![Alt text](screenshot.png?raw=true "GUI screenshot")