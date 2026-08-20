#!/usr/bin/env python3


import csv
import os
import time
from datetime import datetime

import rclpy
from rclpy.node import Node
from nav_msgs.msg import Odometry
from geometry_msgs.msg import PoseStamped, Twist


def timestamped_filename(prefix, ext):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"exp4_{prefix}_{ts}.{ext}"


class MazeNavigator(Node):
    def __init__(self):
        super().__init__('exp4_maze_navigation')

        self.trial_results = []
        self.current_trial = None
        self.trial_start = None
        self.goal_reached = False
        self.start_time = time.time()

        self.odom_sub = self.create_subscription(
            Odometry, '/odom', self.odom_callback, 10)
        self.goal_pub = self.create_publisher(PoseStamped, '/goal_pose', 10)
        self.vel_pub = self.create_publisher(Twist, '/cmd_vel', 10)

        self.get_logger().info('Maze navigator started.')

    def odom_callback(self, msg: Odometry):
        if self.trial_start is None and not self.goal_reached:
            self.trial_start = time.time()
            self.current_trial = {'trial': len(self.trial_results) + 1, 'start_x': msg.pose.pose.position.x,
                                  'start_y': msg.pose.pose.position.y}

    def save_results(self):
        out_dir = os.path.join(os.path.expanduser('~'), 'formica_experiments', 'data')
        os.makedirs(out_dir, exist_ok=True)

        fname = os.path.join(out_dir, timestamped_filename('maze', 'csv'))
        with open(fname, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['trial', 'success', 'duration_s', 'collisions'])
            writer.writeheader()
            writer.writerows(self.trial_results)
        self.get_logger().info(f"Results saved to {fname}")


def main():
    rclpy.init()
    node = MazeNavigator()
    try:
        rclpy.spin(node)
    finally:
        node.save_results()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
