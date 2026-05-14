#!/usr/bin/env python3
"""
thesis_table_builder.py
=======================
Builds publication-ready tables for the FormicaBot thesis Chapter 6.

Generates LaTeX, CSV, and Markdown formats for:
  - Table 6.1: Sensor Calibration
  - Table 6.2: Power Profiling
  - Table 6.3: SLAM Mapping Results
  - Table 6.4: Navigation and Fault Tolerance
  - Table 6.5: CNN Detection Metrics
  - Table 6.6: Pheromone Trail Following

Usage:
    python thesis_table_builder.py --data-dir ~/formica_experiments/data/v1
"""

from __future__ import annotations

import argparse
import csv
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


# ─────────────────────────────────────────────────────────────────────────────
# Table definitions
# ─────────────────────────────────────────────────────────────────────────────

TABLE_DEFS = {
    "table6_1": {
        "title": "Table 6.1: Multi-Sensor Calibration Results",
        "caption": "Results from Experiment 1: Sensor Calibration. All six sensor subsystems were evaluated against thesis-specified targets.",
        "columns": ["Metric", "Measured Value", "Unit", "Target", "Pass/Fail"],
        "rows": [
            ("LiDAR Range RMSE", "lidar_rmse_m", "{:.4f}", "m", "<= 0.02"),
            ("IMU Angular Drift", "imu_drift_deg_per_min", "{:.4f}", "deg/min", "<= 0.5"),
            ("Wheel Odom Mean Error", "odom_error_pct", "{:.4f}", "%", "<= 2.0"),
            ("Wheel Odom SD", "odom_sd_pct", "{:.4f}", "%", "report"),
            ("RGB-D Reprojection", "rgbd_reproj_px", "{:.4f}", "px", "<= 0.5"),
            ("TCRT5000 SNR", "tcrt_snr_db", "{:.2f}", "dB", ">= 6.0"),
            ("tf2 Latency", "tf2_latency_ms", "{:.2f}", "ms", "<= 10.0"),
            ("Odom RMSE", "odom_rmse_m", "{:.4f}", "m", "<= 0.05"),
            ("Odom Mean Abs Error", "odom_mean_abs_error_m", "{:.4f}", "m", "<= 0.05"),
        ],
    },
    "table6_2": {
        "title": "Table 6.2: Power Profiling Results",
        "caption": "Results from Experiment 2: Power Profiling. Mean power consumption across TRANSIT, DECISION, and STANDBY modes.",
        "columns": ["Platform / Mode", "Mean (W)", "SD (W)", "Peak (W)", "Min (W)", "Target"],
        "rows": [
            ("TRANSIT (this work)", "transit_mean_W", "{:.4f}", "W", "—"),
            ("DECISION (this work)", "decision_mean_W", "{:.4f}", "W", "—"),
            ("STANDBY (this work)", "standby_mean_W", "{:.4f}", "W", "—"),
            ("OVERALL (this work)", "overall_mean_W", "{:.4f}", "W", "<= 1.2"),
            ("FormicaBot V1 Baseline", "baseline_W", "6.01", "W", "—"),
            ("Aliengo V2 (benchmark)", "aliengo_W", "0.669", "W", "—"),
            ("Kilobot (benchmark)", "kilobot_W", "N/A", "W", "—"),
        ],
    },
    "table6_3": {
        "title": "Table 6.3: SLAM Mapping Results",
        "caption": "Results from Experiment 3: SLAM-Based Mapping. Localization RMSE at 4 ArUco landmark positions across 10 trials.",
        "columns": ["Trial", "Landmark", "GT (m)", "Est (m)", "Error (m)", "Coverage (%)"],
        "rows": [],
    },
    "table6_4": {
        "title": "Table 6.4: Navigation and Fault Tolerance",
        "caption": "Results from Experiments 4 and 5. Maze navigation success rate and fault tolerance under sensor/obstacle perturbations.",
        "columns": ["Experiment", "Condition", "Successes", "Total Trials", "Success Rate (%)", "Target (%)", "Pass/Fail"],
        "rows": [
            ("Maze Navigation", "Standard", "exp4_successes", "20", "exp4_rate", "89.0", "exp4"),
            ("Fault Tolerance", "Obstacle Injection", "exp5_obstacle_successes", "10", "exp5_obstacle_rate", "—", "exp5"),
            ("Fault Tolerance", "LiDAR Kill", "exp5_lidar_successes", "5", "exp5_lidar_rate", "—", "exp5"),
            ("Fault Tolerance", "Camera Kill", "exp5_camera_successes", "5", "exp5_camera_rate", "—", "exp5"),
            ("Fault Tolerance", "Line Sensor Kill", "exp5_line_successes", "5", "exp5_line_rate", "—", "exp5"),
            ("Fault Tolerance", "Overall", "exp5_total_successes", "25", "exp5_total_rate", "73.2", "exp5"),
        ],
    },
    "table6_5": {
        "title": "Table 6.5: CNN Detection Performance",
        "caption": "Results from Experiment 6: CNN-Based Target Recognition. Mean Average Precision (mAP) across 3 classes and 3 lighting conditions.",
        "columns": ["Class", "Normal mAP", "Low Light mAP", "Clutter mAP", "Overall mAP"],
        "rows": [
            ("red_cube", "exp6_red_normal", "exp6_red_low", "exp6_red_clutter", "exp6_red_overall"),
            ("green_cylinder", "exp6_green_normal", "exp6_green_low", "exp6_green_clutter", "exp6_green_overall"),
            ("blue_sphere", "exp6_blue_normal", "exp6_blue_low", "exp6_blue_clutter", "exp6_blue_overall"),
            ("ALL CLASSES", "—", "—", "—", "exp6_overall_mAP"),
        ],
    },
    "table6_6": {
        "title": "Table 6.6: Pheromone Trail Following",
        "caption": "Results from Experiment 7: Virtual Pheromone Trail. Lateral deviation and sim-to-real gap analysis.",
        "columns": ["Sub-Experiment", "Mean Lateral Dev (cm)", "Target (cm)", "Sim Baseline (cm)", "Gap (%)", "Target Gap (%)"],
        "rows": [
            ("Straight Trail", "exp7_straight_dev", "{:.2f}", "1.3", "exp7_straight_gap", "15"),
            ("Curved Trail", "exp7_curved_dev", "{:.2f}", "1.7", "exp7_curved_gap", "15"),
            ("SNR Switchover", "exp7_snr_latency", "{:.3f} s", "—", "—", "—"),
        ],
    },
}


