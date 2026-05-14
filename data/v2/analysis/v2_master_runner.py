#!/usr/bin/env python3
"""
V2 Master Runner — Alloingo V2 Experiment Suite
Chandan Sheik, FormicaBot Thesis, 2026

Usage:
    python v2_master_runner.py --all              # Run all experiments
    python v2_master_runner.py --exp 1           # Run only experiment 1
    python v2_master_runner.py --exp 2 --exp 3 # Run experiments 2 and 3
    python v2_master_runner.py --check          # Hardware connectivity check

This script orchestrates all V2 experiments on the Alloingo platform.
SSH access to 192.168.123.12 (TX2) is required.
"""

import argparse
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.parent
TX2_HOST = "unitree@192.168.123.12"
MINIPC_HOST = "unitree@192.168.123.220"

EXPERIMENTS = {
    1: {
        'name': 'Power Profiling',
        'desc': 'Prove <= 1.2W average power consumption',
        'script': 'exp1_power_profiling/scripts/v2_power_logger.py',
        'sim_script': 'exp1_power_profiling/scripts/v2_power_logger.py --simulate',
        'duration': '10 min',
        'target': 'Mean power <= 1.2W',
        'v1_baseline': '6.0W',
        'v2_target': '<= 1.2W',
    },
    2: {
        'name': 'Maze Navigation',
        'desc': 'Achieve >= 89% success in Complex Maze',
        'script': 'exp2_maze_navigation/scripts/v2_maze_runner.py',
        'sim_script': 'exp2_maze_navigation/scripts/v2_maze_runner.py --simulate --trials 20',
        'duration': '20 trials',
        'target': '>= 89% success rate',
        'v1_baseline': '~100% (reactive only, no SLAM)',
        'v2_target': '>= 89% (full LiDAR/SLAM)',
    },
    3: {
        'name': 'Pheromone S2R Gap',
        'desc': 'Quantify sim-to-real gap for TCRT5000 sensors',
        'script': 'exp3_pheromone_s2r/scripts/v2_s2r_analysis.py',
        'sim_script': 'exp3_pheromone_s2r/scripts/v2_s2r_analysis.py --sim',
        'duration': '10 trials + analysis',
        'target': 'S2R gap < 10%',
        'v1_baseline': '15.4% (exceeded threshold)',
        'v2_target': '< 10%',
    },
    4: {
        'name': 'Fault Tolerance',
        'desc': 'Validate recovery under LiDAR failure',
        'script': 'exp4_fault_tolerance/scripts/v2_fault_runner.py',
        'sim_script': 'exp4_fault_tolerance/scripts/v2_fault_runner.py --simulate --trials 30',
        'duration': '30 trials',
        'target': '< 0.5s recovery, >= 73.2% success',
        'v1_baseline': '1.8s recovery (node kill/re-launch)',
        'v2_target': '< 0.5s (interrupt-driven)',
    },
    5: {
        'name': 'Thermal Profile',
        'desc': 'Demonstrate negligible thermal signature',
        'script': 'exp5_thermal_profile/scripts/v2_thermal_logger.py',
        'sim_script': 'exp5_thermal_profile/scripts/v2_thermal_logger.py --parse-only',
        'duration': '30 min',
        'target': 'CPU < 50C, rise < 5C above ambient',
        'v1_baseline': '~80C CPU, ~15C rise',
        'v2_target': '< 50C CPU, < 5C rise',
    },
}


def print_banner(text: str):
    width = 70
    print("\n" + "=" * width)
    print(f"  {text}")
    print("=" * width)


def print_table(experiments: list):
    """Print experiment summary table."""
    print("\n  V2 EXPERIMENT SUITE")
    print(f"  {'Exp':<5} {'Name':<20} {'Duration':<12} {'Target':<30}")
    print(f"  {'-'*5} {'-'*20} {'-'*12} {'-'*30}")
    for n in experiments:
        e = EXPERIMENTS[n]
        print(f"  {n:<5} {e['name']:<20} {e['duration']:<12} {e['target']:<30}")
    print()


