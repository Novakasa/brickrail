<!-- Refer to https://keepachangelog.com/en/1.0.0/ for guidance. -->
<!-- template stolen from pybricks-micropython repository -->

# Changelog

## [Unreleased]

### Added

- Added configurable motor and sensor parameters to Trains (https://github.com/Novakasa/brickrail/issues/116, https://github.com/Novakasa/brickrail/issues/85)
- Added battery voltage display for hubs (requires new firmware) (https://github.com/Novakasa/brickrail/issues/111)
- Added ability to invert train motor polarity (https://github.com/Novakasa/brickrail/issues/112)
- Added layout changed label in status bar to highlight unsaved changes (and for debugging)
- Added robustness for crashed BLEServer, new button to manually start it again and display more errors related to BLEServer connection (https://github.com/Novakasa/brickrail/issues/51)

### Fixed

- Fixed phantom prior sensors reappearing despite deleted after loading brickrail layouts (https://github.com/Novakasa/brickrail/issues/117)
- Disable Godot HiDPI setting, since we currently don't react to user OS-level DPI scaling (https://github.com/Novakasa/brickrail/discussions/107#discussioncomment-5689736).
- Fixed false unsaved changes prompt when train had been selected
- Fixed "control devices" enabled despite error while starting hub program

### Changed

- Allow enabling/disabling "only forward" setting for trains in "Control layout" mode.

## [v1.0.0-alpha.2] - 2023-04-21

### Fixed

- Fix TechnicHub dependency in LayoutController hub program (https://github.com/Novakasa/brickrail/issues/108).

## [v1.0.0-alpha.1] - 2023-04-15

<!-- diff links for headers -->
[Unreleased]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.2...HEAD
[v1.0.0-alpha.2]: https://github.com/Novakasa/brickrail/compare/v1.0.0-alpha.1...v1.0.0-alpha.2
[v1.0.0-alpha.1]: https://github.com/Novakasa/brickrail/tree/v1.0.0-alpha.1
