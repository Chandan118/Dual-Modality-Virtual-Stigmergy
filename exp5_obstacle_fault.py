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
from nav_msgs.msg import Odometry


def timestamped_filename(prefix, ext):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"exp5_{prefix}_{ts}.{ext}"


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
        min_range = min(r for r in msg.ranges if r > 0)
        if min_range < 0.3:
            self.fault_events.append({'event': 'obstacle_detected', 'timestamp_s': time.time() - self.start_time,
                                       'distance': min_range})

    def save_results(self):
        out_dir = os.path.join(os.path.expanduser('~'), 'formica_experiments', 'data')
        os.makedirs(out_dir, exist_ok=True)

        fname = os.path.join(out_dir, timestamped_filename('fault', 'csv'))
        with open(fname, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['event', 'timestamp_s', 'recovery_time_s'])
            writer.writeheader()
            for i, event in enumerate(self.fault_events):
                recovery = self.recovery_times[i] if i < len(self.recovery_times) else ''
                writer.writerow({'event': event, 'timestamp_s': recovery, 'recovery_time_s': ''})
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