# ─────────────────────────────────────────────────────────────────────────────
# Formatters
# ─────────────────────────────────────────────────────────────────────────────

def format_latex_table(table_id: str, data: dict[str, Any]) -> str:
    """Generate a LaTeX booktabs table."""
    defn = TABLE_DEFS.get(table_id, {})
    title = defn.get("title", table_id)
    caption = defn.get("caption", "")
    cols = defn.get("columns", [])
    col_spec = " | ".join(["l"] * len(cols))

    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("  \\centering")
    lines.append(f"  \\caption{{{caption}}}")
    lines.append(f"  \\begin{{tabular}}{{@{{}}{col_spec}@{{}}}}")
    lines.append("    \\toprule")
    lines.append("    " + " & ".join(cols) + " \\\\")
    lines.append("    \\midrule")

    for row_data in defn.get("rows", []):
        if not row_data:
            continue
        label = row_data[0]
        values = []
        for val in row_data[1:]:
            if isinstance(val, str) and val.startswith("exp"):
                d = data.get(val)
                fmt = row_data[2] if len(row_data) > 2 and "{" in row_data[2] else "{}"
                values.append(fmt.format(d) if d is not None else "—")
            else:
                values.append(str(val))
        lines.append("    " + " & ".join([label] + values) + " \\\\")

    lines.append("    \\bottomrule")
    lines.append("  \\end{tabular}")
    lines.append(f"  \\label{{tab:{table_id}}}")
    lines.append("\\end{table}")
    return "\n".join(lines)


def format_csv_table(table_id: str, data: dict[str, Any]) -> str:
    """Generate CSV table."""
    defn = TABLE_DEFS.get(table_id, {})
    cols = defn.get("columns", [])
    rows = defn.get("rows", [])
    output_lines = [",".join(cols)]
    for row_data in rows:
        label = row_data[0]
        values = []
        for val in row_data[1:]:
            if isinstance(val, str) and val.startswith("exp"):
                d = data.get(val)
                values.append(str(round(d, 4)) if d is not None else "")
            else:
                values.append(str(val))
        output_lines.append(",".join([label] + values))
    return "\n".join(output_lines)


