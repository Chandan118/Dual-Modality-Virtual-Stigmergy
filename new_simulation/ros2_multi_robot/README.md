# Multi-Robot Swarm ROS2 Package

## Overview
ROS2 package for multi-robot swarm simulation with 20 wheeled FormicaBot robots.

## Files
- `launch/swarm_simulation.launch.py` - Main launch file
- `config/swarm_config.yaml` - Configuration parameters
- `config/swarm.rviz` - RViz visualization config
- `urdf/formicabot.urdf` - Robot description
- `scripts/multi_robot_nodes.py` - ROS2 nodes

## Build
```bash
cd ~/ros2_ws
colcon build --packages-select multi_robot_swarm
source install/setup.bash
```

## Run
```bash
ros2 launch multi_robot_swarm swarm_simulation.launch.py
```

## Parameters
- Number of robots: 20
- Arena size: 8m x 8m
- Simulation time: 60 seconds
- Robot speed: 0.15 m/s
- Pheromone decay: 0.02/s
