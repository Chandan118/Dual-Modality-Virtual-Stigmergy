#!/usr/bin/env python3


import csv
import os
import statistics
import time
from datetime import datetime

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Imu, LaserScan
from nav_msgs.msg import Odometry
from std_msgs.msg import Float32MultiArray, Float32, String
from geometry_msgs.msg import Twist


def timestamped_filename(prefix, ext):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"exp1_{prefix}_{ts}.{ext}"


class SensorCalibrator(Node):
    def __init__(self):
        super().__init__("exp1_sensor_calibration")

        self.lidar_readings = []
        self.imu_readings = []
        self.odom_distances = []
        self.line_sensors = []
        self.gas_sensor = []
        self.camera_ok = False

        self.lidar_sub = self.create_subscription(
            LaserScan, "/scan", self.lidar_callback, 10
        )
        self.imu_sub = self.create_subscription(Imu, "/imu/data", self.imu_callback, 10)
        self.odom_sub = self.create_subscription(
            Odometry, "/odom", self.odom_callback, 10
        )
        self.line_sub = self.create_subscription(
            Float32MultiArray, "/line_sensors", self.line_callback, 10
        )
        self.gas_sub = self.create_subscription(
            Float32, "/gas_sensor", self.gas_callback, 10
        )
        self.camera_sub = self.create_subscription(
            String, "/camera/status", self.camera_callback, 10
        )

        self.get_logger().info(
            "Sensor calibration node started. "
            "Move robot through calibration routine."
        )

    def lidar_callback(self, msg: LaserScan):
        self.lidar_readings.append(msg.ranges)

    def imu_callback(self, msg: Imu):
        self.imu_readings.append(msg)

    def odom_callback(self, msg: Odometry):
        self.odom_distances.append(msg.pose.pose.position)

    def line_callback(self, msg: Float32MultiArray):
        self.line_sensors.append(msg.data)

    def gas_callback(self, msg: Float32):
        self.gas_sensor.append(msg.data)

    def camera_callback(self, msg: String):
        self.camera_ok = msg.data == "ok"

    def calibrate_lidar(self):
        """Measure LiDAR accuracy at known distances."""
        if not self.lidar_readings:
            self.get_logger().warn("No LiDAR readings collected")
            return None
        all_ranges = [r for readings in self.lidar_readings for r in readings if r]
        if all_ranges:
            return {
                "min_range": min(all_ranges),
                "max_range": max(all_ranges),
                "mean_range": sum(all_ranges) / len(all_ranges),
                "sample_count": len(all_ranges),
            }
        return None

    def calibrate_imu(self):
        """Measure IMU drift over time."""
        if len(self.imu_readings) < 2:
            self.get_logger().warn("Insufficient IMU readings for drift analysis")
            return None
        angular_velocities = [msg.angular_velocity.z for msg in self.imu_readings]
        return {
            "mean_drift": sum(angular_velocities) / len(angular_velocities),
            "max_drift": max(angular_velocities),
            "sample_count": len(angular_velocities),
        }

    def calibrate_odom(self):
        """Measure odometry error over known distance."""
        if len(self.odom_distances) < 2:
            self.get_logger().warn("Insufficient odometry data for calibration")
            return None
        distances = [(msg.x**2 + msg.y**2) ** 0.5 for msg in self.odom_distances]
        return {
            "mean_distance": sum(distances) / len(distances),
            "sample_count": len(distances),
        }

    def check_all_sensors(self):
        """Verify all sensors are publishing."""
        self.get_logger().info(
            f"LiDAR samples: {len(self.lidar_readings)}, "
            f"IMU samples: {len(self.imu_readings)}, "
            f"Odom samples: {len(self.odom_distances)}, "
            f"Line sensors: {len(self.line_sensors)}, "
            f"Gas sensor: {len(self.gas_sensor)}, "
            f"Camera: {self.camera_ok}"
        )

    def save_results(self):
        """Write calibration results to CSV."""
        out_dir = os.path.join(os.path.expanduser("~"), "formica_experiments", "data")
        os.makedirs(out_dir, exist_ok=True)

        fname = os.path.join(out_dir, timestamped_filename("calibration", "csv"))
        with open(fname, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["timestamp", "sensor", "value"])
            ts = datetime.now().isoformat()
            for r in self.lidar_readings:
                writer.writerow([ts, "lidar", r])
            for r in self.imu_readings:
                writer.writerow([ts, "imu_angular_velocity_z", r.angular_velocity.z])
        self.get_logger().info(f"Results saved to {fname}")


def main():
    rclpy.init()
    node = SensorCalibrator()
    try:
        rclpy.spin(node)
    finally:
        node.save_results()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
