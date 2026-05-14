#!/usr/bin/env python3
"""
V2 Master Runner — Alloingo V2 Engineering Validation
Runs all 5 V2 experiments sequentially or individually.

Usage:
    python v2_master.py all              # Run all experiments
    python v2_master.py check            # Hardware connectivity check
    python v2_master.py exp1             # Power profiling
    python v2_master.py exp2             # Maze navigation
    python v2_master.py exp3             # Pheromone S2R
    python v2_master.py exp4             # Fault tolerance
    python v2_master.py exp5             # Thermal profile
    python v2_master.py analyse          # Run analysis on collected data
    python v2_master.py summary          # Generate final consolidated summary

Requirements:
    - ROS 2 Humble installed on TX2 (192.168.123.12)
    - SSH access to TX2 and Mini PC
    - Alloingo V2 platform powered on
"""

import argparse
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# Base paths — consistent with v1/ structure
# data/v2/exp1_power_profiling/results/
SCRIPT_DIR = Path(__file__).parent.resolve()
V2_ROOT = SCRIPT_DIR  # /home/jetson/formica_experiments/data/v2/
DATA_ROOT = V2_ROOT   # experiments and results live inside v2/

# Board addresses
TX2_IP = "192.168.123.12"
MINIPC_IP = "192.168.123.220"


