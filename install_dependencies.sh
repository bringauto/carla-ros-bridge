#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SUFFIX="3"
if [ "$ROS_PYTHON_VERSION" = "3" ]; then
    PYTHON_SUFFIX=3
fi

# ROS_DISTRO comes from the sourced ROS setup.bash; default to jazzy if unset.
# (Previously hardcoded to 'humble', which broke the jazzy/noble build: the
# ros-humble-* names below do not exist on noble, so the single apt-get install
# aborted and installed nothing -- no pip, no rviz, no ROS deps.)
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
echo ${ROS_DISTRO}

if [ "${ROS_VERSION}" = "1" ]; then
    ADDITIONAL_PACKAGES="ros-${ROS_DISTRO}-rviz
                         ros-${ROS_DISTRO}-opencv-apps
                         ros-${ROS_DISTRO}-rospy
                         ros-${ROS_DISTRO}-rospy-message-converter
                         ros-${ROS_DISTRO}-pcl-ros"
else
    ADDITIONAL_PACKAGES="ros-${ROS_DISTRO}-rviz2"
fi

if [ "$(lsb_release -sc)" = "focal" ]; then
    ADDITIONAL_PACKAGES="$ADDITIONAL_PACKAGES
                         python-is-python3"
fi

echo ADDITIONAL PACKAGES $ADDITIONAL_PACKAGES

# Dropped vs the original ROS1/legacy list (not available on noble, and unused
# by the ROS 2 build): python3-catkin-tools, python3-wstool, qt5-default.
sudo apt update
sudo apt-get install --no-install-recommends -y \
    python$PYTHON_SUFFIX-pip \
    python$PYTHON_SUFFIX-osrf-pycommon \
    python$PYTHON_SUFFIX-catkin-pkg \
    python$PYTHON_SUFFIX-catkin-pkg-modules \
    python$PYTHON_SUFFIX-rosdep \
    python$PYTHON_SUFFIX-opencv \
    ros-${ROS_DISTRO}-ackermann-msgs \
    ros-${ROS_DISTRO}-derived-object-msgs \
    ros-${ROS_DISTRO}-cv-bridge \
    ros-${ROS_DISTRO}-vision-opencv \
    ros-${ROS_DISTRO}-rqt-image-view \
    ros-${ROS_DISTRO}-rqt-gui-py \
    wget \
    ros-${ROS_DISTRO}-pcl-conversions \
    $ADDITIONAL_PACKAGES

# --break-system-packages: Ubuntu 24.04 (noble) marks the system env as
# externally-managed (PEP 668); without it these installs error out.
pip$PYTHON_SUFFIX install --break-system-packages -r $SCRIPT_DIR/requirements.txt
