#!/usr/bin/env python3
"""
V2-3: Pheromone Detection & Sim-to-Real Gap Analysis
Alloingo V2 — Quantify S2R gap between Gazebo simulation and physical hardware.

Usage:
    python v2_s2r_analysis.py \
        --sim ./results/sim_baseline.csv \
        --hw ./results/v2_hw_raw_adc.csv \
        --output ./results/

Target:
    - S2R Gap (deviation) < 10%  (V1 was 15.4%)
    - S2R Gap (SNR) < 10%
    - Lateral deviation <= 1.0 cm (V1 was 1.5 cm)

This script compares simulation and hardware sensor data,
computes the S2R gap, and generates the comparison spreadsheet.
"""

import argparse
import csv
import math
import statistics
from datetime import datetime
from pathlib import Path


def load_csv(path: str) -> list[dict]:
    """Load a CSV file into a list of dicts."""
    with open(path, 'r') as f:
        reader = csv.DictReader(f)
        return list(reader)


def parse_tegrastats_snr(adc_vals: list[float]) -> float:
    """
    Estimate SNR from ADC readings.
    Signal = mean(adc) above noise floor
    Noise floor = std(adc) in off-trail regions
    """
    if len(adc_vals) < 2:
        return 0.0

    mean_adc = statistics.mean(adc_vals)
    # Noise floor approximation: min value is "no signal"
    noise_floor = min(adc_vals) if adc_vals else 1.0
    signal = mean_adc - noise_floor

    if signal <= 0 or noise_floor <= 0:
        return 0.0

    snr_db = 20 * math.log10(signal / noise_floor)
    return snr_db


def compute_deviation_stats(records: list[dict]) -> dict:
    """Compute deviation and SNR statistics from sensor records."""
    if not records:
        return {}

    deviations = []
    adc_values = []

    for r in records:
        # Try 'deviation_m' or 'lateral_deviation' or 'dev_cm'
        dev = r.get('deviation_m') or r.get('lateral_deviation_m') or r.get('dev_cm')
        if dev:
            try:
                dev_m = float(dev)
                if 'dev_cm' in r:
                    dev_m /= 100.0  # Convert cm to m
                deviations.append(dev_m)
            except (ValueError, TypeError):
                pass

        # Collect ADC values
        for key in ['adc_0', 'adc_1', 'adc_2', 'adc_3', 'sensor_0', 'sensor_1']:
            val = r.get(key)
            if val:
                try:
                    adc_values.append(float(val))
                except (ValueError, TypeError):
                    pass

    if not deviations:
        return {}

    import statistics
    mean_dev = statistics.mean(deviations) * 100  # Convert to cm
    std_dev = statistics.stdev(deviations) * 100 if len(deviations) > 1 else 0.0

    snr_db = parse_tegrastats_snr(adc_values) if adc_values else 0.0

    return {
        'n': len(deviations),
        'mean_dev_cm': round(mean_dev, 4),
        'std_dev_cm': round(std_dev, 4),
        'min_dev_cm': round(min(deviations) * 100, 4),
        'max_dev_cm': round(max(deviations) * 100, 4),
        'snr_db': round(snr_db, 2),
    }


def compute_s2r_gap(sim_val: float, hw_val: float) -> float:
    """Compute sim-to-real gap as percentage."""
    if sim_val == 0:
        return float('inf')
    return abs(sim_val - hw_val) / sim_val * 100


