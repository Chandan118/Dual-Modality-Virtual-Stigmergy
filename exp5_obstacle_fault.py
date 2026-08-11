#!/usr/bin/env python3
"""
exp5_obstacle_fault.py — Experiment 5
====================================
Obstacle avoidance and sensor failure handling.

Run:
    python exp5_obstacle_fault.py
"""

import csv
import os
import time
from datetime import datetime

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import LaserScan


def timestamped_filename(prefix, ext):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"exp5_{prefix}_{ts}.{ext}"


def get_output_dir():
    return os.path.abspath(
        os.environ.get(
            "FORMICA_DATA_DIR",
            os.path.join(os.path.dirname(__file__), "data"),
        )
    )


class FaultTolerantNavigator(Node):
    def __init__(self):
        super().__init__('exp5_obstacle_fault')

        self.fault_events = []
        self.recovery_times = []
        self.start_time = time.time()

        self.scan_sub = self.create_subscription(
            LaserScan, '/scan', self.scan_callback, 10)

        self.get_logger().info('Fault tolerant navigator started.')

    def scan_callback(self, msg: LaserScan):
        valid_ranges = [r for r in msg.ranges if r > 0.0 and r != float('inf')]
        if not valid_ranges:
            return

        min_range = min(valid_ranges)
        if min_range < 0.3:
            self.fault_events.append({
                'event': 'obstacle_detected',
                'timestamp_s': time.time() - self.start_time,
                'distance': min_range,
            })

    def save_results(self):
        out_dir = get_output_dir()
        os.makedirs(out_dir, exist_ok=True)

        fname = os.path.join(out_dir, timestamped_filename('fault', 'csv'))
        with open(fname, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['event', 'timestamp_s', 'distance', 'recovery_time_s'])
            writer.writeheader()
            for i, event in enumerate(self.fault_events):
                recovery = self.recovery_times[i] if i < len(self.recovery_times) else ''
                writer.writerow({
                    'event': event.get('event', ''),
                    'timestamp_s': event.get('timestamp_s', ''),
                    'distance': event.get('distance', ''),
                    'recovery_time_s': recovery,
                })
        self.get_logger().info(f"Results saved to {fname}")


def main():
    rclpy.init()
    node = FaultTolerantNavigator()
    try:
        rclpy.spin(node)
    finally:
        node.save_results()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
