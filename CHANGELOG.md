<!-- Refer to https://keepachangelog.com/en/1.0.0/ for guidance. -->
<!-- template stolen from pybricks-micropython repository -->

# Changelog

## [unreleased]

### Added

- Added support for Spike color sensor (https://github.com/Novakasa/brickrail/issues/180)

### Fixed

### Changed

## [v1.0.0]

### Added

- Added "disable train" setting for blocks. Any train in a block with this setting enabled will not be connected via bluetooth. Layout Controllers will only need to connect when a device is assigned to one of it's ports. (https://github.com/Novakasa/brickrail/issues/161)
- Improved Portal UX. Made add portal process cancellable, added option to remove the Portal again (https://github.com/Novakasa/brickrail/issues/94).

### Fixed

- Fix duplicate status messages for hubs in log messages panel (https://github.com/Novakasa/brickrail/issues/172).
- Fix invalid ble-server state when hub disconnects during program running (e.g. when battery is removed) (https://github.com/Novakasa/brickrail/issues/160).
- Fix pybricks error with motors with rotation encoders in pybricks 3.3-stable (https://github.com/Novakasa/brickrail/issues/174).
- Don't allow adding train to occupied block. This previously created invalid state.
- Fixed Switches and Crossing motors invalidated port when renaming a hub (https://github.com/Novakasa/brickrail/issues/163)

### Changed

## [v1.0.0-alpha.5]

### Added

- Added alternative train colors setting that makes each train color much more obvious at the cost of a unified color scheme.
- Improved reverse entry marker UX. User can remove the marker and cancel adding one (https://github.com/Novakasa/brickrail/issues/133).
- Markers associated with a selected logical block are now highlighted.
- Trains and Blocks can now be renamed by clicking their names in the inspector (https://github.com/Novakasa/brickrail/issues/122).
- Added debug color buffer and plot written to file after unexpected Marker (https://github.com/Novakasa/brickrail/issues/144)
- Spacebar now triggers emergency stop. For the extra urgent emergencies.
- Added automatic level crossings. Add a crossing in the track inspector, assign motors to layout controller ports and have them automatically run based on train routes (https://github.com/Novakasa/brickrail/issues/146).

### Fixed

- Fix BLEServer connection unsuccessful on ubuntu (https://github.com/Novakasa/brickrail/issues/162)
- Fix emergency stop not triggered due to hub state when control devices is set to "switches" (https://github.com/Novakasa/brickrail/issues/156).
- Prevent scanning the same hub (or same name) twice (https://github.com/Novakasa/brickrail/issues/109).
- Fix issues when trying to assign already used port with a device of different type. User now is warned and asked whether to override or cancel (https://github.com/Novakasa/brickrail/issues/148).
- Fix crash when trying to switch a switch back to it's original position while already switching. We now allow for switching anytime.
- Add retries to watchdog message to fix hub programs randomly stopping (https://github.com/Novakasa/brickrail/issues/140).
- Fixed program redownload not triggered when the common module "io_hub" has changed after an update (https://github.com/Novakasa/brickrail/issues/147)
- Fixed issue where BLEServer connect timeout would lead to log and dump files not saved to the correct directory (https://github.com/Novakasa/brickrail/issues/152)

### Changed

- Changed the internal ids for blocks and trains are now not the same as their names. This means old layout files will be converted. Issues with train positions might arise (https://github.com/Novakasa/brickrail/issues/122).
- Renamed "Sensor" to "Marker" and "Prior sensor" to "Reverse entry marker" in all user-facing contexts (https://github.com/Novakasa/brickrail/issues/135).
- ble-server log files will not be overwritten anymore (https://github.com/Novakasa/brickrail/issues/151)

## [v1.0.0-alpha.4] - 2023-06-18

### Added

- Added "Random target" and "Wait time" setting for logical blocks (https://github.com/Novakasa/brickrail/issues/86).
- Added "Random targets" setting for individual trains (https://github.com/Novakasa/brickrail/issues/86).
- Added orientation filter to individual tracks. This makes it possible to restrict trains to only use certain routes in a set forwards/backwards orientation (https://github.com/Novakasa/brickrail/issues/138).
- Added Notifications panel that displays info, warning and error messages chronologically. Messages can contain more info accessed by the `[...]` Button (https://github.com/Novakasa/brickrail/issues/134).
- Reenabled ability to set a name while creating a block.
- Added name display to inspector for most entities.
- Added customizable switch motor strength and duration (https://github.com/Novakasa/brickrail/issues/129)
- If any sensor in layout has a color different than None, the train will only react to markers with actually used colors. (https://github.com/Novakasa/brickrail/discussions/127)

### Fixed

- Fixed route locking issue where train would unlock track part of the next leg.
- Fixed wrong orientation of train wagon hitbox, leading to issues where mouse clicks on trains wouldn't be recognized properly if the train wagon is not at rotation 0.
- Fixed issue where you would click "through" a train if it is selected (https://github.com/Novakasa/brickrail/issues/131).
- Fixed potential issue where Brickrail would not detect changed hub programs on Windows (https://github.com/Novakasa/brickrail/discussions/128).

## [v1.0.0-alpha.3] - 2023-05-05

This release adds a number of usability improvements and quality of life features.

Brickrail now does not rely on specific pybricks firmware anymore and aims to be compatible with the current pybricks beta firmware. It is still recommended to flash the specific version that comes with the Release, since this is the version Brickrail is tested with.

### Added

- Added "discouraged" reversing behavior. With this option, the train will only reverse when there is no other option. (https://github.com/Novakasa/brickrail/issues/125)
- Distinguish current train position from "home" position. Current position is saved in settings, home position saved in .brl layout file. (https://github.com/Novakasa/brickrail/issues/78)
- Added "Download" checkbox to hub GUI. Unchecking it skips downloading the program to the hub, assuming that it is stored on the hub (https://github.com/Novakasa/brickrail/issues/92).
- Brickrail stores for each hub name the last hub program hash. If it is different, Download checkbox is checked automatically to make hub download the new program.
- Added File logging. Logs will be available in user folder.
- Added Control devices mode for switches only, allowing manual train control (https://github.com/Novakasa/brickrail/issues/77).
- Move view appropriately when changing "layers unfolded" or changing active Layer.
- Finally added ability to remove hubs from project.
- Make track section select easier by flipping the selection of single track appropriately.
- Automatically select connected track when deleting a single track segment.
- Current brickrail layout path now displayed in window title.
- Added configurable motor and sensor parameters to Trains (https://github.com/Novakasa/brickrail/issues/116, https://github.com/Novakasa/brickrail/issues/85).
- Added battery voltage display for hubs (https://github.com/Novakasa/brickrail/issues/111).
- Added ability to invert train motor polarity (https://github.com/Novakasa/brickrail/issues/112).
- Added layout changed label in status bar to highlight unsaved changes (and for debugging).
- Added robustness for crashed BLEServer, new button to manually start it again and display more errors related to BLEServer connection (https://github.com/Novakasa/brickrail/issues/51).

### Fixed

- Fixed issue when adding layer after loading a layout.
- Fixed requirement for program start timeout being very long by instead starting the timer after program was downloaded.
- Fixed some track connections not disconnected properly when deleting track.
- Fixed phantom prior sensors reappearing despite deleted after loading brickrail layouts (https://github.com/Novakasa/brickrail/issues/117).
- Disable Godot HiDPI setting, since we currently don't react to user OS-level DPI scaling (https://github.com/Novakasa/brickrail/discussions/107#discussioncomment-5689736).
- Fixed false unsaved changes prompt when train had been selected.
- Fixed "control devices" enabled despite error while starting hub program.

### Changed

- Moved away from frozen module in firmware. Brickrail should now be compatible with standard pybricks firmware.
- Allow enabling/disabling "only forward" setting for trains in "Control layout" mode.

## [v1.0.0-alpha.2] - 2023-04-21

### Fixed

- Fix TechnicHub dependency in LayoutController hub program (https://github.com/Novakasa/brickrail/issues/108).

## [v1.0.0-alpha.1] - 2023-04-15

<!-- diff links for headers -->
[Unreleased]: https://github.com/Novakasa/brickrail/compare/v1.0.0...HEAD
[v1.0.0]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.5...v1.0.0
[v1.0.0-alpha.5]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.4...v1.0.0-alpha.5
[v1.0.0-alpha.4]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.3...v1.0.0-alpha.4
[v1.0.0-alpha.3]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.2...v1.0.0-alpha.3
[v1.0.0-alpha.2]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.1...v1.0.0-alpha.2
[v1.0.0-alpha.1]: https://github.com/Novakasa/brickrail/tree/v1.0.0-alpha.1
