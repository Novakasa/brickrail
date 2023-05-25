<!-- Refer to https://keepachangelog.com/en/1.0.0/ for guidance. -->
<!-- template stolen from pybricks-micropython repository -->

# Changelog

## [Unreleased]

### Added

- Added Notifications panel that displays info, warning and error messages chronologically. Messages can contain more info accessed by the `[...]` Button (https://github.com/Novakasa/brickrail/issues/134).
- Reenabled ability to set a name while creating a block.
- Added name display to inspector for most entities.
- Added customizable switch motor strength and duration (https://github.com/Novakasa/brickrail/issues/129)
- If any sensor in layout has a color different than None, the train will only react to markers with actually used colors. (https://github.com/Novakasa/brickrail/discussions/127)

### Fixed

- Fixed route locking issue where train would unlock track part of the next leg.
- Fixed wrong orientation of train wagon hitbox, leading to issues where mouse clicks on trains wouldn't be recognized properly if the train wagon is not at rotation 0.
- Fixed issue where you would click "through" a train if it is selected (https://github.com/Novakasa/brickrail/issues/131).
- Fixed potential issue where Brickrail would not detect change hub programs on Windows (https://github.com/Novakasa/brickrail/discussions/128).

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
[Unreleased]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.3...HEAD
[v1.0.0-alpha.2]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.1...v1.0.0-alpha.3
[v1.0.0-alpha.2]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.1...v1.0.0-alpha.2
[v1.0.0-alpha.1]: https://github.com/Novakasa/brickrail/tree/v1.0.0-alpha.1
