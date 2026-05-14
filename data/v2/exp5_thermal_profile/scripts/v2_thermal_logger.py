#!/usr/bin/env python3
"""
V2-5: Thermal Profile (Wildcard Experiment)
Alloingo V2 — Measure CPU/GPU temperature and thermal signature.

Usage:
    python v2_thermal_logger.py --duration 1800 --interval 2000 --output ./results/

Target:
    - CPU temp < 50°C at equilibrium
    - GPU temp < 45°C at equilibrium
    - Ambient temp rise < 5°C
    - No thermal throttling

This proves V2's low power consumption (0.669W) produces a negligible
thermal signature, making it suitable for sensitive environments.
"""

import argparse
import csv
import os
import re
import subprocess
import time
from datetime import datetime
from pathlib import Path
from threading import Thread


class ThermalLogger:
    """Logs tegrastats output for thermal profiling."""

    def __init__(
        self,
        output_dir: str,
        duration_s: int = 1800,
        interval_ms: int = 2000,
    ):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.duration_s = duration_s
        self.interval_ms = interval_ms

        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_path = self.output_dir / f"v2_thermal_{self.timestamp}.log"
        self.csv_path = self.output_dir / f"v2_thermal_summary_{self.timestamp}.csv"

        self.samples = []
        self.start_time = None
        self.running = False
        self._thread = None

    def parse_tegrastats(self, line: str) -> dict:
        """Parse a single line of tegrastats output."""
        sample = {
            'elapsed_s': 0.0,
            'timestamp': '',
            'ram_used_mb': None,
            'ram_total_mb': None,
            'cpu_percent': None,
            'gpu_percent': None,
            'cpu_temp_c': None,
            'gpu_temp_c': None,
            'aux_temp_c': None,
            'thermal_throttle': False,
        }

        try:
            # Extract RAM: "RAM 4123/3200MB"
            ram_match = re.search(r'RAM\s+(\d+)/(\d+)MB', line)
            if ram_match:
                sample['ram_used_mb'] = int(ram_match.group(1))
                sample['ram_total_mb'] = int(ram_match.group(2))

            # Extract CPU percentage: "CPU [100%][100%][99%][98%]"
            cpu_match = re.search(r'CPU\s+\[([^\]]+)\]', line)
            if cpu_match:
                cpu_vals = cpu_match.group(1).replace('%', '').split('][')
                cpu_vals = [int(v) for v in cpu_vals if v.isdigit()]
                if cpu_vals:
                    sample['cpu_percent'] = sum(cpu_vals) / len(cpu_vals)

            # Extract GPU percentage: "GR3d 0%"
            gpu_match = re.search(r'GR3d\s+(\d+)%', line)
            if gpu_match:
                sample['gpu_percent'] = int(gpu_match.group(1))

            # Extract temperatures: "AO 41C | CPU 42C | GPU 41C | PMIC 100C"
            temps = re.findall(r'(\d+)C', line)
            if temps:
                temp_ints = [int(t) for t in temps if 20 < int(t) < 120]
                if temp_ints:
                    # CPU is usually the highest
                    sample['cpu_temp_c'] = max(temp_ints)
                    # GPU is often second highest
                    if len(temp_ints) > 1:
                        sample['gpu_temp_c'] = sorted(temp_ints, reverse=True)[
                            min(1, len(temp_ints) - 1)
                        ]
                    # AUX/PMIC is sometimes the highest
                    sample['aux_temp_c'] = max(temp_ints)

            # Check for thermal throttle
            sample['thermal_throttle'] = 'throttling' in line.lower()

        except Exception as e:
            pass

        return sample

    def _read_tegrastats(self):
        """Background thread that reads tegrastats."""
        cmd = ['tegrastats', '--interval', str(self.interval_ms)]
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        self.running = True
        self.start_time = time.time()

        with open(self.log_path, 'w') as f:
            f.write(f"# V2 Thermal Profile Log\n")
            f.write(f"# Start: {datetime.now().isoformat()}\n")
            f.write(f"# Duration: {self.duration_s}s\n")
            f.write(f"# Interval: {self.interval_ms}ms\n\n")

            while self.running and (time.time() - self.start_time) < self.duration_s:
                line = proc.stdout.readline()
                if not line:
                    break

                line = line.strip()
                elapsed = time.time() - self.start_time
                f.write(f"[{elapsed:.2f}s] {line}\n")
                f.flush()

                # Parse and store
                sample = self.parse_tegrastats(line)
                sample['elapsed_s'] = round(elapsed, 2)
                sample['timestamp'] = datetime.now().isoformat()
                self.samples.append(sample)

        proc.terminate()
        proc.wait()

    def start(self):
        """Start logging in background thread."""
        print(f"\nV2-5 Thermal Logger started.")
        print(f"  Duration: {self.duration_s}s ({self.duration_s/60:.0f} min)")
        print(f"  Interval: {self.interval_ms}ms")
        print(f"  Log file: {self.log_path}")
        print(f"  Target temps: CPU < 50°C, GPU < 45°C, rise < 5°C")
        print(f"  Press Ctrl+C to stop early.\n")

        self._thread = Thread(target=self._read_tegrastats, daemon=True)
        self._thread.start()

    def stop(self):
        """Stop logging."""
        self.running = False
        if self._thread:
            self._thread.join(timeout=5)
        print(f"\n  Stopped. Collected {len(self.samples)} samples.")

    def save_csv(self):
        """Save parsed data to CSV."""
        if not self.samples:
            print("  No samples to save!")
            return

        fieldnames = [
            'elapsed_s', 'timestamp',
            'ram_used_mb', 'ram_total_mb',
            'cpu_percent', 'gpu_percent',
            'cpu_temp_c', 'gpu_temp_c', 'aux_temp_c',
            'thermal_throttle',
        ]

        with open(self.csv_path, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction='ignore')
            writer.writeheader()
            writer.writerows(self.samples)

        print(f"  CSV saved to: {self.csv_path}")
        return self.csv_path

    def compute_summary(self, ambient_temp: float = 22.5) -> dict:
        """Compute thermal summary statistics."""
        if not self.samples:
            return {}

        cpu_temps = [s['cpu_temp_c'] for s in self.samples if s['cpu_temp_c']]
        gpu_temps = [s['gpu_temp_c'] for s in self.samples if s['gpu_temp_c']]
        ram_usage = [s['ram_used_mb'] for s in self.samples if s['ram_used_mb']]
        throttles = [s for s in self.samples if s['thermal_throttle']]

        if not cpu_temps:
            return {}

        import statistics

        # Find equilibrium (last 10% of samples)
        n_eq = max(1, len(cpu_temps) // 10)
        eq_cpu = cpu_temps[-n_eq:]
        eq_gpu = gpu_temps[-n_eq:] if gpu_temps else [0]

        summary = {
            'total_samples': len(self.samples),
            'duration_s': round(time.time() - self.start_time, 1) if self.start_time else 0,
            # Overall CPU
            'cpu_mean_c': round(statistics.mean(cpu_temps), 2),
            'cpu_max_c': max(cpu_temps),
            'cpu_min_c': min(cpu_temps),
            'cpu_stdev_c': round(statistics.stdev(cpu_temps), 2) if len(cpu_temps) > 1 else 0.0,
            # Equilibrium CPU
            'cpu_eq_mean_c': round(statistics.mean(eq_cpu), 2),
            'cpu_eq_max_c': max(eq_cpu),
            # Overall GPU
            'gpu_mean_c': round(statistics.mean(gpu_temps), 2) if gpu_temps else None,
            'gpu_max_c': max(gpu_temps) if gpu_temps else None,
            'gpu_eq_mean_c': round(statistics.mean(eq_gpu), 2) if eq_gpu else None,
            # RAM
            'ram_peak_mb': max(ram_usage) if ram_usage else None,
            'ram_mean_mb': round(statistics.mean(ram_usage), 0) if ram_usage else None,
            # Thermal throttle
            'throttle_events': len(throttles),
            'thermal_throttle': len(throttles) > 0,
            # Temperature rise above ambient
            'ambient_temp_c': ambient_temp,
            'cpu_rise_c': round(statistics.mean(eq_cpu) - ambient_temp, 2),
            'gpu_rise_c': round(statistics.mean(eq_gpu) - ambient_temp, 2) if eq_gpu else None,
        }

        return summary


def print_thermal_summary(summary: dict):
    """Print the thermal profile summary."""
    print("\n" + "=" * 60)
    print("V2-5 THERMAL PROFILE SUMMARY")
    print("=" * 60)

    print(f"\n  Samples collected : {summary.get('total_samples', 0)}")
    print(f"  Duration           : {summary.get('duration_s', 0):.1f} s")

    print(f"\n  CPU TEMPERATURE:")
    print(f"    Mean  : {summary.get('cpu_mean_c', 0):.1f}°C")
    print(f"    Max   : {summary.get('cpu_max_c', 0):.1f}°C")
    print(f"    Min   : {summary.get('cpu_min_c', 0):.1f}°C")
    print(f"    SD    : {summary.get('cpu_stdev_c', 0):.2f}°C")
    print(f"    Eq.   : {summary.get('cpu_eq_mean_c', 0):.1f}°C  (last 10% of run)")

    cpu_status = "PASS ✓" if summary.get('cpu_eq_mean_c', 99) < 50 else "FAIL ✗"
    print(f"    Target: < 50°C  {cpu_status}")

    if summary.get('gpu_mean_c') is not None:
        print(f"\n  GPU TEMPERATURE:")
        print(f"    Mean  : {summary.get('gpu_mean_c', 0):.1f}°C")
        print(f"    Max   : {summary.get('gpu_max_c', 0):.1f}°C")
        print(f"    Eq.   : {summary.get('gpu_eq_mean_c', 0):.1f}°C")
        gpu_status = "PASS ✓" if summary.get('gpu_eq_mean_c', 99) < 45 else "FAIL ✗"
        print(f"    Target: < 45°C  {gpu_status}")

    ambient = summary.get('ambient_temp_c', 22.5)
    rise = summary.get('cpu_rise_c', 0)
    rise_status = "PASS ✓" if rise < 5 else "FAIL ✗"
    print(f"\n  TEMPERATURE RISE (above {ambient}°C ambient):")
    print(f"    CPU rise: {rise:+.1f}°C  (target: < +5°C)  {rise_status}")

    throttle = summary.get('thermal_throttle', False)
    print(f"\n  THERMAL THROTTLE:")
    print(f"    Events : {summary.get('throttle_events', 0)}")
    print(f"    Status : {'YES (FAIL ✗)' if throttle else 'NO (PASS ✓)'}")

    print(f"\n  V1 vs V2 COMPARISON:")
    print(f"    V1 CPU temp : ~80°C  (near throttle)")
    print(f"    V2 CPU temp : {summary.get('cpu_eq_mean_c', 0):.1f}°C  ({80 - summary.get('cpu_eq_mean_c', 80):.0f}°C cooler)")
    print(f"    V1 Power    : 6.0 W")
    print(f"    V2 Power    : 0.669 W  ({89}% reduction)")
    print(f"    V1 Rise     : ~15°C above ambient")
    print(f"    V2 Rise     : {rise:+.1f}°C above ambient")

    print("\n  APPLICATION VERDICT:")
    print(f"    {'Suitable for sensitive environments (agriculture, deep-sea, indoor)' if not throttle and rise < 5 else 'NOT suitable — thermal issues'}")
    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description='V2-5: Log thermal data from Alloingo V2 TX2'
    )
    parser.add_argument(
        '--duration', '-d', type=int, default=1800,
        help='Duration to log in seconds (default: 1800 = 30 minutes)'
    )
    parser.add_argument(
        '--interval', '-i', type=int, default=2000,
        help='Sampling interval in ms (default: 2000 = 2 seconds)'
    )
    parser.add_argument(
        '--output', '-o', type=str, default='./results/',
        help='Output directory'
    )
    parser.add_argument(
        '--ambient', '-a', type=float, default=22.5,
        help='Ambient temperature in °C (default: 22.5)'
    )
    parser.add_argument(
        '--parse-only', '-p', type=str, default='',
        help='Parse existing tegrastats log file (no logging)'
    )
    args = parser.parse_args()

    Path(args.output).mkdir(parents=True, exist_ok=True)

    if args.parse_only:
        # Parse existing log
        print(f"Parsing existing log: {args.parse_only}")
        samples = []
        with open(args.parse_only, 'r') as f:
            start = None
            for line in f:
                if line.startswith('['):
                    elapsed = float(re.search(r'\[([\d.]+)s\]', line).group(1))
                    if start is None:
                        start = elapsed
                    sample = {
                        'elapsed_s': round(elapsed - start, 2),
                        'timestamp': '',
                    }
                    parsed = ThermalLogger('').parse_tegrastats(line)
                    sample.update(parsed)
                    samples.append(sample)

        logger = ThermalLogger(args.output)
        logger.samples = samples
        logger.start_time = 0
    else:
        # Start new logging session
        logger = ThermalLogger(
            output_dir=args.output,
            duration_s=args.duration,
            interval_ms=args.interval,
        )
        logger.start()

        try:
            import time
            start = time.time()
            while time.time() - start < args.duration:
                time.sleep(1)
                remaining = args.duration - (time.time() - start)
                if int(remaining) % 60 == 0 and remaining > 0:
                    print(f"  {int(remaining // 60)} min remaining...")
        except KeyboardInterrupt:
            print("\nInterrupted by user.")
        finally:
            logger.stop()

    logger.save_csv()
    summary = logger.compute_summary(ambient_temp=args.ambient)
    print_thermal_summary(summary)

    # Save summary as JSON
    import json
    summary_path = Path(args.output) / f"v2_thermal_summary_{logger.timestamp}.json"
    with open(summary_path, 'w') as f:
        f.write(json.dumps(summary, indent=2))
    print(f"  Summary saved to: {summary_path}")


if __name__ == '__main__':
    main()
