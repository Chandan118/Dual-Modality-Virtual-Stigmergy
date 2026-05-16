# FormicaBot Experimental Validation

Chapter 6 experimental validation code for FormicaBot — a single-robot platform based on NVIDIA Jetson Orin Nano 8GB and ROS 2 Humble.

## Robot Platform

- **Hardware**: NVIDIA Jetson Orin Nano 8GB
- **ROS Version**: ROS 2 Humble
- **Sensors**: RPLIDAR A1, Arduino base with line sensors, Azure Kinect camera, IMU (MPU6050)
- **Actuators**: Differential drive base with motor control via Arduino

## Experiments

| Exp | Name | Description |
|-----|------|-------------|
| 1 | Sensor Calibration | LiDAR, IMU, camera, line/gas sensor calibration |
| 2 | Power Profiling | INA219 power monitoring over mission duration |
| 3 | SLAM Mapping | Online SLAM with landmark detection |
| 4 | Maze Navigation | Nav2 autonomous navigation in known map |
| 5 | Fault Tolerance | Obstacle avoidance and sensor failure handling |
| 6 | CNN Detection | TensorRT-based target recognition |
| 7 | Pheromone Trail | LED trail following with ethanol detection |

## Data

Experiment output CSV files are stored in `data/`. Timestamps in filenames follow `exp{N}_{type}_{YYYYMMDD}_{HHMMSS}.csv`.

| Prefix | Experiment |
|--------|------------|
| `exp1_calibration_*` | Sensor calibration measurements |
| `exp2_power_*` | Power profiling time series |
| `exp3_slam_*` | SLAM pose and map data |
| `exp4_maze_*` | Maze navigation trial results |
| `exp5_fault_*` | Fault injection and recovery events |
| `exp6_cnn_*` | CNN detection frames and confidences |
| `exp7_pheromone_*` | Pheromone trail following data |
| `exp7_task2_mq_ethanol_*` | MQ-3 ethanol sensor measurements |

## Running Experiments

```bash
# Experiment 1: Sensor Calibration
python exp1_sensor_calibration.py

# Experiment 2: Power Profiling
python exp2_power_profiling.py

# Experiment 3: SLAM Mapping
python exp3_slam_mapping.py

# Experiment 4: Maze Navigation
python exp4_maze_navigation.py

# Experiment 5: Fault Tolerance
python exp5_obstacle_fault.py

# Experiment 6: CNN Detection
python exp6_cnn_detection.py

# Experiment 7: Pheromone Trail
python exp7_pheromone_trail.py
```

## Citation

```
@software{formica_experiments,
  title = {FormicaBot Chapter 6 Experimental Validation},
  author = {Chandan Sheikder},
  year = {2026},
  url = {https://github.com/Chandan118/bio-inspired-thesis-chapter6}
}
```

## License

MIT License

## Contributors

Thanks to all contributors who have helped improve this repository:

<!-- readme: contributors start -->
<!-- readme: contributors end -->

## Acknowledgments

This project was developed as part of thesis research on bio-inspired robotics.
