import importlib
import os
import sys
import types
import unittest
from types import SimpleNamespace


def _install_ros_stubs():
    if "rclpy" not in sys.modules:
        rclpy = types.ModuleType("rclpy")
        rclpy.init = lambda *args, **kwargs: None
        rclpy.spin = lambda *args, **kwargs: None
        rclpy.shutdown = lambda *args, **kwargs: None
        sys.modules["rclpy"] = rclpy

    if "rclpy.node" not in sys.modules:
        node_mod = types.ModuleType("rclpy.node")

        class Node:
            def __init__(self, *args, **kwargs):
                pass

        node_mod.Node = Node
        sys.modules["rclpy.node"] = node_mod

    for module_name, class_names in {
        "sensor_msgs.msg": ["Imu", "LaserScan", "Image"],
        "nav_msgs.msg": ["Odometry", "OccupancyGrid"],
        "std_msgs.msg": ["Float32MultiArray", "Float32", "String"],
        "geometry_msgs.msg": ["Twist", "PoseStamped", "PoseWithCovarianceStamped"],
    }.items():
        if module_name not in sys.modules:
            mod = types.ModuleType(module_name)
            for class_name in class_names:
                setattr(mod, class_name, type(class_name, (), {}))
            sys.modules[module_name] = mod


_install_ros_stubs()


class ExperimentRobustnessTests(unittest.TestCase):
    def test_output_dir_default_and_override(self):
        module_names = [
            "exp1_sensor_calibration",
            "exp2_power_profiling",
            "exp3_slam_mapping",
            "exp4_maze_navigation",
            "exp5_obstacle_fault",
            "exp6_cnn_detection",
            "exp7_pheromone_trail",
        ]

        for module_name in module_names:
            mod = importlib.import_module(module_name)

            default_dir = mod.get_output_dir()
            self.assertTrue(default_dir.endswith(os.path.join("bio-inspired-thesis-chapter6", "data")))

            os.environ["FORMICA_DATA_DIR"] = "/tmp/formica_output"
            try:
                self.assertEqual(mod.get_output_dir(), "/tmp/formica_output")
            finally:
                os.environ.pop("FORMICA_DATA_DIR", None)

    def test_exp7_scan_callback_handles_empty_valid_ranges(self):
        mod = importlib.import_module("exp7_pheromone_trail")

        follower = mod.PheromoneFollower.__new__(mod.PheromoneFollower)
        follower.samples = [{"sensor_type": "line"}]

        follower.scan_callback(SimpleNamespace(ranges=[0.0, float("inf")]))
        self.assertFalse(follower.samples[-1]["path_clear"])

        follower.scan_callback(SimpleNamespace(ranges=[0.6, 0.9]))
        self.assertTrue(follower.samples[-1]["path_clear"])


if __name__ == "__main__":
    unittest.main()
