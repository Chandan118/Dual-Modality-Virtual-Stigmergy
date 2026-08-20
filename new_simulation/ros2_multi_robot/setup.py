from setuptools import setup
import os

package_name = "multi_robot_swarm"

setup(
    name=package_name,
    version="1.0.0",
    packages=[package_name],
    data_files=[
        ("share/ament_index/resource_index/packages", ["resource/" + package_name]),
        ("share/" + package_name, ["package.xml"]),
        (
            os.path.join("share", package_name, "launch"),
            ["launch/swarm_simulation.launch.py"],
        ),
        (os.path.join("share", package_name, "config"), ["config/swarm_config.yaml"]),
        (os.path.join("share", package_name, "urdf"), ["urdf/formicabot.urdf"]),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="Chandan Sheikder",
    maintainer_email="chandan@example.com",
    description="Multi-robot swarm simulation with 20 wheeled robots",
    license="MIT",
    tests_require=["pytest"],
    entry_points={
        "console_scripts": [
            "coordinator = multi_robot_swarm.coordinator:main",
            "pheromone_grid = multi_robot_swarm.pheromone_grid:main",
            "robot_node = multi_robot_swarm.robot_node:main",
            "robot_viz = multi_robot_swarm.robot_viz:main",
            "data_logger = multi_robot_swarm.data_logger:main",
        ],
    },
)
