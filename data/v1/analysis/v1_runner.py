#!/usr/bin/env python3
"""
v1_runner.py
=============
Orchestrates the full v1 experiment pipeline.

Steps:
  1. Check hardware connectivity
  2. Run each experiment (Exp 1-7) in sequence
  3. Copy results to v1/ subdirectories
  4. Run post-processing (exp2, exp7)
  5. Generate consolidated summary, thesis tables, sim-to-real analysis

Usage:
    python v1_runner.py --v1-dir ~/formica_experiments/data/v1

Individual steps:
    python v1_runner.py --step check
    python v1_runner.py --step exp1
    python v1_runner.py --step copy_results
    python v1_runner.py --step postprocess
    python v1_runner.py --step analyse
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Literal


# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

EXP_SCRIPTS = {
    "exp1": "exp1_calibration",
    "exp2": "exp2_power",
    "exp3": "exp3_slam",
    "exp4": "exp4_maze",
    "exp5": "exp5_fault",
    "exp6": "exp6_cnn",
    "exp7": "exp7_pheromone",
}

DATA_DIR = Path.home() / "formica_experiments" / "data"
RUNNER_SCRIPT = Path.home() / "formica_experiments" / "scripts" / "chapter6_experiment_runner.sh"
EXP2_POSTPROCESS = Path.home() / "formica_experiments" / "formica_experiments" / "exp2_postprocess.py"
EXP7_POSTPROCESS = Path.home() / "formica_experiments" / "formica_experiments" / "exp7_postprocess.py"
ANALYSIS_DIR = Path(__file__).parent


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def log(msg: str) -> None:
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def run_cmd(cmd: list[str], timeout: int | None = None, check: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command and return the result."""
    log(f"Running: {' '.join(str(c) for c in cmd)}")
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=check,
        )
        if result.stdout:
            for line in result.stdout.splitlines()[:20]:
                print(f"  stdout: {line}")
        return result
    except subprocess.CalledProcessError as exc:
        print(f"  ERROR: Command failed with exit code {exc.returncode}")
        if exc.stdout:
            for line in exc.stdout.splitlines()[:10]:
                print(f"  stdout: {line}")
        if exc.stderr:
            for line in exc.stderr.splitlines()[:10]:
                print(f"  stderr: {line}")
        raise
    except subprocess.TimeoutExpired as exc:
        print(f"  ERROR: Command timed out after {timeout}s")
        raise


def find_latest_csv(prefix: str, data_dir: Path = DATA_DIR) -> Path | None:
    """Find the most recent CSV matching the prefix."""
    matches = sorted(data_dir.glob(f"{prefix}*.csv"), key=lambda p: p.stat().st_mtime, reverse=True)
    return matches[0] if matches else None


def copy_to_v1(csv_path: Path | None, v1_subdir: Path) -> bool:
    """Copy a CSV to the v1 experiment results directory."""
    if csv_path is None or not csv_path.exists():
        log(f"  No CSV to copy for {v1_subdir.name}")
        return False
    dest_dir = v1_subdir / "results"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / csv_path.name
    shutil.copy2(csv_path, dest)
    log(f"  Copied: {csv_path.name} -> {dest}")
    return True


# ─────────────────────────────────────────────────────────────────────────────
# Steps
# ─────────────────────────────────────────────────────────────────────────────

def step_check() -> int:
    """Check hardware connectivity."""
    log("STEP: Hardware Check")
    if RUNNER_SCRIPT.exists():
        result = run_cmd(["bash", str(RUNNER_SCRIPT), "check"], timeout=60, check=False)
        return result.returncode
    else:
        log(f"  Runner script not found: {RUNNER_SCRIPT}")
        log("  Please run hardware check manually:")
        log("    ros2 topic list")
        log("    ros2 doctor")
        return 0


def step_run_experiment(exp_key: str) -> int:
    """Run a single experiment via the runner script."""
    log(f"STEP: Running {exp_key.upper()}")
    if not RUNNER_SCRIPT.exists():
        log(f"  Runner script not found: {RUNNER_SCRIPT}")
        log(f"  Please run manually:")
        log(f"    cd ~/formica_experiments")
        log(f"    ./scripts/chapter6_experiment_runner.sh {exp_key}")
        return 1

    log(f"  Launching experiment via runner script...")
    result = run_cmd(
        ["bash", str(RUNNER_SCRIPT), exp_key],
        timeout=600,
        check=False,
    )
    log(f"  Experiment exited with code: {result.returncode}")
    return result.returncode


def step_copy_results(v1_dir: Path) -> int:
    """Copy latest CSVs from data/ to v1 subdirectories."""
    log("STEP: Copy Results to v1")

    copies = [
        ("exp1_table6_1", v1_dir / "exp1_sensor_calibration"),
        ("exp1_calibration", v1_dir / "exp1_sensor_calibration"),
        ("table6_2_power_profile", v1_dir / "exp2_power_profiling"),
        ("exp3_slam", v1_dir / "exp3_slam_mapping"),
        ("exp4_maze", v1_dir / "exp4_maze_navigation"),
        ("exp5_fault", v1_dir / "exp5_fault_tolerance"),
        ("exp6_cnn", v1_dir / "exp6_cnn_detection"),
        ("exp7_pheromone", v1_dir / "exp7_pheromone_trail"),
    ]

    success_count = 0
    for prefix, v1_subdir in copies:
        csv = find_latest_csv(prefix)
        if copy_to_v1(csv, v1_subdir):
            success_count += 1

    log(f"  Copied {success_count}/{len(copies)} result files.")
    return 0