def run_cmd(cmd: list[str], desc: str = "", check: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command and print status."""
    print(f"\n{'='*60}")
    print(f"  {desc}")
    print(f"  Command: {' '.join(cmd[:3])}...")
    print(f"{'='*60}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.stdout:
            print(result.stdout[:500])
        if result.returncode != 0 and check:
            print(f"WARNING: Command returned code {result.returncode}")
            if result.stderr:
                print(f"STDERR: {result.stderr[:200]}")
        return result
    except subprocess.TimeoutExpired:
        print("ERROR: Command timed out")
        return subprocess.CompletedProcess(cmd, 1, "", "Timeout")
    except FileNotFoundError:
        print(f"ERROR: Command not found: {cmd[0]}")
        print("  (This may be expected if not running on the TX2)")
        return subprocess.CompletedProcess(cmd, 1, "", "Not found")


def check_hardware() -> bool:
    """Verify connectivity to all boards."""
    print("\n" + "=" * 60)
    print("  HARDWARE CONNECTIVITY CHECK")
    print("=" * 60)

    boards = [
        (TX2_IP, "Jetson TX2 (Sensing Motherboard)"),
        (MINIPC_IP, "Mini PC (Motion Motherboard)"),
    ]

    all_ok = True
    for ip, name in boards:
        result = subprocess.run(
            ["ping", "-c", "2", "-W", "2", ip],
            capture_output=True
        )
        status = "✓ PASS" if result.returncode == 0 else "✗ FAIL"
        print(f"  {name} ({ip}): {status}")
        if result.returncode != 0:
            all_ok = False

    print(f"\n  Overall: {'✓ ALL REACHABLE' if all_ok else '✗ SOME UNREACHABLE'}")
    return all_ok


def run_ssh_check() -> bool:
    """Check SSH access to boards."""
    print("\n  Checking SSH access...")
    try:
        result = subprocess.run(
            ["ssh", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=no",
             f"unitree@{TX2_IP}", "echo", "SSH_OK"],
            capture_output=True, text=True, timeout=10
        )
        if "SSH_OK" in result.stdout:
            print(f"  ✓ SSH to TX2 ({TX2_IP}) OK")
            return True
        else:
            print(f"  ✗ SSH to TX2 failed")
            return False
    except Exception as e:
        print(f"  ✗ SSH check error: {e}")
        return False


def run_exp1() -> bool:
    """V2-1: Power Profiling."""
    print("\n" + "=" * 60)
    print("  EXPERIMENT V2-1: POWER PROFILING")
    print("=" * 60)
    print("  Target: Mean power <= 1.2 W (V1 was 6.0 W)")
    print("  Duration: 10 minutes")
    print("  Method: tegrastats + PDB INA3221 logging")
    print("=" * 60)

    results_dir = DATA_ROOT / "exp1_power_profiling" / "results"
    results_dir.mkdir(parents=True, exist_ok=True)

    # Option 1: Run via SSH on TX2 (requires actual hardware)
    use_ssh = input("\n  Run on TX2 hardware via SSH? (y/n, default: n [simulate]): ")
    if use_ssh.lower() == 'y':
        script = SCRIPT_DIR / "exp1_power_profiling" / "scripts" / "v2_power_logger.py"
        cmd = [
            "ssh", f"unitree@{TX2_IP}",
            f"python3 {script} --duration 600 --output ~/v2_results/"
        ]
        run_cmd(cmd, "Running V2-1 on TX2", check=False)
    else:
        # Simulated run
        script = SCRIPT_DIR / "exp1_power_profiling" / "scripts" / "v2_power_logger.py"
        cmd = [
            sys.executable, str(script),
            "--duration", "600",
            "--output", str(results_dir),
            "--tegrastats", str(SCRIPT_DIR / "mock" / "tegrastats.log"),
        ]
        print(f"\n  [SIMULATED] Running power logger...")
        print(f"  Output: {results_dir}")
        result = run_cmd(cmd, "V2-1 Power Profiling (simulated)", check=False)
        return result.returncode == 0

    return True


def run_exp2() -> bool:
    """V2-2: Maze Navigation."""
    print("\n" + "=" * 60)
    print("  EXPERIMENT V2-2: OPTIMIZED MAZE NAVIGATION")
    print("=" * 60)
    print("  Target: >= 89% success rate (20 trials)")
    print("  Nav2 params: inflation_radius=0.15m, cost_scaling=1.8")
    print("  V1 context: V1 maze succeeded via reactive-only (ultrasonic/IR)")
    print("=" * 60)

    results_dir = DATA_ROOT / "exp2_maze_navigation" / "results"
    results_dir.mkdir(parents=True, exist_ok=True)

    use_ssh = input("\n  Run on TX2 hardware via SSH? (y/n, default: n [simulate]): ")
    if use_ssh.lower() == 'y':
        script = SCRIPT_DIR / "exp2_maze_navigation" / "scripts" / "v2_maze_runner.py"
        cmd = [
            "ssh", f"unitree@{TX2_IP}",
            f"python3 {script} --trials 20 --timeout 120"
        ]
        run_cmd(cmd, "Running V2-2 on TX2", check=False)
    else:
        script = SCRIPT_DIR / "exp2_maze_navigation" / "scripts" / "v2_maze_runner.py"
        cmd = [
            sys.executable, str(script),
            "--trials", "20",
            "--timeout", "120",
            "--output", str(results_dir),
            "--simulate",
        ]
        print(f"\n  [SIMULATED] Running maze navigation...")
        result = run_cmd(cmd, "V2-2 Maze Navigation (simulated)", check=False)
        return result.returncode == 0

    return True


def run_exp3() -> bool:
    """V2-3: Pheromone Sim-to-Real Gap."""
    print("\n" + "=" * 60)
    print("  EXPERIMENT V2-3: PHEROMONE SIM-TO-REAL GAP")
    print("=" * 60)
    print("  Target: S2R gap < 10% (V1 was 15.4%)")
    print("  Target: Deviation <= 1.0 cm (V1 was 1.5 cm)")
    print("  Method: Gazebo sim vs physical TCRT5000 ADC values")
    print("=" * 60)

    results_dir = DATA_ROOT / "exp3_pheromone_s2r" / "results"
    results_dir.mkdir(parents=True, exist_ok=True)

    # Check for pre-existing data
    sim_csv = results_dir / "sim_baseline.csv"
    hw_csv = results_dir / "v2_hw_raw_adc.csv"

    if not sim_csv.exists() or not hw_csv.exists():
        print("\n  [NOTE] Sim and/or hardware CSV not found.")
        print(f"  Expected: {sim_csv}")
        print(f"  Expected: {hw_csv}")
        print("  Please collect sim and hardware data first.")
        print("  Creating mock data for analysis demo...")

        # Create mock CSVs
        import random
        random.seed(42)
        with open(sim_csv, 'w') as f:
            f.write("trial,deviation_m,snr_db\n")
            for i in range(10):
                f.write(f"{i+1},{random.uniform(0.012, 0.015):.5f},{random.uniform(43.5, 44.5):.2f}\n")

        with open(hw_csv, 'w') as f:
            f.write("trial,adc_0,adc_1,adc_2,adc_3\n")
            for i in range(10):
                f.write(f"{i+1},{random.randint(600,650)},{random.randint(600,650)},"
                        f"{random.randint(600,650)},{random.randint(600,650)}\n")

    # Run S2R analysis
    script = SCRIPT_DIR / "exp3_pheromone_s2r" / "scripts" / "v2_s2r_analysis.py"
    cmd = [
        sys.executable, str(script),
        "--sim", str(sim_csv),
        "--hw", str(hw_csv),
        "--output", str(results_dir),
    ]
    result = run_cmd(cmd, "V2-3 S2R Analysis", check=False)
    return result.returncode == 0


def run_exp4() -> bool:
    """V2-4: Fault Tolerance."""
    print("\n" + "=" * 60)
    print("  EXPERIMENT V2-4: FAULT TOLERANCE & RECOVERY")
    print("=" * 60)
    print("  Target: Recovery < 0.5s (V1 was 1.8s)")
    print("  Target: Success >= 73.2% under fault conditions")
    print("  Method: Kill LiDAR node, measure recovery time")
    print("=" * 60)

    results_dir = DATA_ROOT / "exp4_fault_tolerance" / "results"
    results_dir.mkdir(parents=True, exist_ok=True)

    use_ssh = input("\n  Run on TX2 hardware via SSH? (y/n, default: n [simulate]): ")
    if use_ssh.lower() == 'y':
        script = SCRIPT_DIR / "exp4_fault_tolerance" / "scripts" / "v2_fault_runner.py"
        cmd = [
            "ssh", f"unitree@{TX2_IP}",
            f"python3 {script} --trials 30 --fault-type lidar_kill"
        ]
        run_cmd(cmd, "Running V2-4 on TX2", check=False)
    else:
        script = SCRIPT_DIR / "exp4_fault_tolerance" / "scripts" / "v2_fault_runner.py"
        cmd = [
            sys.executable, str(script),
            "--trials", "30",
            "--fault-type", "lidar_kill",
            "--output", str(results_dir),
            "--simulate",
        ]
        print(f"\n  [SIMULATED] Running fault tolerance trials...")
        result = run_cmd(cmd, "V2-4 Fault Tolerance (simulated)", check=False)
        return result.returncode == 0

    return True


def run_exp5() -> bool:
    """V2-5: Thermal Profile."""
    print("\n" + "=" * 60)
    print("  EXPERIMENT V2-5: THERMAL PROFILE (WILDCARD)")
    print("=" * 60)
    print("  Target: CPU < 50°C at equilibrium")
    print("  Target: GPU < 45°C at equilibrium")
    print("  Target: Ambient rise < 5°C")
    print("  Method: tegrastats logging for 30 minutes")
    print("=" * 60)

    results_dir = DATA_ROOT / "exp5_thermal_profile" / "results"
    results_dir.mkdir(parents=True, exist_ok=True)

    use_ssh = input("\n  Run on TX2 hardware via SSH? (y/n, default: n [simulate]): ")
    if use_ssh.lower() == 'y':
        script = SCRIPT_DIR / "exp5_thermal_profile" / "scripts" / "v2_thermal_logger.py"
        cmd = [
            "ssh", f"unitree@{TX2_IP}",
            f"python3 {script} --duration 1800 --interval 2000"
        ]
        run_cmd(cmd, "Running V2-5 on TX2", check=False)
    else:
        script = SCRIPT_DIR / "exp5_thermal_profile" / "scripts" / "v2_thermal_logger.py"
        cmd = [
            sys.executable, str(script),
            "--duration", "60",  # Short for demo
            "--interval", "1000",
            "--output", str(results_dir),
        ]
        print(f"\n  [SIMULATED] Running thermal logger (60s demo)...")
        result = run_cmd(cmd, "V2-5 Thermal Profile (simulated)", check=False)
        return result.returncode == 0

    return True


def run_exp6() -> bool:
    """V2-6: Cross-Platform Algorithm Portability (TurtleBot3)."""
    print("\n" + "=" * 60)
    print("  EXPERIMENT V2-6: CROSS-PLATFORM ALGORITHMIC PORTABILITY")
    print("  (Reviewer 2 Response)")
    print("=" * 60)
    print("  Target: >= 90% success rate on TurtleBot3 Burger")
    print("  Platform: Raspberry Pi 3B+ + LDS-01 laser scanner")
    print("  Algorithm: Identical bio_inspired_nav.launch.py")
    print("=" * 60)

    results_dir = DATA_ROOT / "exp6_cross_platform" / "results"
    results_dir.mkdir(parents=True, exist_ok=True)

    use_ssh = input("\n  Run on TurtleBot3 hardware via SSH? (y/n, default: n [simulate]): ")
    if use_ssh.lower() == 'y':
        script = SCRIPT_DIR / "exp6_cross_platform" / "scripts" / "v2_turtlebot_runner.py"
        cmd = [
            "ssh", "pi@192.168.1.100",
            f"python3 {script} --robot turtlebot3 --trials 20"
        ]
        run_cmd(cmd, "Running V2-6 on TurtleBot3", check=False)
    else:
        script = SCRIPT_DIR / "exp6_cross_platform" / "scripts" / "v2_turtlebot_runner.py"
        cmd = [
            sys.executable, str(script),
            "--robot", "turtlebot3",
            "--trials", "20",
            "--output", str(results_dir),
            "--simulate",
        ]
        print(f"\n  [SIMULATED] Running TurtleBot3 validation...")
        result = run_cmd(cmd, "V2-6 TurtleBot3 (simulated)", check=False)
        return result.returncode == 0

    return True


def run_exp7() -> bool:
    """V2-7: Parameter Stability Analysis (Heat Map)."""
    print("\n" + "=" * 60)
    print("  EXPERIMENT V2-7: PARAMETER STABILITY ANALYSIS")
    print("  (Reviewer 2 Response)")
    print("=" * 60)
    print("  Target: rho = 0.10 in robust plateau (>85% success)")
    print("  Method: 500 Gazebo simulation trials")
    print("  Parameters: rho in [0.05, 0.50], CI in [0.0, 1.0]")
    print("=" * 60)

    results_dir = DATA_ROOT / "exp7_parameter_stability" / "results"
    figures_dir = DATA_ROOT / "exp7_parameter_stability" / "figures"
    results_dir.mkdir(parents=True, exist_ok=True)
    figures_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n  Running evaporation rate sweep...")
    sweep_script = SCRIPT_DIR / "exp7_parameter_stability" / "scripts" / "v2_param_sweep.py"
    cmd_sweep = [
        sys.executable, str(sweep_script),
        "--sweep", "evaporation_rate",
        "--rho-range", "0.05", "0.50", "0.05",
        "--trials-per-config", "20",
        "--output", str(results_dir),
    ]
    run_cmd(cmd_sweep, "V2-7 Parameter Sweep", check=False)

    print(f"\n  Running full 2D heat map sweep...")
    cmd_full = [
        sys.executable, str(sweep_script),
        "--sweep", "full",
        "--rho-range", "0.05", "0.50", "0.10",
        "--ci-range", "0.0", "1.0", "0.25",
        "--trials-per-config", "20",
        "--output", str(results_dir),
    ]
    run_cmd(cmd_full, "V2-7 Full Heat Map", check=False)

    # Find the latest sweep CSV
    sweep_csvs = sorted(results_dir.glob("param_sweep_*.csv"))
    if sweep_csvs:
        heatmap_script = SCRIPT_DIR / "exp7_parameter_stability" / "scripts" / "v2_heatmap_generator.py"
        cmd_heatmap = [
            sys.executable, str(heatmap_script),
            "--input", str(sweep_csvs[-1]),
            "--output", str(figures_dir),
        ]
        run_cmd(cmd_heatmap, "V2-7 Heat Map Generation", check=False)

    return True


def run_exp8() -> bool:
    """V2-8: Multi-Robot Scalability Analysis."""
    print("\n" + "=" * 60)
    print("  EXPERIMENT V2-8: MULTI-ROBOT SCALABILITY ANALYSIS")
    print("  (Reviewer 2 Response)")
    print("=" * 60)
    print("  Target: n=10: Time < 30% of baseline, Reliability > 90%")
    print("  Method: Gazebo swarm simulation (n = 1, 2, 3, 5, 10)")
    print("=" * 60)

    results_dir = DATA_ROOT / "exp8_scalability" / "results"
    results_dir.mkdir(parents=True, exist_ok=True)

    script = SCRIPT_DIR / "exp8_scalability" / "scripts" / "v2_scalability_analysis.py"
    cmd = [
        sys.executable, str(script),
        "--team-sizes", "1", "2", "3", "5", "10",
        "--trials-per-size", "10",
        "--output", str(results_dir),
    ]
    print(f"\n  [SIMULATED] Running swarm scalability (n = 1, 2, 3, 5, 10)...")
    result = run_cmd(cmd, "V2-8 Swarm Scalability (simulated)", check=False)
    return result.returncode == 0


def run_analyse() -> bool:
    """Run analysis on collected data."""
    print("\n" + "=" * 60)
    print("  RUNNING V2 ANALYSIS PIPELINE")
    print("=" * 60)

    analysis_script = SCRIPT_DIR / "analysis" / "v2_consolidated_analysis.py"
    if not analysis_script.exists():
        print(f"  Analysis script not found: {analysis_script}")
        return False

    cmd = [
        sys.executable, str(analysis_script),
        "--data-dir", str(DATA_ROOT),
        "--output", str(V2_ROOT / "figures"),
    ]
    result = run_cmd(cmd, "V2 Consolidated Analysis", check=False)
    return result.returncode == 0


def run_summary() -> bool:
    """Generate the final consolidated summary."""
    print("\n" + "=" * 60)
    print("  GENERATING V2 CONSOLIDATED SUMMARY")
    print("=" * 60)

    summary_script = SCRIPT_DIR / "analysis" / "v2_summary_generator.py"
    if not summary_script.exists():
        print(f"  Summary script not found: {summary_script}")
        return False

    cmd = [
        sys.executable, str(summary_script),
        "--data-dir", str(DATA_ROOT),
        "--output", str(V2_ROOT),
    ]
    result = run_cmd(cmd, "V2 Summary Generator", check=False)
    return result.returncode == 0


def main():
    parser = argparse.ArgumentParser(
        description="V2 Master Runner — Alloingo Engineering Validation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python v2_master.py all         # Run all experiments (V2-1 to V2-8)
    python v2_master.py core         # Core engineering (V2-1 to V2-5)
    python v2_master.py r2           # Reviewer 2 responses (V2-6 to V2-8)
    python v2_master.py check        # Check hardware connectivity
    python v2_master.py exp1        # Power profiling (V2-1)
    python v2_master.py exp2        # Maze navigation (V2-2)
    python v2_master.py exp3        # S2R analysis (V2-3)
    python v2_master.py exp4        # Fault tolerance (V2-4)
    python v2_master.py exp5        # Thermal profile (V2-5)
    python v2_master.py exp6        # Cross-platform TurtleBot3 (V2-6)
    python v2_master.py exp7        # Parameter heat map (V2-7)
    python v2_master.py exp8        # Multi-robot scalability (V2-8)
    python v2_master.py analyse     # Analyze collected data
    python v2_master.py summary     # Generate final summary
        """
    )
    parser.add_argument(
        'command', nargs='?', default='help',
        choices=['all', 'core', 'r2', 'check',
                 'exp1', 'exp2', 'exp3', 'exp4', 'exp5',
                 'exp6', 'exp7', 'exp8',
                 'analyse', 'summary', 'help']
    )
    args = parser.parse_args()

    print("\n" + "=" * 60)
    print("  ALLOINGO V2 — ENGINEERING VALIDATION MASTER RUNNER")
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    if args.command == 'help':
        parser.print_help()
        return

    # Create directories
    RESULTS_ROOT = V2_ROOT / "results"
    for exp in ['exp1_power_profiling', 'exp2_maze_navigation', 'exp3_pheromone_s2r',
                'exp4_fault_tolerance', 'exp5_thermal_profile',
                'exp6_cross_platform', 'exp7_parameter_stability', 'exp8_scalability']:
        (DATA_ROOT / exp / "results").mkdir(parents=True, exist_ok=True)
    RESULTS_ROOT.mkdir(parents=True, exist_ok=True)

    success = True

    if args.command == 'all':
        print("\n  Running ALL V2 experiments in sequence...")
        steps = [
            ('check', "Hardware Connectivity"),
            ('exp1', "Power Profiling"),
            ('exp2', "Maze Navigation"),
            ('exp3', "Pheromone S2R"),
            ('exp4', "Fault Tolerance"),
            ('exp5', "Thermal Profile"),
            ('exp6', "Cross-Platform (TurtleBot3)"),
            ('exp7', "Parameter Heat Map"),
            ('exp8', "Multi-Robot Scalability"),
            ('analyse', "Analysis Pipeline"),
            ('summary', "Final Summary"),
        ]

    elif args.command == 'core':
        steps = [
            ('exp1', "Power Profiling"),
            ('exp2', "Maze Navigation"),
            ('exp3', "Pheromone S2R"),
            ('exp4', "Fault Tolerance"),
            ('exp5', "Thermal Profile"),
            ('analyse', "Analysis Pipeline"),
        ]

    elif args.command == 'r2':
        steps = [
            ('exp6', "Cross-Platform (TurtleBot3)"),
            ('exp7', "Parameter Heat Map"),
            ('exp8', "Multi-Robot Scalability"),
            ('analyse', "Analysis Pipeline"),
        ]

    else:
        steps = []

    for step_cmd, step_name in steps:
        print(f"\n\n{'#'*60}")
        print(f"# STEP: {step_name}")
        print(f"{'#'*60}")
        if step_cmd == 'check':
            check_hardware()
        elif step_cmd == 'exp1':
            run_exp1()
        elif step_cmd == 'exp2':
            run_exp2()
        elif step_cmd == 'exp3':
            run_exp3()
        elif step_cmd == 'exp4':
            run_exp4()
        elif step_cmd == 'exp5':
            run_exp5()
        elif step_cmd == 'exp6':
            run_exp6()
        elif step_cmd == 'exp7':
            run_exp7()
        elif step_cmd == 'exp8':
            run_exp8()
        elif step_cmd == 'analyse':
            run_analyse()
        elif step_cmd == 'summary':
            run_summary()

    if args.command == 'check':
        check_hardware()

    elif args.command == 'exp1':
        run_exp1()

    elif args.command == 'exp2':
        run_exp2()

    elif args.command == 'exp3':
        run_exp3()

    elif args.command == 'exp4':
        run_exp4()

    elif args.command == 'exp5':
        run_exp5()

    elif args.command == 'exp6':
        run_exp6()

    elif args.command == 'exp7':
        run_exp7()

    elif args.command == 'exp8':
        run_exp8()

    elif args.command == 'analyse':
        run_analyse()

    elif args.command == 'summary':
        run_summary()

    print("\n" + "=" * 60)
    print(f"  V2 MASTER RUNNER COMPLETE — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60 + "\n")


if __name__ == '__main__':
    main()
