import os
from glob import glob

from setuptools import find_packages, setup

package_name = 'formica_experiments'

setup(
    name=package_name,
    version='1.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'config'),
         [f for f in glob('config/*') if os.path.isfile(f)]),
        (os.path.join('share', package_name, 'launch'),
         [f for f in glob('launch/*') if os.path.isfile(f)]),
    ],
    install_requires=[
        'setuptools',
        'pyserial',
        'pandas',
        'matplotlib',
        'ultralytics',
    ],
    zip_safe=True,
    maintainer='FormicaBot Research',
    maintainer_email='robot@formica.bot',
    description='Chapter 6 experimental validation package for FormicaBot',
    license='MIT',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'arduino_base = formica_experiments.arduino_base_node:main',
            'cmd_vel_relay = formica_experiments.cmd_vel_relay:main',
            'data_logger = formica_experiments.data_logger:main',
            'exp1_calibration = formica_experiments.exp1_sensor_calibration:main',
            'exp2_power = formica_experiments.exp2_power_profiling:main',
            'ina219_power_monitor = formica_experiments.ina219_power_monitor:main',
            'exp3_slam = formica_experiments.exp3_slam_mapping:main',
            'mapping_motion_helper = formica_experiments.mapping_motion_helper:main',
            'exp4_maze = formica_experiments.exp4_maze_navigation:main',
            'exp5_fault = formica_experiments.exp5_obstacle_fault:main',
            'exp6_cnn = formica_experiments.exp6_cnn_detection:main',
            'exp7_pheromone = formica_experiments.exp7_pheromone_trail:main',
            'exp7_postprocess = formica_experiments.exp7_postprocess:main',
            'jetson_camera = formica_experiments.jetson_camera_publisher:main',
            'jetson_vision_guide = formica_experiments.jetson_vision_sensor_guide:main',
        ],
    },
)