def step_postprocess(v1_dir: Path) -> int:
    """Run post-processing scripts for exp2 and exp7."""
    log("STEP: Post-Processing")

    # exp2 postprocess
    exp2_csv = find_latest_csv("exp2_power")
    if exp2_csv and EXP2_POSTPROCESS.exists():
        log("  Running exp2 postprocess...")
        result = run_cmd(
            ["python3", str(EXP2_POSTPROCESS), str(exp2_csv)],
            timeout=120,
            check=False,
        )
        # Copy outputs to v1
        for suffix in ["table6_2", "exp2_summary", "Figure6_3"]:
            for ext in ["csv", "txt", "png"]:
                src = Path("/home/jetson/exp1_logs")
                if not src.exists():
                    src = v1_dir.parent
                matches = sorted(src.glob(f"{suffix}*.{ext}"))
                for m in matches[-1:]:
                    shutil.copy2(m, v1_dir / "exp2_power_profiling" / "results" / m.name)
    else:
        log("  exp2 CSV or postprocess script not found, skipping.")

    # exp7 postprocess
    exp7_csv = find_latest_csv("exp7_pheromone")
    if exp7_csv and EXP7_POSTPROCESS.exists():
        log("  Running exp7 postprocess...")
        result = run_cmd(
            ["python3", str(EXP7_POSTPROCESS), str(exp7_csv),
             "--out-dir", str(v1_dir / "exp7_pheromone_trail" / "results")],
            timeout=120,
            check=False,
        )
    else:
        log("  exp7 CSV or postprocess script not found, skipping.")

    return 0


def step_analyse(v1_dir: Path) -> int:
    """Run all analysis scripts."""
    log("STEP: Analysis")

    # Consolidated summary
    log("  Running consolidated_summary.py...")
    summary_script = ANALYSIS_DIR / "consolidated_summary.py"
    if summary_script.exists():
        run_cmd(
            ["python3", str(summary_script),
             "--v1-dir", str(v1_dir),
             "--output", str(v1_dir / "figures")],
            timeout=120,
            check=False,
        )
    else:
        log(f"  Script not found: {summary_script}")

    # Thesis table builder
    log("  Running thesis_table_builder.py...")
    table_script = ANALYSIS_DIR / "thesis_table_builder.py"
    if table_script.exists():
        run_cmd(
            ["python3", str(table_script),
             "--data-dir", str(v1_dir),
             "--output", str(v1_dir / "figures")],
            timeout=120,
            check=False,
        )

    # Sim-to-real analysis
    log("  Running sim_to_real_analysis.py...")
    sim_real_script = ANALYSIS_DIR / "sim_to_real_analysis.py"
    if sim_real_script.exists():
        run_cmd(
            ["python3", str(sim_real_script),
             "--v1-dir", str(v1_dir),
             "--output", str(v1_dir / "figures")],
            timeout=120,
            check=False,
        )

    return 0


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

STEPS: dict[str, callable] = {
    "check": step_check,
    "exp1": lambda _: step_run_experiment("exp1"),
    "exp2": lambda _: step_run_experiment("exp2"),
    "exp3": lambda _: step_run_experiment("exp3"),
    "exp4": lambda _: step_run_experiment("exp4"),
    "exp5": lambda _: step_run_experiment("exp5"),
    "exp6": lambda _: step_run_experiment("exp6"),
    "exp7": lambda _: step_run_experiment("exp7"),
    "copy_results": step_copy_results,
    "postprocess": step_postprocess,
    "analyse": step_analyse,
}


def run(args: argparse.Namespace) -> int:
    v1_dir = Path(args.v1_dir).expanduser().resolve()

    log(f"\n{'='*70}")
    log(f"  FormicaBot Chapter 6 v1 Experiment Runner")
    log(f"  v1 directory: {v1_dir}")
    log(f"{'='*70}\n")

    if args.step:
        step_fn = STEPS.get(args.step)
        if not step_fn:
            log(f"Unknown step: {args.step}")
            log(f"Available steps: {', '.join(STEPS.keys())}")
            return 1
        return step_fn(v1_dir)

    # Full pipeline
    log("Running FULL pipeline...\n")

    # 1. Check
    if step_check() != 0:
        log("Hardware check failed. Continuing anyway...")

    # 2. Run experiments
    for exp_key in ["exp1", "exp2", "exp3", "exp4", "exp5", "exp6", "exp7"]:
        log(f"\n{'─'*70}")
        log(f"  Experiment: {exp_key.upper()}")
        log(f"{'─'*70}")
        rc = step_run_experiment(exp_key)
        if rc != 0:
            log(f"  WARNING: {exp_key} returned non-zero exit code {rc}")
        time.sleep(2)

    # 3. Copy results
    step_copy_results(v1_dir)

    # 4. Post-process
    step_postprocess(v1_dir)

    # 5. Analyse
    step_analyse(v1_dir)

    log(f"\n{'='*70}")
    log(f"  Pipeline complete!")
    log(f"  Results: {v1_dir}")
    log(f"  Next: Review analysis output in {v1_dir / 'figures'}")
    log(f"{'='*70}\n")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="FormicaBot Chapter 6 v1 Experiment Runner")
    parser.add_argument(
        "--v1-dir",
        type=str,
        default="~/formica_experiments/data/v1",
        help="Path to v1 directory",
    )
    parser.add_argument(
        "--step",
        type=str,
        choices=list(STEPS.keys()),
        help="Run a specific step (default: run full pipeline)",
    )
    args = parser.parse_args()
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