def format_markdown_table(table_id: str, data: dict[str, Any]) -> str:
    """Generate Markdown table."""
    defn = TABLE_DEFS.get(table_id, {})
    cols = defn.get("columns", [])
    rows = defn.get("rows", [])

    lines = []
    lines.append(f"### {defn.get('title', table_id)}")
    lines.append("")
    lines.append(f"*{defn.get('caption', '')}*")
    lines.append("")
    lines.append("| " + " | ".join(cols) + " |")
    lines.append("| " + " | ".join(["---"] * len(cols)) + " |")

    for row_data in rows:
        label = row_data[0]
        values = []
        for val in row_data[1:]:
            if isinstance(val, str) and val.startswith("exp"):
                d = data.get(val)
                fmt = row_data[2] if len(row_data) > 2 and "{" in row_data[2] else "{}"
                values.append(fmt.format(d) if d is not None else "—")
            else:
                values.append(str(val))
        lines.append("| " + " | ".join([label] + values) + " |")
    lines.append("")
    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# Data extraction helpers
# ─────────────────────────────────────────────────────────────────────────────

def extract_table61(v1_dir: Path) -> dict[str, Any]:
    """Extract Table 6.1 data from exp1 results."""
    data: dict[str, Any] = {}
    results_dir = v1_dir / "exp1_sensor_calibration" / "results"
    if not results_dir.exists():
        return data
    matches = sorted(results_dir.glob("table6_1*.csv"), key=lambda p: p.stat().st_mtime)
    if not matches:
        return data
    with open(matches[-1], newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            metric = row.get("metric", "").strip().lower().replace(" ", "_")
            val_str = row.get("value", "").strip()
            try:
                data[f"t61_{metric}"] = float(val_str)
            except ValueError:
                pass
    return data


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def run(args: argparse.Namespace) -> int:
    v1_dir = Path(args.data_dir).expanduser().resolve()
    out_dir = Path(args.output).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*70}")
    print(f"  Thesis Table Builder — FormicaBot Chapter 6 v1")
    print(f"{'='*70}")
    print(f"  Data dir : {v1_dir}")
    print(f"  Output   : {out_dir}")
    print(f"{'='*70}\n")

    # Gather all data
    all_data: dict[str, Any] = {}
    all_data.update(extract_table61(v1_dir))

    # Generate tables
    for table_id, defn in TABLE_DEFS.items():
        print(f"  Building {table_id}...")

        latex = format_latex_table(table_id, all_data)
        csv_out = format_csv_table(table_id, all_data)
        md = format_markdown_table(table_id, all_data)

        (out_dir / f"{table_id}.tex").write_text(latex + "\n", encoding="utf-8")
        (out_dir / f"{table_id}.csv").write_text(csv_out + "\n", encoding="utf-8")
        (out_dir / f"{table_id}.md").write_text(md + "\n", encoding="utf-8")

        print(f"    {table_id}.tex | {table_id}.csv | {table_id}.md")

    # Master combined markdown
    master_md = out_dir / "thesis_tables_combined.md"
    with open(master_md, "w", encoding="utf-8") as f:
        f.write("# Chapter 6 Thesis Tables\n\n")
        f.write(f"_Generated: {datetime.now().isoformat()}_\n\n")
        for table_id in TABLE_DEFS:
            content = (out_dir / f"{table_id}.md").read_text(encoding="utf-8")
            f.write(content)
            f.write("\n---\n\n")
    print(f"\n  Combined tables: {master_md}")

    print(f"\n{'='*70}")
    print(f"  Done. Output: {out_dir}")
    print(f"{'='*70}\n")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="FormicaBot Thesis Table Builder")
    parser.add_argument(
        "--data-dir",
        type=str,
        default="~/formica_experiments/data/v1",
        help="Path to v1 data directory",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="~/formica_experiments/data/v1/figures",
        help="Output directory for table files",
    )
    args = parser.parse_args()
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
