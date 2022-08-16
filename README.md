# Brickrail
Work in progress LEGO train automation software

Intended to be used with LEGO PoweredUp trains and LEGO PoweredUp hubs as stationary controllers (for motorized switches) with easy to install and uninstall [`pybricks`](https://pybricks.com/) firmware.
This project contains microphython programs running on the LEGO hardware, a python server that handles BLE communication with the devices, and a GUI running in Godot game engine that also handles the Train route and scheduling logic.
Communication between GUI and python server is done through websockets.
As of now, trains detect their location via a Boost Color and Distance Sensor pointed dowwards onto the track. Colored markers signal the bounds of block sections.

![GUI screenshot](screenshot2.PNG)

# How to run
Download the Godot Engine binary from the [official website](https://godotengine.org/download). Open the project `brickrail-gui/project.godot`, hit F5.
The gui is looking for a python environment with the installed package `pybricksdev` in ble-server/.env to start the ble-server, which is not currently included in the repo, but will be in releases once they are available.

Instructions for setup of your switches and calibration of the color sensors are coming in the future, as the process is not finalized yet.
