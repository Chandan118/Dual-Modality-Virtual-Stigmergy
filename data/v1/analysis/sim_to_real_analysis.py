#!/usr/bin/env python3
"""
sim_to_real_analysis.py
=========================
Sim-to-Real Gap Analysis for FormicaBot Chapter 6.

Compares physical hardware results against simulated/virtual baselines to
quantify the sim-to-real transfer gap for each experiment.

Usage:
    python sim_to_real_analysis.py --v1-dir ~/formica_experiments/data/v1
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path
from typing import Any


# ─────────────────────────────────────────────────────────────────────────────
# Baseline definitions (from virtual/physics simulation)
# ─────────────────────────────────────────────────────────────────────────────
SIM_BASELINES = {
    "exp1_lidar_rmse": 0.018,      # Sim LiDAR RMSE (m)
    "exp1_imu_drift": 0.45,         # Sim IMU drift (deg/min)
    "exp1_odom_error": 1.8,         # Sim odom error (%)
    "exp1_tcrt_snr": 6.5,           # Sim TCRT SNR (dB)
    "exp1_rgbd_reproj": 0.42,       # Sim reproj error (px)

    "exp2_transit_power": 0.95,      # Sim TRANSIT power (W)
    "exp2_decision_power": 1.05,     # Sim DECISION power (W)
    "exp2_standby_power": 0.35,     # Sim STANDBY power (W)
    "exp2_overall_power": 0.88,     # Sim overall power (W)

    "exp3_rmse": 0.12,              # Sim SLAM RMSE (m)
    "exp3_coverage": 96.0,          # Sim map coverage (%)

    "exp4_success_rate": 92.0,      # Sim maze success (%)
    "exp4_mean_path": 3.95,         # Sim mean path (m)

    "exp5_success_rate": 78.0,     # Sim fault tolerance (%)
    "exp5_recovery_time": 1.8,       # Sim mean recovery (s)

    "exp6_mAP": 0.94,               # Sim mAP
    "exp6_red_mAP": 0.93,
    "exp6_green_mAP": 0.95,
    "exp6_blue_mAP": 0.94,

    "exp7_straight_lateral": 1.30,  # Sim straight lateral dev (cm)
    "exp7_curved_lateral": 1.70,    # Sim curved lateral dev (cm)
    "exp7_snr_threshold": 6.0,     # Sim SNR threshold (dB)
    "exp7_switchover_latency": 0.45, # Sim switchover latency (s)
}


# ─────────────────────────────────────────────────────────────────────────────
# Gap computation
# ─────────────────────────────────────────────────────────────────────────────

def gap_pct(real: float, sim: float) -> float | None:
    """Compute sim-to-real gap as percentage."""
    if sim == 0 or sim is None:
        return None
    return abs(real - sim) / abs(sim) * 100.0


def gap_absolute(real: float, sim: float) -> float | None:
    """Compute absolute gap."""
    if real is None or sim is None:
        return None
    return abs(real - sim)


# ─────────────────────────────────────────────────────────────────────────────
# Analysis per experiment
# ─────────────────────────────────────────────────────────────────────────────

def analyse_exp1(v1_dir: Path) -> dict[str, Any]:
    """Analyse Experiment 1: Sensor Calibration sim-to-real gap."""
    results_dir = v1_dir / "exp1_sensor_calibration" / "results"
    if not results_dir.exists():
        return {}
    matches = sorted(results_dir.glob("table6_1*.csv"), key=lambda p: p.stat().st_mtime)
    if not matches:
        return {}
    data: dict[str, Any] = {"gaps": {}, "metrics": {}}
    with open(matches[-1], newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            metric = row.get("metric", "").strip()
            val_str = row.get("value", "").strip()
            try:
                value = float(val_str)
            except ValueError:
                continue

            metric_map = {
                "LiDAR RMSE": "exp1_lidar_rmse",
                "IMU drift": "exp1_imu_drift",
                "Odom mean error": "exp1_odom_error",
                "TCRT5000 SNR": "exp1_tcrt_snr",
                "RGB-D reprojection": "exp1_rgbd_reproj",
            }
            sim_key = metric_map.get(metric)
            if sim_key:
                sim_val = SIM_BASELINES.get(sim_key)
                data["metrics"][metric] = value
                if sim_val:
                    data["gaps"][metric] = {
                        "real": value,
                        "sim": sim_val,
                        "gap_pct": gap_pct(value, sim_val),
                        "gap_abs": gap_absolute(value, sim_val),
                    }
    return data


def analyse_exp7(v1_dir: Path) -> dict[str, Any]:
    """Analyse Experiment 7: Pheromone sim-to-real gap."""
    results_dir = v1_dir / "exp7_pheromone_trail" / "results"
    if not results_dir.exists():
        return {}
    matches = sorted(results_dir.glob("exp7_pheromone*.csv"), key=lambda p: p.stat().st_mtime)
    if not matches:
        return {}
    data: dict[str, Any] = {"gaps": {}, "metrics": {}}

    straight_devs, curved_devs = [], []
    with open(matches[-1], newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            sub_exp = str(row.get("sub_exp", "")).strip()
            dev_str = str(row.get("lateral_dev_m", "")).strip()
            if dev_str in ("", "N/A"):
                continue
            try:
                dev_cm = float(dev_str) * 100.0
                if sub_exp.startswith("A_straight"):
                    straight_devs.append(dev_cm)
                elif sub_exp.startswith("B_curved"):
                    curved_devs.append(dev_cm)
            except ValueError:
                pass

    import statistics
    if straight_devs:
        mean_s = statistics.mean(straight_devs)
        sim_s = SIM_BASELINES["exp7_straight_lateral"]
        data["metrics"]["Straight Trail Lateral Deviation"] = mean_s
        data["gaps"]["Straight Trail"] = {
            "real": mean_s,
            "sim": sim_s,
            "gap_pct": gap_pct(mean_s, sim_s),
            "gap_abs": gap_absolute(mean_s, sim_s),
        }

    if curved_devs:
        mean_c = statistics.mean(curved_devs)
        sim_c = SIM_BASELINES["exp7_curved_lateral"]
        data["metrics"]["Curved Trail Lateral Deviation"] = mean_c
        data["gaps"]["Curved Trail"] = {
            "real": mean_c,
            "sim": sim_c,
            "gap_pct": gap_pct(mean_c, sim_c),
            "gap_abs": gap_absolute(mean_c, sim_c),
        }

    return data


# ─────────────────────────────────────────────────────────────────────────────
# Reporting
# ─────────────────────────────────────────────────────────────────────────────

def generate_report(all_results: dict[str, dict[str, Any]]) -> str:
    """Generate a formatted analysis report."""
    lines = []
    lines.append("=" * 72)
    lines.append("  FormicaBot Chapter 6 — Sim-to-Real Gap Analysis Report")
    lines.append("=" * 72)
    lines.append("")

    lines.append("Methodology:")
    lines.append("  Gap (%) = |Real - Sim| / |Sim| × 100")
    lines.append("  Gap (abs) = |Real - Sim|")
    lines.append("  Target: All gaps < 15%")
    lines.append("")

    all_pass = True

    for exp_key, exp_data in sorted(all_results.items()):
        if not exp_data:
            continue

        gaps = exp_data.get("gaps", {})
        if not gaps:
            continue

        lines.append("-" * 72)
        lines.append(f"  {exp_key.upper()}")
        lines.append("-" * 72)
        lines.append(f"  {'Metric':<30} {'Real':>8} {'Sim':>8} {'Gap%':>8} {'Gap(abs)':>10} {'Pass':>6}")
        lines.append(f"  {'-'*30} {'-'*8} {'-'*8} {'-'*8} {'-'*10} {'-'*6}")

        for metric, gap_info in sorted(gaps.items()):
            real = gap_info.get("real")
            sim = gap_info.get("sim")
            gap_p = gap_info.get("gap_pct")
            gap_a = gap_info.get("gap_abs")

            real_str = f"{real:.4f}" if real is not None else "N/A"
            sim_str = f"{sim:.4f}" if sim is not None else "N/A"
            gap_p_str = f"{gap_p:.2f}%" if gap_p is not None else "N/A"
            gap_a_str = f"{gap_a:.4f}" if gap_a is not None else "N/A"
            passed = gap_p is not None and gap_p < 15.0
            pass_str = "PASS" if passed else "FAIL"
            if not passed:
                all_pass = False

            lines.append(f"  {metric:<30} {real_str:>8} {sim_str:>8} {gap_p_str:>8} {gap_a_str:>10} {pass_str:>6}")

        lines.append("")

    lines.append("=" * 72)
    lines.append("  OVERALL SIM-TO-REAL GAP ASSESSMENT")
    lines.append("=" * 72)

    if all_pass:
        lines.append("  RESULT: PASS — All sim-to-real gaps are within 15% threshold.")
    else:
        lines.append("  RESULT: FAIL — One or more gaps exceed 15% threshold.")
        lines.append("  Recommendation: Review physical sensor calibration and experiment protocol.")

    lines.append("")
    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def run(args: argparse.Namespace) -> int:
    v1_dir = Path(args.v1_dir).expanduser().resolve()
    out_dir = Path(args.output).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*70}")
    print(f"  Sim-to-Real Gap Analysis — FormicaBot Chapter 6 v1")
    print(f"{'='*70}")
    print(f"  v1 directory: {v1_dir}")
    print(f"  Output dir  : {out_dir}")
    print(f"{'='*70}\n")

    all_results: dict[str, dict[str, Any]] = {
        "exp1_sensor_calibration": analyse_exp1(v1_dir),
        "exp7_pheromone_trail": analyse_exp7(v1_dir),
    }

    # Print report to stdout
    report = generate_report(all_results)
    print(report)

    # Write report to file
    report_path = out_dir / "sim_to_real_gap_report.txt"
    report_path.write_text(report + "\n", encoding="utf-8")
    print(f"\n  Report saved: {report_path}")

    # Write gap CSV
    gap_csv = out_dir / "sim_to_real_gap_data.csv"
    with open(gap_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "experiment", "metric", "real_value", "sim_baseline",
            "gap_pct", "gap_absolute", "pass_15pct",
        ])
        writer.writeheader()
        for exp_key, exp_data in sorted(all_results.items()):
            for metric, gap_info in exp_data.get("gaps", {}).items():
                writer.writerow({
                    "experiment": exp_key,
                    "metric": metric,
                    "real_value": gap_info.get("real"),
                    "sim_baseline": gap_info.get("sim"),
                    "gap_pct": gap_info.get("gap_pct"),
                    "gap_absolute": gap_info.get("gap_abs"),
                    "pass_15pct": gap_info.get("gap_pct", 999) < 15.0,
                })
    print(f"  Gap CSV saved: {gap_csv}")

    print(f"\n{'='*70}")
    print(f"  Done.")
    print(f"{'='*70}\n")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="FormicaBot Sim-to-Real Gap Analysis")
    parser.add_argument(
        "--v1-dir",
        type=str,
        default="~/formica_experiments/data/v1",
        help="Path to v1 directory",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="~/formica_experiments/data/v1/figures",
        help="Output directory",
    )
    args = parser.parse_args()
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
