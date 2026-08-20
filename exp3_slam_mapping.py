#!/usr/bin/env python3


import csv
import os
import time
from datetime import datetime

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import LaserScan
from nav_msgs.msg import Odometry, OccupancyGrid
from geometry_msgs.msg import PoseWithCovarianceStamped


def timestamped_filename(prefix, ext):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"exp3_{prefix}_{ts}.{ext}"


class SlamMapper(Node):
    def __init__(self):
        super().__init__('exp3_slam_mapping')

        self.scan_count = 0
        self.pose_samples = []
        self.map_received = False
        self.start_time = time.time()

        self.scan_sub = self.create_subscription(
            LaserScan, '/scan', self.scan_callback, 10)
        self.pose_sub = self.create_subscription(
            PoseWithCovarianceStamped, '/amcl_pose', self.pose_callback, 10)
        self.map_sub = self.create_subscription(
            OccupancyGrid, '/map', self.map_callback, 10)

        self.get_logger().info('SLAM mapper started.')

    def scan_callback(self, msg: LaserScan):
        self.scan_count += 1
        if self.scan_count % 100 == 0:
            self.get_logger().info(f"Scans processed: {self.scan_count}")

    def pose_callback(self, msg: PoseWithCovarianceStamped):
        self.pose_samples.append({
            'timestamp_s': time.time() - self.start_time,
            'x': msg.pose.pose.position.x,
            'y': msg.pose.pose.position.y,
            'covariance_xx': msg.pose.covariance[0],
            'covariance_yy': msg.pose.covariance[7],
        })

    def map_callback(self, msg: OccupancyGrid):
        self.map_received = True
        self.get_logger().info(
            f"Map received: {msg.info.width}x{msg.info.height} "
            f"@ {msg.info.resolution}m/pixel"
        )

    def save_results(self):
        out_dir = os.path.join(os.path.expanduser('~'), 'formica_experiments', 'data')
        os.makedirs(out_dir, exist_ok=True)

        fname = os.path.join(out_dir, timestamped_filename('slam', 'csv'))
        with open(fname, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['timestamp_s', 'x', 'y', 'covariance_xx', 'covariance_yy'])
            writer.writeheader()
            writer.writerows(self.pose_samples)
        self.get_logger().info(f"Results saved to {fname}")


def main():
    rclpy.init()
    node = SlamMapper()
    try:
        rclpy.spin(node)
    finally:
        node.save_results()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
