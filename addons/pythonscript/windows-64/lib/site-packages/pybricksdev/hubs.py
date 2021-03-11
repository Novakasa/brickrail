# SPDX-License-Identifier: MIT
# Copyright (c) 2020 The Pybricks Authors

"""This module has useful hub-specific information."""

from enum import IntEnum


class HubTypeId(IntEnum):
    """Hub type identifiers (as defined by LEGO)."""

    MOVE_HUB = 0x40
    """BOOST Move hub."""

    CITY_HUB = 0x41
    """City/train/Batmobile hub."""

    TECHNIC_HUB = 0x80
    """Technic medium (Control+) hub."""

    PRIME_HUB = 0x84
    """Technic large (SPIKE Prime, MINDSTORMS Inventor) hub."""