def generate_spreadsheet(sim_stats: dict, hw_stats: dict, output_path: str):
    """Generate a simple XLSX-style CSV comparison (use openpyxl for real XLSX)."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # Summary CSV
    summary_path = Path(output_path) / f"v2_s2r_summary_{timestamp}.csv"
    with open(summary_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Metric', 'Gazebo Simulation', 'Physical Hardware', 'S2R Gap', 'Target', 'Status'])
        writer.writerow([])

        # Deviation
        sim_dev = sim_stats.get('mean_dev_cm', 0)
        hw_dev = hw_stats.get('mean_dev_cm', 0)
        gap_dev = compute_s2r_gap(sim_dev, hw_dev)
        writer.writerow([
            'Lateral Deviation (cm)',
            f'{sim_dev:.3f}',
            f'{hw_dev:.3f}',
            f'{gap_dev:.2f}%',
            '<10%',
            'PASS ✓' if gap_dev < 10 else 'FAIL ✗'
        ])

        # SNR
        sim_snr = sim_stats.get('snr_db', 0)
        hw_snr = hw_stats.get('snr_db', 0)
        gap_snr = compute_s2r_gap(sim_snr, hw_snr)
        writer.writerow([
            'Signal-to-Noise Ratio (dB)',
            f'{sim_snr:.2f}',
            f'{hw_snr:.2f}',
            f'{gap_snr:.2f}%',
            '<10%',
            'PASS ✓' if gap_snr < 10 else 'FAIL ✗'
        ])

        # Raw ADC values
        writer.writerow([])
        writer.writerow(['Trial-level Data (Simulation)'])
        writer.writerow(['Metric', 'Value'])
        writer.writerow(['Mean Deviation', f'{sim_dev:.4f} cm'])
        writer.writerow(['Std Deviation', f'{sim_stats.get("std_dev_cm", 0):.4f} cm'])
        writer.writerow(['Min Deviation', f'{sim_stats.get("min_dev_cm", 0):.4f} cm'])
        writer.writerow(['Max Deviation', f'{sim_stats.get("max_dev_cm", 0):.4f} cm'])
        writer.writerow(['SNR', f'{sim_snr:.2f} dB'])
        writer.writerow(['N', sim_stats.get('n', 0)])

        writer.writerow([])
        writer.writerow(['Trial-level Data (Hardware)'])
        writer.writerow(['Metric', 'Value'])
        writer.writerow(['Mean Deviation', f'{hw_dev:.4f} cm'])
        writer.writerow(['Std Deviation', f'{hw_stats.get("std_dev_cm", 0):.4f} cm'])
        writer.writerow(['Min Deviation', f'{hw_stats.get("min_dev_cm", 0):.4f} cm'])
        writer.writerow(['Max Deviation', f'{hw_stats.get("max_dev_cm", 0):.4f} cm'])
        writer.writerow(['SNR', f'{hw_snr:.2f} dB'])
        writer.writerow(['N', hw_stats.get('n', 0)])

    print(f"\n  Spreadsheet saved to: {summary_path}")
    return summary_path


def print_s2r_report(sim_stats: dict, hw_stats: dict):
    """Print the S2R gap analysis report."""
    print("\n" + "=" * 60)
    print("V2-3 SIM-TO-REAL GAP ANALYSIS")
    print("=" * 60)

    # Deviation
    sim_dev = sim_stats.get('mean_dev_cm', 0)
    hw_dev = hw_stats.get('mean_dev_cm', 0)
    gap_dev = compute_s2r_gap(sim_dev, hw_dev)

    print(f"\n  LATERAL DEVIATION:")
    print(f"    Simulation mean : {sim_dev:.4f} cm")
    print(f"    Hardware mean   : {hw_dev:.4f} cm")
    print(f"    S2R Gap         : {gap_dev:.2f}%")
    print(f"    Target          : < 10%  {'PASS ✓' if gap_dev < 10 else 'FAIL ✗'}")

    # SNR
    sim_snr = sim_stats.get('snr_db', 0)
    hw_snr = hw_stats.get('snr_db', 0)
    gap_snr = compute_s2r_gap(sim_snr, hw_snr)

    print(f"\n  SIGNAL-TO-NOISE RATIO:")
    print(f"    Simulation mean : {sim_snr:.2f} dB")
    print(f"    Hardware mean   : {hw_snr:.2f} dB")
    print(f"    S2R Gap         : {gap_snr:.2f}%")
    print(f"    Target          : < 10%  {'PASS ✓' if gap_snr < 10 else 'FAIL ✗'}")

    # V1 comparison
    v1_dev = 1.5  # cm
    v1_gap = 15.4  # %
    print(f"\n  V1 vs V2 COMPARISON:")
    print(f"    V1 Deviation : {v1_dev} cm")
    print(f"    V1 S2R Gap  : {v1_gap}% (at boundary, marginally exceeded 15%)")
    print(f"    V2 Deviation: {hw_dev:.4f} cm (target: <= 1.0 cm)")
    print(f"    V2 S2R Gap  : {gap_dev:.2f}% (target: < 10%)")
    improvement = v1_gap - gap_dev
    print(f"    S2R Gap reduction: {improvement:.1f}% absolute improvement")

    # Optical decay note
    print(f"\n  PHYSICAL CONSTRAINT (TCRT5000 28% Decay Limit):")
    print(f"    Min detectable signal = 28% of fresh trail")
    print(f"    This is a hardware threshold — not a V2 failure")
    print(f"    V2 PID controller is tuned to track above this limit")

    print("\n  DECISION:")
    all_pass = gap_dev < 10 and gap_snr < 10 and hw_dev <= 1.0
    print(f"    Overall: {'PASS ✓' if all_pass else 'FAIL ✗'}")
    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description='V2-3: Analyze Sim-to-Real gap for pheromone sensors'
    )
    parser.add_argument(
        '--sim', '-s', type=str, required=True,
        help='Path to simulation baseline CSV'
    )
    parser.add_argument(
        '--hw', '-h', type=str, required=True,
        help='Path to hardware ADC CSV'
    )
    parser.add_argument(
        '--output', '-o', type=str, default='./results/',
        help='Output directory'
    )
    args = parser.parse_args()

    Path(args.output).mkdir(parents=True, exist_ok=True)

    # Load CSVs
    print(f"Loading simulation data: {args.sim}")
    sim_records = load_csv(args.sim)
    sim_stats = compute_deviation_stats(sim_records)
    print(f"  Loaded {len(sim_records)} simulation records")
    if sim_stats:
        print(f"  Mean deviation: {sim_stats.get('mean_dev_cm', 0):.4f} cm")
        print(f"  SNR: {sim_stats.get('snr_db', 0):.2f} dB")

    print(f"\nLoading hardware data: {args.hw}")
    hw_records = load_csv(args.hw)
    hw_stats = compute_deviation_stats(hw_records)
    print(f"  Loaded {len(hw_records)} hardware records")
    if hw_stats:
        print(f"  Mean deviation: {hw_stats.get('mean_dev_cm', 0):.4f} cm")
        print(f"  SNR: {hw_stats.get('snr_db', 0):.2f} dB")

    if not sim_stats or not hw_stats:
        print("\nERROR: Could not parse data from one or both files.")
        print("Expected columns: deviation_m, lateral_deviation_m, adc_0..adc_3")
        return

    # Compute and print report
    print_s2r_report(sim_stats, hw_stats)

    # Generate spreadsheet
    summary_path = generate_spreadsheet(sim_stats, hw_stats, args.output)
    print(f"\n  Spreadsheet saved to: {summary_path}")


if __name__ == '__main__':
    main()
