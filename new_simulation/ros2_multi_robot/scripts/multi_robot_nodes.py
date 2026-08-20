#!/usr/bin/env python3


import rclpy
from rclpy.node import Node
from geometry_msgs.msg import PoseStamped, Twist
from nav_msgs.msg import Odometry
from sensor_msgs.msg import LaserScan
from visualization_msgs.msg import Marker, MarkerArray
from std_msgs.msg import Float32MultiArray
import numpy as np
import time


class SwarmCoordinator(Node):
    """Central coordinator for multi-robot swarm"""
    
    def __init__(self):
        super().__init__('swarm_coordinator')
        
        # Parameters
        self.declare_parameter('num_robots', 20)
        self.declare_parameter('arena_width', 8.0)
        self.declare_parameter('arena_height', 8.0)
        self.declare_parameter('sim_time', 60.0)
        
        self.num_robots = self.get_parameter('num_robots').value
        self.arena_width = self.get_parameter('arena_width').value
        self.arena_height = self.get_parameter('arena_height').value
        self.sim_time = self.get_parameter('sim_time').value
        
        # Publishers
        self.status_pub = self.create_publisher(
            Float32MultiArray, '/swarm_status', 10)
        
        # Timer
        self.timer = self.create_timer(1.0, self.timer_callback)
        
        self.start_time = time.time()
        self.get_logger().info(f'Swarm Coordinator started with {self.num_robots} robots')
    
    def timer_callback(self):
        elapsed = time.time() - self.start_time
        
        # Publish status
        msg = Float32MultiArray()
        msg.data = [
            float(self.num_robots),
            float(elapsed),
            float(self.arena_width),
            float(self.arena_height)
        ]
        self.status_pub.publish(msg)
        
        if elapsed >= self.sim_time:
            self.get_logger().info('Simulation complete!')
            rclpy.shutdown()


class PheromoneGrid(Node):
    """Virtual pheromone grid management"""
    
    def __init__(self):
        super().__init__('pheromone_grid')
        
        # Parameters
        self.declare_parameter('grid_resolution', 0.05)
        self.declare_parameter('arena_width', 8.0)
        self.declare_parameter('arena_height', 8.0)
        self.declare_parameter('decay_rate', 0.02)
        self.declare_parameter('max_intensity', 255.0)
        
        self.grid_resolution = self.get_parameter('grid_resolution').value
        self.arena_width = self.get_parameter('arena_width').value
        self.arena_height = self.get_parameter('arena_height').value
        self.decay_rate = self.get_parameter('decay_rate').value
        self.max_intensity = self.get_parameter('max_intensity').value
        
        # Initialize grid
        self.grid_size_x = int(self.arena_width / self.grid_resolution)
        self.grid_size_y = int(self.arena_height / self.grid_resolution)
        self.grid = np.zeros((self.grid_size_y, self.grid_size_x))
        
        # Subscribers
        self.deposit_sub = self.create_subscription(
            Float32MultiArray, '/pheromone_deposit', self.deposit_callback, 10)
        
        # Publishers
        self.grid_pub = self.create_publisher(
            Float32MultiArray, '/pheromone_grid_data', 10)
        
        # Timer
        self.timer = self.create_timer(0.1, self.timer_callback)
        
        self.get_logger().info('Pheromone Grid initialized')
    
    def deposit_callback(self, msg):
        """Handle pheromone deposit from robots"""
        x = int(msg.data[0] / self.grid_resolution)
        y = int(msg.data[1] / self.grid_resolution)
        amount = msg.data[2]
        
        if 0 <= x < self.grid_size_x and 0 <= y < self.grid_size_y:
            self.grid[y, x] = min(self.max_intensity, self.grid[y, x] + amount)
    
    def timer_callback(self):
        # Decay pheromone
        self.grid *= (1 - self.decay_rate * 0.1)
        self.grid = np.maximum(0, self.grid)
        
        # Publish grid data
        msg = Float32MultiArray()
        msg.data = self.grid.flatten().tolist()
        self.grid_pub.publish(msg)


