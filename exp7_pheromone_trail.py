#!/usr/bin/env python3


import csv
import os
import time
from datetime import datetime

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import LaserScan
from std_msgs.msg import Float32, Float32MultiArray


def timestamped_filename(prefix, ext):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"exp7_{prefix}_{ts}.{ext}"


class PheromoneFollower(Node):
    def __init__(self):
        super().__init__('exp7_pheromone_trail')

        self.samples = []
        self.start_time = time.time()

        self.line_sub = self.create_subscription(
            Float32MultiArray, '/line_sensors', self.line_callback, 10)
        self.gas_sub = self.create_subscription(
            Float32, '/gas_sensor', self.gas_callback, 10)
        self.scan_sub = self.create_subscription(
            LaserScan, '/scan', self.scan_callback, 10)

        self.get_logger().info('Pheromone trail follower started.')

    def line_callback(self, msg: Float32MultiArray):
        self.samples.append({
            'timestamp_s': time.time() - self.start_time,
            'sensor_type': 'line',
            'values': list(msg.data),
        })

    def gas_callback(self, msg: Float32):
        self.samples.append({
            'timestamp_s': time.time() - self.start_time,
            'sensor_type': 'gas',
            'values': [msg.data],
        })

    def scan_callback(self, msg: LaserScan):
        if self.samples and self.samples[-1]['sensor_type'] == 'line':
            self.samples[-1]['path_clear'] = min(r for r in msg.ranges if r > 0) > 0.5

    def save_results(self):
        out_dir = os.path.join(os.path.expanduser('~'), 'formica_experiments', 'data')
        os.makedirs(out_dir, exist_ok=True)

        fname = os.path.join(out_dir, timestamped_filename('pheromone', 'csv'))
        with open(fname, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['timestamp_s', 'sensor_type', 'values'])
            writer.writeheader()
            writer.writerows(self.samples)
        self.get_logger().info(f"Results saved to {fname}")


def main():
    rclpy.init()
    node = PheromoneFollower()
    try:
        rclpy.spin(node)
    finally:
        node.save_results()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
