#!/usr/bin/env python3


import csv
import os
import time
from datetime import datetime

import rclpy
from rclpy.node import Node
from std_msgs.msg import Float32, Float32MultiArray


def timestamped_filename(prefix, ext):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"exp2_{prefix}_{ts}.{ext}"


class PowerProfiler(Node):
    def __init__(self):
        super().__init__("exp2_power_profiling")

        self.power_samples = []
        self.start_time = time.time()

        self.current_sub = self.create_subscription(
            Float32, "/power/current_A", self.current_callback, 10
        )
        self.voltage_sub = self.create_subscription(
            Float32, "/power/voltage_V", self.voltage_callback, 10
        )

        self.get_logger().info("Power profiler started.")

    def current_callback(self, msg: Float32):
        self.power_samples.append(
            {
                "timestamp_s": time.time() - self.start_time,
                "current_A": msg.data,
            }
        )

    def voltage_callback(self, msg: Float32):
        if self.power_samples:
            self.power_samples[-1]["voltage_V"] = msg.data
            self.power_samples[-1]["power_W"] = (
                self.power_samples[-1]["current_A"] * msg.data
            )

    def save_results(self):
        out_dir = os.path.join(os.path.expanduser("~"), "formica_experiments", "data")
        os.makedirs(out_dir, exist_ok=True)

        fname = os.path.join(out_dir, timestamped_filename("power", "csv"))
        with open(fname, "w", newline="") as f:
            writer = csv.DictWriter(
                f, fieldnames=["timestamp_s", "current_A", "voltage_V", "power_W"]
            )
            writer.writeheader()
            writer.writerows(self.power_samples)
        self.get_logger().info(f"Results saved to {fname}")


def main():
    rclpy.init()
    node = PowerProfiler()
    try:
        rclpy.spin(node)
    finally:
        node.save_results()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
