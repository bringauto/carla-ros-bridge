# ROS 2 bridge for CARLA simulator v0.9.16

This ROS package is a modified fork of the [carla-simulator/ros-bridge](https://github.com/carla-simulator/ros-bridge) package (branched via [ttgamage/carla-ros-bridge](https://github.com/ttgamage/carla-ros-bridge), which carries the scenario and demo-default tweaks this fork inherited), adapted to work with **CARLA 0.9.16** and **ROS 2 Jazzy** on Ubuntu 24.04 LTS, with Scenario Runner v0.9.16. The ROS bridge enables two-way communication between ROS and CARLA. The information from the CARLA server is translated to ROS topics. In the same way, the messages sent between nodes in ROS get translated to commands to be applied in CARLA.

## Main Requirements

- OS: Ubuntu 24.04 LTS
- CARLA Version: 0.9.16
- Scenario Runner Version: 0.9.16
- ROS Version: Jazzy
- **NOTE**: Testing was performed with Python 3.12 (the default interpreter on Ubuntu 24.04). The CARLA Python API is installed from the `cp3XX` wheel shipped in `PythonAPI/carla/dist` that matches the interpreter; the Docker build falls back to the legacy `.egg`-on-`PYTHONPATH` scheme when no matching wheel is present.
- `carla_ros_bridge` enforces an exact version match between `carla_ros_bridge/src/carla_ros_bridge/CARLA_VERSION` and the installed CARLA Python module at startup, so the installed CARLA API must also be 0.9.16.

### Screenshot of Carla AD Demo in Action

![rviz setup](./docs/images/ad_demo.png "AD Demo")

## Why this fork was ported to CARLA 0.9.16

The fork exists because we moved the simulation stack to CARLA 0.9.16 on ROS 2 Jazzy, and the bridge had to come with it: our vehicle stack is wired to the bridge's topic names, `carla_msgs` types, spawn services and closed-loop control path. Porting the bridge was the cheapest way to keep that contract intact across the CARLA upgrade — the alternative, rewriting the stack against CARLA's native ROS 2 interface, would have meant reimplementing most of what the bridge already does (see below).

CARLA 0.9.16 advertises a *native* ROS 2 interface built into the simulator server (FastDDS publishers/subscribers in `LibCarla/source/carla/ros2`, enabled by building the server with `--ros2` and launching it with `-ros2`). It does **not** replace this bridge for our use case. The native interface covers sensor streams plus a single control input; it does not reproduce the topic, service and message surface that this repository's packages — and the stacks built on top of them — depend on. Note also that the native interface is not new in 0.9.16 — the same code is present at tag 0.9.15, and the only ROS-related entries in the 0.9.16 changelog are two build fixes.

What the native 0.9.16 interface provides:

- Sensor publishers: camera (RGB/depth/semantic/instance/normals/optical flow/DVS), lidar, semantic lidar, radar, IMU, GNSS, collision
- `/clock` and `/tf`
- Per-vehicle subscribers: `vehicle_control_cmd` (`carla_msgs/CarlaEgoVehicleControl`) and `ackermann_control_cmd` (`ackermann_msgs/AckermannDriveStamped`)

What it does **not** provide, and this bridge does:

- Vehicle feedback: `/carla/<role>/odometry`, `/carla/<role>/vehicle_status`, `/carla/<role>/vehicle_info` (no odometry publisher is instantiated natively)
- World and scene state: `/carla/world_info`, `/carla/map`, `/carla/objects`, `/carla/actor_list`, `/carla/markers`, `/carla/traffic_lights/info`, `/carla/traffic_lights/status`
- Simulation control: `/carla/status`, `/carla/control`, `/carla/weather_control`, synchronous-mode stepping, `passive` mode and `synchronous_mode_wait_for_vehicle_control_command`
- ROS services: `/carla/spawn_object`, `/carla/destroy_object`, `/carla/get_blueprints` — the native layer is DDS publishers/subscribers only, it exposes no services at all
- Walker control (`/carla/<role>/walker_control_cmd`) and everything the sibling packages in this repo build on the above: `carla_spawn_objects`, `carla_ackermann_control` (closed-loop PID on top of vehicle status), `carla_waypoint_publisher`, `carla_ad_agent`/`carla_ad_demo`, `carla_manual_control`, `carla_twist_to_control`, `carla_ros_scenario_runner`, `rviz_carla_plugin`, `rqt_carla_control`

Additional practical caveats:

- The native interface is a compile-time option (`USE_ROS2=false` by default in `Util/BuildTools/BuildCarlaUE4.sh`), so a stock CARLA package has it compiled out; using it means building the server from source.
- It is not documented in the CARLA 0.9.16 (UE4) documentation — the only ROS page there still points at the ROS bridge. The `ros2_native` documentation belongs to the CARLA UE5 line.
- Native topic names are derived from the `ros_name` blueprint attribute rather than from the bridge's `/carla/<role_name>/<sensor_name>` convention, so downstream remapping would be required even for the sensors it does cover.
- Unconfirmed, but worth knowing before betting on it: [carla#9408](https://github.com/carla-simulator/carla/issues/9408) reports that on 0.9.16 with ROS 2 Jazzy the native control topics exist and accept messages, but the vehicle does not react. Single user report, no maintainer response at the time of writing.

In short: the native interface is a lower-latency sensor tap with a control inlet, not a drop-in replacement for the bridge. Keeping the bridge preserves the existing topic names, `carla_msgs` types, services and control path that our vehicle stack is already wired to.

## Instructions (adapted from [ROS Bridge Documentation](https://carla.readthedocs.io/projects/ros-bridge/en/latest/ros_installation_ros2/))

1. Set up a project directory and clone the ROS bridge repository and submodules:
```
mkdir -p ~/Workspace/ros-bridge && cd ~/Workspace/ros-bridge
git clone --recurse-submodules https://github.com/bringauto/carla-ros-bridge.git
mv carla-ros-bridge src
```
2. Set up ROS environment and install dependencies:
```
source /opt/ros/jazzy/setup.bash
rosdep update
rosdep install --from-paths src --ignore-src -r
```
3. Build the ROS bridge workspace using colcon:
```
colcon build --symlink-install
```

### Docker

`build.sh` resolves paths relative to its own directory only under bash, so run it from `docker/`. `CARLA_VERSION` is read from `carla_ros_bridge/src/carla_ros_bridge/CARLA_VERSION`; `ROS_DISTRO` defaults to `foxy` and must be overridden:

```
cd docker
./build.sh -r jazzy      # builds carla-ros-bridge:jazzy
./run.sh -t jazzy
```

The image pulls the CARLA Python API from the `carlasim/carla:<CARLA_VERSION>` image (`/workspace/PythonAPI` in the 0.9.16 layout; older CARLA images used `/home/carla`).