def ssh_check(host: str, label: str) -> bool:
    """Check SSH connectivity to a host."""
    print(f"  Checking {label} ({host})...", end=" ", flush=True)
    try:
        result = subprocess.run(
            ['ssh', '-o', 'ConnectTimeout=5', '-o', 'StrictHostKeyChecking=no',
             host, 'echo ok'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and 'ok' in result.stdout:
            print("✓ reachable")
            return True
        else:
            print("✗ not reachable")
            return False
    except Exception as e:
        print(f"✗ error: {e}")
        return False


def hardware_check() -> bool:
    """Verify connectivity to all Alloingo boards."""
    print_banner("HARDWARE CONNECTIVITY CHECK")

    results = {}

    # Check TX2 (Sensing Motherboard)
    results['tx2'] = ssh_check(TX2_HOST, "TX2 (Sensing)")

    # Check Mini PC (Motion Motherboard)
    results['minipc'] = ssh_check(MINIPC_HOST, "Mini PC (Motion)")

    # Check network connectivity
    print("\n  Checking network reachability...")
    for ip in ['192.168.123.12', '192.168.123.220', '192.168.123.254']:
        result = subprocess.run(
            ['ping', '-c', '1', '-W', '2', ip],
            capture_output=True, text=True
        )
        status = "✓" if result.returncode == 0 else "✗"
        print(f"    {status} {ip}")

    all_ok = all(results.values())
    print(f"\n  Overall: {'PASS ✓' if all_ok else 'FAIL ✗ — check network'}")
    return all_ok


def run_experiment(
    exp_num: int,
    simulate: bool = False,
    output_base: str = None,
) -> bool:
    """Run a single V2 experiment."""
    e = EXPERIMENTS[exp_num]
    script = e['sim_script'] if simulate else e['script']

    print_banner(f"EXPERIMENT V2-{exp_num}: {e['name'].upper()}")
    print(f"  Description: {e['desc']}")
    print(f"  V1 Baseline: {e['v1_baseline']}")
    print(f"  V2 Target  : {e['v2_target']}")
    print(f"  Duration   : {e['duration']}")

    if simulate:
        print(f"\n  Mode: SIMULATION (--simulate flag)")
    else:
        print(f"\n  Mode: LIVE HARDWARE")
        print(f"  SSH: {TX2_HOST}")

    output_dir = output_base or str(SCRIPT_DIR)
    script_path = SCRIPT_DIR / script

    if not script_path.exists():
        print(f"\n  ERROR: Script not found: {script_path}")
        return False

    # Build command
    cmd = [
        'python3', str(script_path),
        '--output', f'{output_dir}/exp{exp_num}_*/results/'
    ]

    if simulate:
        cmd = [
            'python3', str(script_path),
            '--output', f'{output_dir}/exp{exp_num}_*/results/',
            '--simulate',
        ]
        if exp_num == 2:
            cmd.insert(2, '--trials')
            cmd.insert(3, '20')
        elif exp_num == 4:
            cmd.insert(2, '--trials')
            cmd.insert(3, '30')

    print(f"\n  Command: {' '.join(cmd)}")

    try:
        result = subprocess.run(cmd, capture_output=False, text=True, timeout=3600)
        success = result.returncode == 0
        print(f"\n  Result: {'PASS ✓' if success else 'FAIL ✗'}")
        return success
    except subprocess.TimeoutExpired:
        print(f"\n  ERROR: Experiment timed out after 60 minutes")
        return False
    except Exception as e:
        print(f"\n  ERROR: {e}")
        return False


def run_full_suite(
    experiments: list,
    simulate: bool = False,
    output_base: str = None,
) -> dict:
    """Run all selected experiments in sequence."""
    print_banner(f"ALLINGO V2 — FULL EXPERIMENT SUITE")
    print(f"  Date    : {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"  Mode    : {'SIMULATION' if simulate else 'LIVE HARDWARE'}")
    print(f"  Output  : {output_base or str(SCRIPT_DIR)}")
    print_table(experiments)

    if not simulate:
        proceed = input("  Proceed with live hardware experiments? (y/n): ")
        if proceed.lower() != 'y':
            print("  Aborted.")
            return {}

    results = {}
    overall_start = time.time()

    for n in experiments:
        exp_start = time.time()
        print(f"\n  >>> Starting V2-{n}: {EXPERIMENTS[n]['name']}")
        results[n] = run_experiment(n, simulate=simulate, output_base=output_base)
        exp_elapsed = time.time() - exp_start
        print(f"\n  V2-{n} completed in {exp_elapsed/60:.1f} minutes")
        print(f"  {'─' * 60}")

        # Small pause between experiments
        if n < max(experiments) and not simulate:
            time.sleep(2)

    overall_elapsed = time.time() - overall_start

    # Print summary
    print_banner("EXPERIMENT SUITE SUMMARY")
    print(f"  {'Exp':<5} {'Name':<22} {'Result':<10} {'Duration'}")
    print(f"  {'-'*5} {'-'*22} {'-'*10} {'-'*20}")
    for n in experiments:
        e = EXPERIMENTS[n]
        status = "PASS ✓" if results.get(n) else "FAIL ✗"
        print(f"  V2-{n:<3} {e['name']:<22} {status:<10}")
    print()
    print(f"  Total elapsed: {overall_elapsed/60:.1f} minutes")
    passed = sum(1 for v in results.values() if v)
    print(f"  Passed: {passed}/{len(results)}")
    print("=" * 70)

    return results


def main():
    parser = argparse.ArgumentParser(
        description='Alloingo V2 Master Experiment Runner',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python v2_master_runner.py --all --simulate
      Run all experiments in simulation mode

  python v2_master_runner.py --exp 1 --exp 2
      Run only experiments 1 (Power) and 2 (Maze) on live hardware

  python v2_master_runner.py --check
      Verify hardware connectivity without running experiments

  python v2_master_runner.py --exp 1 --output /tmp/v2_data
      Run experiment 1, output to /tmp/v2_data
        """
    )
    parser.add_argument(
        '--all', '-a', action='store_true',
        help='Run all experiments'
    )
    parser.add_argument(
        '--exp', '-e', type=int, action='append', dest='experiments',
        help='Experiment number to run (can be specified multiple times)'
    )
    parser.add_argument(
        '--check', action='store_true',
        help='Run hardware connectivity check only'
    )
    parser.add_argument(
        '--simulate', '-s', action='store_true',
        help='Run in simulation mode (no live hardware required)'
    )
    parser.add_argument(
        '--output', '-o', type=str, default=None,
        help='Base output directory (default: ./data/v2/)'
    )

    args = parser.parse_args()

    # Default to all experiments if none specified
    experiments = args.experiments or (list(EXPERIMENTS.keys()) if args.all else [])
    output_base = args.output or str(SCRIPT_DIR / 'data')

    if args.check:
        hardware_check()
        return

    if not experiments:
        print_banner("ALLINGO V2 — EXPERIMENT SUITE")
        print("  No experiments specified.")
        print("  Available experiments:")
        print_table(list(EXPERIMENTS.keys()))
        print("  Usage examples:")
        print("    python v2_master_runner.py --all --simulate")
        print("    python v2_master_runner.py --exp 1 --exp 2")
        print("    python v2_master_runner.py --check")
        return

    # Validate experiment numbers
    invalid = [n for n in experiments if n not in EXPERIMENTS]
    if invalid:
        print(f"  ERROR: Invalid experiment numbers: {invalid}")
        print(f"  Valid: {list(EXPERIMENTS.keys())}")
        return

    run_full_suite(
        experiments=experiments,
        simulate=args.simulate,
        output_base=output_base,
    )


if __name__ == '__main__':
    main()
