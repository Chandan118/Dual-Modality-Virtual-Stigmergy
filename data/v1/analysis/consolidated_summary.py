#!/usr/bin/env python3
"""
consolidated_summary.py
========================
Cross-experiment analysis for FormicaBot Chapter 6 v1.

Reads all experiment CSVs from the v1/ structure and produces:
  - consolidated_results.csv: One row per experiment with pass/fail
  - thesis_tables.md: Formatted tables for the thesis document
  - experiment_summary.txt: Human-readable summary

Usage:
    python consolidated_summary.py --v1-dir ~/formica_experiments/data/v1
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

# ─────────────────────────────────────────────────────────────────────────────
# Thresholds (from remediation summary)
# ─────────────────────────────────────────────────────────────────────────────
THRESHOLDS = {
    "exp1": {
        "lidar_rmse_m": (0.02, "max"),
        "imu_drift_deg_per_min": (0.5, "max"),
        "odom_error_pct": (2.0, "max"),
        "rgbd_reproj_px": (0.5, "max"),
        "tcrt_snr_db": (6.0, "min"),
    },
    "exp2": {
        "mean_power_W": (1.2, "max"),
    },
    "exp3": {
        "rmse_m": (0.15, "max"),
        "coverage_pct": (95.0, "min"),
    },
    "exp4": {
        "success_rate_pct": (89.0, "min"),
    },
    "exp5": {
        "success_rate_pct": (73.2, "min"),
    },
    "exp6": {
        "mAP": (0.92, "min"),
    },
    "exp7": {
        "sim_to_real_gap_pct": (15.0, "max"),
        "lateral_dev_straight_cm": (1.5, "max"),
        "lateral_dev_curved_cm": (2.0, "max"),
    },
}

# ─────────────────────────────────────────────────────────────────────────────
# CSV column mappings per experiment
# ─────────────────────────────────────────────────────────────────────────────
EXP_COLUMN_MAP = {
    "exp1": {
        "lidar_rmse_m": "lidar_rmse",
        "imu_drift_deg_per_min": "imu_drift_deg_per_min",
        "odom_error_pct": "odom_mean_error",
        "rgbd_reproj_px": "rgbd_reprojection_error",
        "tcrt_snr_db": "tcrt_snr",
    },
    "exp2": {
        "mean_power_W": "mean_W",
    },
    "exp3": {
        "rmse_m": "rmse",
        "coverage_pct": "coverage",
    },
    "exp4": {
        "success_rate_pct": "efficiency",
    },
    "exp5": {
        "success_rate_pct": "success_rate",
    },
    "exp6": {
        "mAP": "mAP",
    },
    "exp7": {
        "lateral_dev_straight_cm": "mean_lateral_cm",
        "lateral_dev_curved_cm": "mean_lateral_cm",
    },
}


# ─────────────────────────────────────────────────────────────────────────────
# Parsers
# ─────────────────────────────────────────────────────────────────────────────

def parse_exp1_table61(csv_path: Path) -> dict[str, float]:
    """Parse Table 6.1 CSV (exp1_table6_1_*.csv)."""
    results: dict[str, float] = {}
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            metric = row.get("metric", "").strip()
            val_str = row.get("value", "").strip()
            if not metric or not val_str:
                continue
            try:
                results[metric] = float(val_str)
            except ValueError:
                pass
    return results


def parse_exp2_table62(csv_path: Path) -> dict[str, float]:
    """Parse Table 6.2 power profile CSV."""
    results: dict[str, float] = {}
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            row_label = str(row.get("row", "")).strip()
            mean_str = str(row.get("mean_W", "")).strip()
            if "OVERALL" in row_label and mean_str not in ("", "N/A"):
                try:
                    results["mean_power_W"] = float(mean_str)
                except ValueError:
                    pass
    return results


def parse_exp3_slam(csv_path: Path) -> dict[str, float]:
    """Parse exp3 SLAM CSV for RMSE and coverage."""
    errors: list[float] = []
    coverages: list[float] = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            trial = str(row.get("trial", "")).strip()
            if trial.upper() in ("ALL", "RMSE", ""):
                continue
            err_str = str(row.get("error_m", "")).strip()
            cov_str = str(row.get("coverage_pct", "")).strip()
            if err_str not in ("", "N/A"):
                try:
                    errors.append(float(err_str))
                except ValueError:
                    pass
            if cov_str not in ("", "N/A"):
                try:
                    coverages.append(float(cov_str))
                except ValueError:
                    pass
    results: dict[str, float] = {}
    if errors:
        import statistics
        results["rmse_m"] = statistics.mean(errors)
    if coverages:
        results["coverage_pct"] = max(coverages) if errors else 0.0
    return results


def parse_exp4_maze(csv_path: Path) -> dict[str, float]:
    """Parse exp4 maze CSV for success rate."""
    total = 0
    successes = 0
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            trial = str(row.get("trial", "")).strip()
            outcome = str(row.get("outcome", "")).strip().upper()
            if trial.upper() in ("FINAL", ""):
                continue
            total += 1
            if outcome == "SUCCESS":
                successes += 1
    results: dict[str, float] = {}
    if total > 0:
        results["success_rate_pct"] = (successes / total) * 100.0
    return results


def parse_exp5_fault(csv_path: Path) -> dict[str, float]:
    """Parse exp5 fault tolerance CSV for success rate."""
    total = 0
    successes = 0
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            outcome = str(row.get("outcome", "")).strip().upper()
            total += 1
            if outcome == "SUCCESS":
                successes += 1
    results: dict[str, float] = {}
    if total > 0:
        results["success_rate_pct"] = (successes / total) * 100.0
    return results


def parse_exp6_cnn(csv_path: Path) -> dict[str, float]:
    """Parse exp6 CNN CSV for mAP."""
    ap_values: list[float] = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            condition = str(row.get("condition", "")).strip().upper()
            ap_str = str(row.get("AP", "")).strip()
            if condition == "OVERALL" or ap_str in ("", "N/A"):
                continue
            try:
                ap_values.append(float(ap_str))
            except ValueError:
                pass
    results: dict[str, float] = {}
    if ap_values:
        import statistics
        results["mAP"] = statistics.mean(ap_values)
    return results


def parse_exp7_pheromone(csv_path: Path) -> dict[str, float]:
    """Parse exp7 pheromone CSV for lateral deviation."""
    straight_devs: list[float] = []
    curved_devs: list[float] = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            sub_exp = str(row.get("sub_exp", "")).strip()
            dev_str = str(row.get("lateral_dev_m", "")).strip()
            if dev_str in ("", "N/A"):
                continue
            try:
                dev_m = float(dev_str) * 100.0  # convert to cm
                if sub_exp.startswith("A_straight"):
                    straight_devs.append(dev_m)
                elif sub_exp.startswith("B_curved"):
                    curved_devs.append(dev_m)
            except ValueError:
                pass
    results: dict[str, float] = {}
    if straight_devs:
        import statistics
        results["lateral_dev_straight_cm"] = statistics.mean(straight_devs)
    if curved_devs:
        import statistics
        results["lateral_dev_curved_cm"] = statistics.mean(curved_devs)
    return results


PARSERS = {
    "exp1": parse_exp1_table61,
    "exp2": parse_exp2_table62,
    "exp3": parse_exp3_slam,
    "exp4": parse_exp4_maze,
    "exp5": parse_exp5_fault,
    "exp6": parse_exp6_cnn,
    "exp7": parse_exp7_pheromone,
}


# ─────────────────────────────────────────────────────────────────────────────
# Evaluation
# ─────────────────────────────────────────────────────────────────────────────

def evaluate(exp_key: str, metrics: dict[str, float]) -> dict[str, Any]:
    """Compare metrics against thresholds."""
    thresholds = THRESHOLDS.get(exp_key, {})
    results: dict[str, Any] = {"pass": True, "metrics": {}}
    for key, (target, direction) in thresholds.items():
        if key not in metrics:
            results["metrics"][key] = {"value": None, "target": target, "pass": None}
            results["pass"] = False
            continue
        value = metrics[key]
        if direction == "max":
            passed = value <= target
        elif direction == "min":
            passed = value >= target
        else:
            passed = True
        results["metrics"][key] = {"value": value, "target": target, "pass": passed}
        if not passed:
            results["pass"] = False
    return results


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def find_latest_csv(v1_dir: Path, prefix: str) -> Path | None:
    """Find the latest CSV matching the given prefix."""
    results_dir = v1_dir
    if not results_dir.exists():
        # try within experiment subdirectory
        for exp_dir in v1_dir.iterdir():
            if exp_dir.is_dir() and (exp_dir / "results").exists():
                candidate = exp_dir / "results"
                matches = sorted(candidate.glob(f"{prefix}*.csv"), key=lambda p: p.stat().st_mtime)
                if matches:
                    return matches[-1]
    matches = sorted(results_dir.glob(f"{prefix}*.csv"), key=lambda p: p.stat().st_mtime)
    return matches[-1] if matches else None


def run(args: argparse.Namespace) -> int:
    v1_dir = Path(args.v1_dir).expanduser().resolve()
    out_dir = Path(args.output).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*70}")
    print(f"  FormicaBot Chapter 6 — Consolidated Summary (v1)")
    print(f"{'='*70}")
    print(f"  v1 directory : {v1_dir}")
    print(f"  Output dir   : {out_dir}")
    print(f"{'='*70}\n")

    all_results: list[dict[str, Any]] = []

    exp_configs = [
        ("exp1", "Sensor Calibration", "exp1_table6_1", ["table6_1"]),
        ("exp2", "Power Profiling", "table6_2", ["table6_2"]),
        ("exp3", "SLAM Mapping", "exp3_slam", ["exp3_slam"]),
        ("exp4", "Maze Navigation", "exp4_maze", ["exp4_maze"]),
        ("exp5", "Fault Tolerance", "exp5_fault", ["exp5_fault"]),
        ("exp6", "CNN Detection", "exp6_cnn", ["exp6_cnn"]),
        ("exp7", "Pheromone Trail", "exp7_pheromone", ["exp7_pheromone"]),
    ]

    for exp_key, exp_name, primary_prefix, alt_prefixes in exp_configs:
        print(f"\n{'─'*70}")
        print(f"  {exp_key.upper()}: {exp_name}")
        print(f"{'─'*70}")

        parser = PARSERS.get(exp_key)
        if not parser:
            print(f"  No parser for {exp_key}, skipping.")
            continue

        csv_path = find_latest_csv(v1_dir / exp_key, primary_prefix)
        if not csv_path:
            # try alternatives
            for alt in alt_prefixes:
                csv_path = find_latest_csv(v1_dir, alt)
                if csv_path:
                    break

        if not csv_path:
            print(f"  No CSV found for {exp_key}. Skipping.")
            all_results.append({
                "exp_key": exp_key,
                "exp_name": exp_name,
                "csv_path": None,
                "metrics": {},
                "evaluation": {"pass": None},
            })
            continue

        print(f"  CSV: {csv_path.name}")
        try:
            metrics = parser(csv_path)
        except Exception as exc:
            print(f"  ERROR parsing {csv_path.name}: {exc}")
            metrics = {}

        if metrics:
            print(f"  Metrics:")
            for k, v in metrics.items():
                print(f"    {k}: {v:.4f}")
            evaluation = evaluate(exp_key, metrics)
            print(f"  Result: {'PASS' if evaluation['pass'] else 'FAIL'}")
        else:
            evaluation = {"pass": None}
            print(f"  No metrics extracted.")

        all_results.append({
            "exp_key": exp_key,
            "exp_name": exp_name,
            "csv_path": str(csv_path),
            "metrics": metrics,
            "evaluation": evaluation,
        })

    # ── Write consolidated CSV ──────────────────────────────────────────────
    consolidated_csv = out_dir / "consolidated_results.csv"
    with open(consolidated_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "exp_key", "exp_name", "csv_file", "overall_pass",
            "lidar_rmse_m", "imu_drift_deg_per_min", "odom_error_pct",
            "rgbd_reproj_px", "tcrt_snr_db", "mean_power_W",
            "rmse_m", "coverage_pct", "success_rate_pct", "mAP",
            "lateral_dev_straight_cm", "lateral_dev_curved_cm",
            "sim_to_real_gap_pct",
        ])
        writer.writeheader()
        for r in all_results:
            row: dict[str, Any] = {
                "exp_key": r["exp_key"],
                "exp_name": r["exp_name"],
                "csv_file": Path(r["csv_path"]).name if r["csv_path"] else "",
                "overall_pass": r["evaluation"].get("pass"),
            }
            for k, v in r["metrics"].items():
                row[k] = v
            # sim-to-real gap (computed from exp7 lateral dev)
            if r["exp_key"] == "exp7":
                straight = r["metrics"].get("lateral_dev_straight_cm")
                if straight:
                    # Assume simulation baseline is 1.3 cm
                    SIM_BASELINE = 1.3
                    row["sim_to_real_gap_pct"] = abs(straight - SIM_BASELINE) / SIM_BASELINE * 100
            writer.writerow(row)

    print(f"\n  Consolidated CSV: {consolidated_csv}")

    # ── Write thesis tables markdown ─────────────────────────────────────────
    tables_md = out_dir / "thesis_tables.md"
    with open(tables_md, "w", encoding="utf-8") as f:
        f.write("# Chapter 6 Thesis Tables\n\n")
        f.write(f"_Generated: {datetime.now().isoformat()}_\n\n")

        # Table 6.1 — Sensor Calibration
        f.write("## Table 6.1: Sensor Calibration Results\n\n")
        f.write("| Metric | Measured | Target | Pass |\n")
        f.write("|--------|----------|--------|------|\n")
        exp1 = next((r for r in all_results if r["exp_key"] == "exp1"), None)
        if exp1:
            m = exp1["metrics"]
            ev = exp1["evaluation"]["metrics"]
            rows = [
                ("LiDAR RMSE", "lidar_rmse_m", "m", "<= 0.02"),
                ("IMU Drift", "imu_drift_deg_per_min", "deg/min", "<= 0.5"),
                ("Odom Error", "odom_error_pct", "%", "<= 2.0"),
                ("RGB-D Reproj", "rgbd_reproj_px", "px", "<= 0.5"),
                ("TCRT SNR", "tcrt_snr_db", "dB", ">= 6.0"),
            ]
            for label, key, unit, target in rows:
                val = m.get(key)
                p = ev.get(key, {}).get("pass")
                val_str = f"{val:.4f}" if val is not None else "N/A"
                p_str = "PASS" if p else ("FAIL" if p is False else "N/A")
                f.write(f"| {label} | {val_str} {unit} | {target} | {p_str} |\n")
        f.write("\n")

        # Table 6.2 — Power
        f.write("## Table 6.2: Power Profiling Results\n\n")
        f.write("| Platform | Mean Power (W) | Target | Pass |\n")
        f.write("|----------|---------------|--------|------|\n")
        exp2 = next((r for r in all_results if r["exp_key"] == "exp2"), None)
        if exp2:
            mean = exp2["metrics"].get("mean_power_W")
            ev = exp2["evaluation"]["metrics"].get("mean_power_W", {})
            val_str = f"{mean:.4f}" if mean is not None else "N/A"
            p = ev.get("pass")
            p_str = "PASS" if p else ("FAIL" if p is False else "N/A")
            f.write(f"| FormicaBot (this work) | {val_str} | <= 1.2 | {p_str} |\n")
        f.write(f"| FormicaBot V1 Baseline | 6.01 | — | — |\n")
        f.write(f"| Aliengo V2 | 0.669 | — | — |\n\n")

        # Table 6.3 — Navigation Summary
        f.write("## Table 6.3: Navigation and Fault Tolerance\n\n")
        f.write("| Experiment | Metric | Value | Target | Pass |\n")
        f.write("|------------|--------|-------|--------|------|\n")
        for exp_key, label, metric_key in [
            ("exp4", "Maze Navigation", "success_rate_pct"),
            ("exp5", "Fault Tolerance", "success_rate_pct"),
        ]:
            r = next((re for re in all_results if re["exp_key"] == exp_key), None)
            if r:
                val = r["metrics"].get(metric_key)
                ev = r["evaluation"]["metrics"].get(metric_key, {})
                val_str = f"{val:.1f}%" if val is not None else "N/A"
                target_map = {"exp4": ">= 89%", "exp5": ">= 73.2%"}
                p = ev.get("pass")
                p_str = "PASS" if p else ("FAIL" if p is False else "N/A")
                f.write(f"| {label} | Success Rate | {val_str} | {target_map[exp_key]} | {p_str} |\n")
        f.write("\n")

        # Table 6.4 — Detection and Pheromone
        f.write("## Table 6.4: Detection and Pheromone Following\n\n")
        f.write("| Experiment | Metric | Value | Target | Pass |\n")
        f.write("|------------|--------|-------|--------|------|\n")
        exp6 = next((r for r in all_results if r["exp_key"] == "exp6"), None)
        if exp6:
            val = exp6["metrics"].get("mAP")
            ev = exp6["evaluation"]["metrics"].get("mAP", {})
            val_str = f"{val:.4f}" if val is not None else "N/A"
            p = ev.get("pass")
            p_str = "PASS" if p else ("FAIL" if p is False else "N/A")
            f.write(f"| CNN Detection | mAP | {val_str} | >= 0.92 | {p_str} |\n")
        exp7 = next((r for r in all_results if r["exp_key"] == "exp7"), None)
        if exp7:
            m = exp7["metrics"]
            for label, key, unit, target in [
                ("Straight Lateral Dev", "lateral_dev_straight_cm", "cm", "<= 1.5"),
                ("Curved Lateral Dev", "lateral_dev_curved_cm", "cm", "<= 2.0"),
            ]:
                val = m.get(key)
                val_str = f"{val:.2f}" if val is not None else "N/A"
                f.write(f"| Pheromone ({label}) | | {val_str} {unit} | {target} | — |\n")
        f.write("\n")

    print(f"  Thesis tables: {tables_md}")

    # ── Write summary text ──────────────────────────────────────────────────
    summary_txt = out_dir / "experiment_summary.txt"
    with open(summary_txt, "w", encoding="utf-8") as f:
        f.write("FormicaBot Chapter 6 Experiment Summary (v1)\n")
        f.write("=" * 50 + "\n\n")
        for r in all_results:
            status = "PASS" if r["evaluation"].get("pass") else ("FAIL" if r["evaluation"].get("pass") is False else "N/A")
            f.write(f"[{status}] {r['exp_key']} - {r['exp_name']}\n")
            if r["csv_path"]:
                f.write(f"  Data: {Path(r['csv_path']).name}\n")
            for k, v in r["metrics"].items():
                f.write(f"  {k}: {v:.4f}\n")
            f.write("\n")
    print(f"  Summary text: {summary_txt}")

    print(f"\n{'='*70}")
    print(f"  Analysis complete. Results in: {out_dir}")
    print(f"{'='*70}\n")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="FormicaBot Chapter 6 v1 consolidated analysis")
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
        help="Output directory for generated files",
    )
    args = parser.parse_args()
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
