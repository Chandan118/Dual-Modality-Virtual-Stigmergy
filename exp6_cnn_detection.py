#!/usr/bin/env python3
"""
exp6_cnn_detection.py — Experiment 6
=====================================
TensorRT-based target recognition.

Run:
    ros2 run formica_experiments exp6_cnn_detection
"""

import csv
import os
import time
from datetime import datetime

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image
from std_msgs.msg import Float32, String


def timestamped_filename(prefix, ext):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"exp6_{prefix}_{ts}.{ext}"


class CNNDetector(Node):
    def __init__(self):
        super().__init__('exp6_cnn_detection')

        self.detections = []
        self.confidences = []
        self.latencies = []
        self.start_time = time.time()

        self.image_sub = self.create_subscription(
            Image, '/rgb/image_raw', self.image_callback, 10)
        self.detection_sub = self.create_subscription(
            String, '/detections/class', self.detection_callback, 10)
        self.confidence_sub = self.create_subscription(
            Float32, '/detections/confidence', self.confidence_callback, 10)

        self.get_logger().info('CNN detector started.')

    def image_callback(self, msg: Image):
        pass  # TODO: implement inference trigger

    def detection_callback(self, msg: String):
        self.detections.append({
            'timestamp_s': time.time() - self.start_time,
            'class': msg.data,
        })

    def confidence_callback(self, msg: Float32):
        if self.detections:
            self.detections[-1]['confidence'] = msg.data

    def save_results(self):
        out_dir = os.path.join(os.path.expanduser('~'), 'formica_experiments', 'data')
        os.makedirs(out_dir, exist_ok=True)

        fname = os.path.join(out_dir, timestamped_filename('cnn', 'csv'))
        with open(fname, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['timestamp_s', 'class', 'confidence'])
            writer.writeheader()
            writer.writerows(self.detections)
        self.get_logger().info(f"Results saved to {fname}")


def main():
    rclpy.init()
    node = CNNDetector()
    try:
        rclpy.spin(node)
    finally:
        node.save_results()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
