#!/bin/bash
# quickstart.sh — FormicaBot Chapter 6 v1 Experiment Pipeline
#
# Usage:
#   cd ~/formica_experiments/data/v1
#   bash quickstart.sh              # Run full pipeline
#   bash quickstart.sh check        # Hardware check only
#   bash quickstart.sh exp1         # Run single experiment
#   bash quickstart.sh copy         # Copy results to v1
#   bash quickstart.sh analyse      # Run analysis only
#

set -e

V1_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMICA_DIR="$HOME/formica_experiments"
DATA_DIR="$FORMICA_DIR/data"

echo "========================================"
echo "  FormicaBot Chapter 6 v1 Quickstart"
echo "========================================"
echo "  V1_DIR: $V1_DIR"
echo "  DATA_DIR: $DATA_DIR"
echo "========================================"

STEP="${1:-all}"

run_check() {
    echo ""
    echo "[STEP] Hardware Check"
    echo "------------------------------"
    if [ -f "$FORMICA_DIR/scripts/chapter6_experiment_runner.sh" ]; then
        bash "$FORMICA_DIR/scripts/chapter6_experiment_runner.sh" check
    else
        echo "Runner script not found. Run manually:"
        echo "  ros2 topic list"
        echo "  ros2 doctor"
    fi
}

run_exp() {
    local exp="$1"
    echo ""
    echo "[STEP] Running Experiment $exp"
    echo "------------------------------"
    if [ -f "$FORMICA_DIR/scripts/chapter6_experiment_runner.sh" ]; then
        bash "$FORMICA_DIR/scripts/chapter6_experiment_runner.sh" "$exp"
    else
        echo "Runner script not found. Run manually:"
        echo "  cd $FORMICA_DIR"
        echo "  source /opt/ros/humble/setup.bash"
        echo "  source install/setup.bash"
        echo "  ros2 run formica_experiments exp${exp}_..."
    fi
}

copy_results() {
    echo ""
    echo "[STEP] Copying Results to v1/"
    echo "------------------------------"
    for exp_dir in "$V1_DIR"/exp*; do
        if [ -d "$exp_dir" ]; then
            mkdir -p "$exp_dir/results"
        fi
    done

    # Copy latest CSVs
    cp_cmd="python3 $V1_DIR/analysis/v1_runner.py --v1-dir $V1_DIR --step copy_results"
    python3 "$V1_DIR/analysis/v1_runner.py" --v1-dir "$V1_DIR" --step copy_results || true
}

run_postprocess() {
    echo ""
    echo "[STEP] Post-Processing"
    echo "------------------------------"
    python3 "$V1_DIR/analysis/v1_runner.py" --v1-dir "$V1_DIR" --step postprocess || true
}

run_analysis() {
    echo ""
    echo "[STEP] Analysis"
    echo "------------------------------"
    python3 "$V1_DIR/analysis/v1_runner.py" --v1-dir "$V1_DIR" --step analyse || true
}

case "$STEP" in
    check)
        run_check
        ;;
    copy)
        copy_results
        ;;
    postprocess)
        run_postprocess
        ;;
    analyse)
        run_analysis
        ;;
    exp1|exp2|exp3|exp4|exp5|exp6|exp7)
        run_exp "$STEP"
        ;;
    all)
        run_check
        for exp in exp1 exp2 exp3 exp4 exp5 exp6 exp7; do
            run_exp "$exp"
            sleep 2
        done
        copy_results
        run_postprocess
        run_analysis
        ;;
    *)
        echo "Usage: $0 [check|exp1|exp2|...|exp7|copy|postprocess|analyse|all]"
        echo ""
        echo "Steps:"
        echo "  check      - Check hardware connectivity"
        echo "  exp1-exp7 - Run single experiment"
        echo "  copy       - Copy CSVs to v1/"
        echo "  postprocess- Run exp2/exp7 post-processing"
        echo "  analyse    - Generate thesis tables and gap analysis"
        echo "  all        - Run full pipeline (default)"
        exit 1
        ;;
esac

echo ""
echo "========================================"
echo "  Done! Results in: $V1_DIR"
echo "========================================"
