# ROS2 Multi-Robot Swarm Launch File
# Launch 20 wheeled robots for swarm simulation
#
# Usage:
#   ros2 launch multi_robot_swarm swarm_simulation.launch.py
#
# Date: 2026-08-15

from launch import LaunchDescription
from launch_ros.actions import Node, SetParameter
from launch.actions import DeclareLaunchArgument, ExecuteProcess, TimerAction
from launch.substitutions import LaunchConfiguration
import os


def generate_launch_description():
    # Number of robots
    num_robots = 20

    # Robot namespace list
    robot_names = [f"formicabot_{i}" for i in range(num_robots)]

    # Declare launch arguments
    declared_arguments = []

    # Simulation time
    sim_time_arg = DeclareLaunchArgument(
        "sim_time", default_value="60.0", description="Simulation time in seconds"
    )
    declared_arguments.append(sim_time_arg)

    # Arena size
    arena_size_arg = DeclareLaunchArgument(
        "arena_size", default_value="8.0", description="Arena size in meters"
    )
    declared_arguments.append(arena_size_arg)

    # Robot parameters
    declared_arguments.append(
        DeclareLaunchArgument(
            "robot_radius", default_value="0.08", description="Robot radius in meters"
        )
    )

    declared_arguments.append(
        DeclareLaunchArgument(
            "max_speed", default_value="0.15", description="Maximum robot speed in m/s"
        )
    )

    declared_arguments.append(
        DeclareLaunchArgument(
            "pheromone_decay",
            default_value="0.02",
            description="Pheromone decay rate per second",
        )
    )

    # Initialize nodes list
    nodes = []

    # ============================================
    # CENTRAL COORDINATOR NODE
    # ============================================
    coordinator_node = Node(
        package="multi_robot_swarm",
        executable="coordinator",
        name="swarm_coordinator",
        parameters=[
            {
                "num_robots": num_robots,
                "arena_width": 8.0,
                "arena_height": 8.0,
                "sim_time": 60.0,
                "pheromone_decay": 0.02,
                "deposit_intensity": 200.0,
            }
        ],
        output="screen",
        emulate_tty=True,
    )
    nodes.append(coordinator_node)

    # ============================================
    # PHEROMONE GRID NODE
    # ============================================
    pheromone_node = Node(
        package="multi_robot_swarm",
        executable="pheromone_grid",
        name="pheromone_grid",
        parameters=[
            {
                "grid_resolution": 0.05,
                "arena_width": 8.0,
                "arena_height": 8.0,
                "decay_rate": 0.02,
                "max_intensity": 255.0,
            }
        ],
        output="screen",
    )
    nodes.append(pheromone_node)

    # ============================================
    # ROBOT NODES (20 robots)
    # ============================================
    for i in range(num_robots):
        robot_ns = robot_names[i]

        # Calculate initial position (grid layout)
        row = i // 5
        col = i % 5
        init_x = 1.0 + col * 1.2
        init_y = 1.0 + row * 1.2

        # Robot state publisher
        robot_node = Node(
            package="multi_robot_swarm",
            executable="robot_node",
            name=f"robot_{i}",
            namespace=robot_ns,
            parameters=[
                {
                    "robot_id": i,
                    "initial_x": init_x,
                    "initial_y": init_y,
                    "initial_theta": 0.0,
                    "max_speed": 0.15,
                    "turn_rate": 1.5,
                    "robot_radius": 0.08,
                    "pheromone_threshold": 10.0,
                }
            ],
            output="screen",
            emulate_tty=True,
        )
        nodes.append(robot_node)

        # Robot visualization (RViz marker)
        viz_node = Node(
            package="multi_robot_swarm",
            executable="robot_viz",
            name=f"viz_{i}",
            namespace=robot_ns,
            parameters=[
                {
                    "robot_id": i,
                    "color_r": 0.0,
                    "color_g": 0.0,
                    "color_b": 1.0,
                }
            ],
            output="screen",
        )
        nodes.append(viz_node)

    # ============================================
    # VISUALIZATION NODES
    # ============================================

    # RViz configuration
    rviz_config = os.path.join(os.path.dirname(__file__), "config", "swarm.rviz")

    rviz_node = Node(
        package="rviz2",
        executable="rviz2",
        name="rviz2",
        arguments=["-d", rviz_config],
        output="screen",
    )

    # Add delayed RViz start
    rviz_timer = TimerAction(period=2.0, actions=[rviz_node])
    nodes.append(rviz_timer)

    # ============================================
    # DATA LOGGER NODE
    # ============================================
    logger_node = Node(
        package="multi_robot_swarm",
        executable="data_logger",
        name="data_logger",
        parameters=[
            {
                "log_file": "swarm_simulation_log.csv",
                "log_rate": 10.0,
            }
        ],
        output="screen",
    )
    nodes.append(logger_node)

    # ============================================
    # VIDEO RECORDER (optional)
    # ============================================
    recorder_node = Node(
        package="rosbag2",
        executable="record",
        name="bag_recorder",
        arguments=["-a", "-o", "swarm_simulation_bag"],
        output="screen",
    )
    nodes.append(recorder_node)

    return LaunchDescription(declared_arguments + nodes)
