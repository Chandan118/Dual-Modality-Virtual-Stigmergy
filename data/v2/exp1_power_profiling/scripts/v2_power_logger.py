#!/usr/bin/env python3
"""
V2-1: Optimized Power Profiling
Alloingo V2 — Power data collection during foraging mission.

Usage:
    python v2_power_logger.py --duration 600 --output ./results/

This script logs power data from the Alloingo V2 PDB (INA3221) via ROS 2
topics during a foraging mission cycle. It also parses tegrastats output.

Target: Mean power <= 1.2 W (vs V1 baseline of 6.0 W)
"""

import argparse
import csv
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import rclpy
from rclpy.node import Node
from std_msgs.msg import Float32, String


class PowerLogger(Node):
    """ROS 2 node that subscribes to V2 power and mode topics."""

    def __init__(self, output_dir: str):
        super().__init__('v2_power_logger')
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.csv_path = self.output_dir / f"v2_power_{self.timestamp}.csv"

        self.samples = []
        self.start_time = time.time()

        # Subscribe to power topic (from INA3221 on PDB)
        self.power_sub = self.create_subscription(
            Float32,
            '/system/power',
            self.power_callback,
            10
        )

        # Subscribe to mode topic (TRANSIT / DECISION / STANDBY)
        self.mode_sub = self.create_subscription(
            String,
            '/system/mode',
            self.mode_callback,
            10
        )

        self.current_mode = "UNKNOWN"
        self.current_power = None

        self.get_logger().info(f"Logging to {self.csv_path}")

    def power_callback(self, msg: Float32):
        """Handle incoming power reading."""
        elapsed = time.time() - self.start_time
        self.current_power = msg.data
        self.samples.append({
            'elapsed_s': round(elapsed, 3),
            'timestamp': datetime.now().isoformat(),
            'mode': self.current_mode,
            'power_W': round(msg.data, 4)
        })

    def mode_callback(self, msg: String):
        """Handle mode transition."""
        self.current_mode = msg.data
        self.get_logger().info(f"Mode changed to: {self.current_mode}")

    def save_csv(self):
        """Write all samples to CSV file."""
        if not self.samples:
            self.get_logger().warn("No samples collected!")
            return

        with open(self.csv_path, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=[
                'elapsed_s', 'timestamp', 'mode', 'power_W'
            ])
            writer.writeheader()
            writer.writerows(self.samples)

        self.get_logger().info(f"Saved {len(self.samples)} samples to {self.csv_path}")

    def compute_summary(self) -> dict:
        """Compute summary statistics for the collected data."""
        if not self.samples:
            return {}

        powers = [s['power_W'] for s in self.samples]
        total = len(powers)

        import statistics
        mean_power = statistics.mean(powers)
        stdev_power = statistics.stdev(powers) if len(powers) > 1 else 0.0

        # Count samples per mode
        mode_counts = {}
        mode_powers = {}
        for s in self.samples:
            m = s['mode']
            mode_counts[m] = mode_counts.get(m, 0) + 1
            if m not in mode_powers:
                mode_powers[m] = []
            mode_powers[m].append(s['power_W'])

        mode_summary = {}
        for m, ps in mode_powers.items():
            mode_summary[m] = {
                'count': mode_counts[m],
                'mean_W': round(statistics.mean(ps), 4),
                'stdev_W': round(statistics.stdev(ps), 4) if len(ps) > 1 else 0.0,
                'min_W': round(min(ps), 4),
                'max_W': round(max(ps), 4),
            }

        # 95% confidence interval for mean
        n = len(powers)
        if n > 1:
            stderr = stdev_power / (n ** 0.5)
            ci_95 = 1.96 * stderr
        else:
            ci_95 = 0.0

        return {
            'total_samples': total,
            'duration_s': round(time.time() - self.start_time, 1),
            'overall_mean_W': round(mean_power, 4),
            'overall_stdev_W': round(stdev_power, 4),
            'overall_min_W': round(min(powers), 4),
            'overall_max_W': round(max(powers), 4),
            'ci_95_lower': round(mean_power - ci_95, 4),
            'ci_95_upper': round(mean_power + ci_95, 4),
            'passes_target': (mean_power - ci_95) <= 1.2,
            'mode_summary': mode_summary,
        }