class RobotNode(Node):
    """Individual robot node"""
    
    def __init__(self, robot_id=0):
        super().__init__(f'robot_{robot_id}')
        
        self.robot_id = robot_id
        
        # Parameters
        self.declare_parameter('robot_id', robot_id)
        self.declare_parameter('initial_x', 1.0)
        self.declare_parameter('initial_y', 1.0)
        self.declare_parameter('initial_theta', 0.0)
        self.declare_parameter('max_speed', 0.15)
        self.declare_parameter('turn_rate', 1.5)
        self.declare_parameter('robot_radius', 0.08)
        self.declare_parameter('pheromone_threshold', 10.0)
        
        self.x = self.get_parameter('initial_x').value
        self.y = self.get_parameter('initial_y').value
        self.theta = self.get_parameter('initial_theta').value
        self.max_speed = self.get_parameter('max_speed').value
        self.turn_rate = self.get_parameter('turn_rate').value
        self.robot_radius = self.get_parameter('robot_radius').value
        self.pheromone_threshold = self.get_parameter('pheromone_threshold').value
        
        # State
        self.dt = 0.05
        
        # Publishers
        self.cmd_pub = self.create_publisher(Twist, '/cmd_vel', 10)
        self.deposit_pub = self.create_publisher(
            Float32MultiArray, '/pheromone_deposit', 10)
        self.marker_pub = self.create_publisher(Marker, '/robot_marker', 10)
        
        # Subscribers
        self.pheromone_sub = self.create_subscription(
            Float32MultiArray, '/pheromone_grid_data', self.pheromone_callback, 10)
        
        # Timer
        self.timer = self.create_timer(self.dt, self.timer_callback)
        
        self.get_logger().info(f'Robot {robot_id} initialized at ({self.x:.2f}, {self.y:.2f})')
    
    def pheromone_callback(self, msg):
        """Store pheromone grid data"""
        # Store for later use in navigation
        pass
    
    def timer_callback(self):
        # Simple random walk with pheromone following
        cmd = Twist()
        
        # Random behavior (simplified)
        cmd.linear.x = self.max_speed * 0.5
        cmd.angular.z = (np.random.random() - 0.5) * self.turn_rate
        
        # Deposit pheromone
        deposit = Float32MultiArray()
        deposit.data = [float(self.x), float(self.y), float(10.0)]
        self.deposit_pub.publish(deposit)
        
        # Update position (simplified)
        self.x += cmd.linear.x * self.dt * np.cos(self.theta)
        self.y += cmd.linear.x * self.dt * np.sin(self.theta)
        self.theta += cmd.angular.z * self.dt
        
        # Boundary check
        self.x = max(0.1, min(7.9, self.x))
        self.y = max(0.1, min(7.9, self.y))
        
        self.cmd_pub.publish(cmd)
        self.publish_marker()
    
    def publish_marker(self):
        """Publish robot marker for visualization"""
        marker = Marker()
        marker.header.frame_id = 'map'
        marker.ns = 'robots'
        marker.id = self.robot_id
        marker.type = Marker.CYLINDER
        marker.action = Marker.ADD
        marker.pose.position.x = self.x
        marker.pose.position.y = self.y
        marker.pose.position.z = 0.04
        marker.scale.x = self.robot_radius * 2
        marker.scale.y = self.robot_radius * 2
        marker.scale.z = 0.08
        marker.color.r = 0.0
        marker.color.g = 0.0
        marker.color.b = 1.0
        marker.color.a = 1.0
        self.marker_pub.publish(marker)


def main(args=None):
    rclpy.init(args=args)
    
    # Create and spin nodes
    coordinator = SwarmCoordinator()
    pheromone = PheromoneGrid()
    
    # Create robot nodes
    robots = [RobotNode(i) for i in range(20)]
    
    executor = rclpy.executors.MultiThreadedExecutor()
    executor.add_node(coordinator)
    executor.add_node(pheromone)
    for robot in robots:
        executor.add_node(robot)
    
    try:
        executor.spin()
    except KeyboardInterrupt:
        pass
    finally:
        coordinator.destroy_node()
        pheromone.destroy_node()
        for robot in robots:
            robot.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