def parse_tegrastats(log_path: str) -> dict:
    """Parse tegrastats log and extract power/temperature readings."""
    results = {
        'ram_mb': [],
        'cpu_percent': [],
        'gpu_percent': [],
        'cpu_temp_c': [],
        'gpu_temp_c': [],
    }

    if not os.path.exists(log_path):
        return results

    with open(log_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            # Parse tegrastats format:
            # RAM 4123/3200MB | CPU [100%][100%][99%][98%] | ... | AO 41C | CPU 42C | GPU 41C
            try:
                # Extract RAM
                if 'RAM' in line:
                    ram_part = line.split('RAM')[1].split('MB')[0].strip()
                    ram_used = int(ram_part.split('/')[0].strip())
                    results['ram_mb'].append(ram_used)

                # Extract temperatures
                if 'CPU' in line and 'C' in line:
                    # Find all temperature readings
                    import re
                    temps = re.findall(r'(\d+)C', line)
                    if temps:
                        cpu_temps = [int(t) for t in temps if int(t) < 120]
                        if cpu_temps:
                            results['cpu_temp_c'].append(max(cpu_temps))
                        if len(cpu_temps) > 1:
                            results['gpu_temp_c'].append(cpu_temps[-1])

                # Extract CPU percentage
                cpu_match = re.search(r'CPU \[([^\]]+)\]', line)
                if cpu_match:
                    cpu_vals = cpu_match.group(1).replace('%', '').split('][')
                    cpu_vals = [int(v) for v in cpu_vals if v.isdigit()]
                    if cpu_vals:
                        results['cpu_percent'].append(sum(cpu_vals) / len(cpu_vals))

                # Extract GPU percentage
                gpu_match = re.search(r'GR3d (\d+)%', line)
                if gpu_match:
                    results['gpu_percent'].append(int(gpu_match.group(1)))

            except Exception:
                continue

    return results


def print_summary(summary: dict):
    """Print a formatted summary of the power profiling results."""
    print("\n" + "=" * 60)
    print("V2-1 POWER PROFILING SUMMARY")
    print("=" * 60)

    print(f"\n  Total samples : {summary.get('total_samples', 0)}")
    print(f"  Duration      : {summary.get('duration_s', 0):.1f} s")
    print(f"\n  OVERALL POWER:")
    print(f"    Mean        : {summary.get('overall_mean_W', 0):.4f} W")
    print(f"    Std Dev     : {summary.get('overall_stdev_W', 0):.4f} W")
    print(f"    Min         : {summary.get('overall_min_W', 0):.4f} W")
    print(f"    Max         : {summary.get('overall_max_W', 0):.4f} W")
    print(f"    95% CI      : [{summary.get('ci_95_lower', 0):.4f}, {summary.get('ci_95_upper', 0):.4f}] W")

    status = "PASS ✓" if summary.get('passes_target') else "FAIL ✗"
    print(f"\n  Target (<=1.2W): {status}")
    print(f"    (Pass = lower bound of 95% CI <= 1.2W)")

    print(f"\n  POWER BY MODE:")
    for mode, stats in summary.get('mode_summary', {}).items():
        print(f"    {mode:12s}: n={stats['count']:3d}  "
              f"mean={stats['mean_W']:.4f}W  "
              f"sd={stats['stdev_W']:.4f}W  "
              f"[{stats['min_W']:.4f} – {stats['max_W']:.4f}]W")

    print("\n  V1 vs V2 COMPARISON:")
    v1_power = 6.0
    v2_power = summary.get('overall_mean_W', 0)
    reduction = (1 - v2_power / v1_power) * 100
    print(f"    V1 (baseline): {v1_power:.2f} W")
    print(f"    V2 (Alloingo): {v2_power:.4f} W")
    print(f"    Reduction     : {reduction:.1f}%")
    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description='V2-1: Log power data from Alloingo V2 PDB during foraging mission'
    )
    parser.add_argument(
        '--duration', '-d', type=int, default=600,
        help='Duration to log in seconds (default: 600 = 10 minutes)'
    )
    parser.add_argument(
        '--output', '-o', type=str, default='./results/',
        help='Output directory for CSV files'
    )
    parser.add_argument(
        '--tegrastats', '-t', type=str, default='',
        help='Path to tegrastats log file to parse (optional)'
    )
    args = parser.parse_args()

    Path(args.output).mkdir(parents=True, exist_ok=True)

    # Parse tegrastats if provided
    if args.tegrastats and os.path.exists(args.tegrastats):
        print(f"Parsing tegrastats log: {args.tegrastats}")
        ts_results = parse_tegrastats(args.tegrastats)

        if ts_results['ram_mb']:
            print(f"  RAM peak: {max(ts_results['ram_mb'])} MB")
        if ts_results['cpu_temp_c']:
            print(f"  CPU temp: max={max(ts_results['cpu_temp_c'])}°C, "
                  f"mean={sum(ts_results['cpu_temp_c'])/len(ts_results['cpu_temp_c']):.1f}°C")
        if ts_results['gpu_temp_c']:
            print(f"  GPU temp: max={max(ts_results['gpu_temp_c'])}°C, "
                  f"mean={sum(ts_results['gpu_temp_c'])/len(ts_results['gpu_temp_c']):.1f}°C")

    # Initialize ROS 2
    rclpy.init(args=sys.argv)
    node = PowerLogger(args.output)

    print(f"\nV2-1 Power Logger started. Logging for {args.duration}s...")
    print(f"Target: Mean power <= 1.2 W (V1 baseline: 6.0 W)")
    print("Press Ctrl+C to stop early.\n")

    try:
        # Log for specified duration
        start = time.time()
        while rclpy.ok() and (time.time() - start) < args.duration:
            rclpy.spin_once(node, timeout_sec=0.1)
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
    finally:
        node.destroy_node()
        rclpy.shutdown()

        # Save and summarize
        node.save_csv()
        summary = node.compute_summary()
        print_summary(summary)

        # Save summary as text
        summary_path = Path(args.output) / f"v2_power_summary_{node.timestamp}.txt"
        with open(summary_path, 'w') as f:
            import json
            f.write(json.dumps(summary, indent=2, default=str))
        print(f"Summary saved to: {summary_path}")


if __name__ == '__main__':
    main()
