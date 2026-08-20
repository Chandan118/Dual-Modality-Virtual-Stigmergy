#!/bin/bash
# run_continuous_validation.sh
# Continuous Hardware Validation Loop for FormicaBot V2
# Runs data collection every 5 minutes until manually stopped

WORKSPACE_DIR="/Users/chandansheikder/Documents/Bio-Inspired Thesis/chapter 6 reseach paper/new Simulation"

echo "============================================================"
echo "FormicaBot V2 Hardware Validation - Continuous Loop"
echo "============================================================"
echo "Started: $(date)"
echo "Results directory: $WORKSPACE_DIR/hardware_data"
echo "============================================================"
echo ""
echo "Press Ctrl+C to stop the loop"
echo ""

cd "$WORKSPACE_DIR"

iteration=1
while true; do
    echo ""
    echo "============================================================"
    echo "LOOP ITERATION #$iteration"
    echo "Time: $(date)"
    echo "============================================================"
    
    # Run Python data collection
    python3 HardwareDataCollection.py
    
    # Also run MATLAB if available
    if command -v matlab &> /dev/null; then
        echo ""
        echo "Running MATLAB validation..."
        matlab -batch "RunHardwareValidation"
    fi
    
    iteration=$((iteration + 1))
    echo ""
    echo "============================================================"
    echo "Iteration $((iteration - 1)) complete"
    echo "Next collection in 5 minutes..."
    echo "============================================================"
    
    # Wait 5 minutes (300 seconds)
    sleep 300
done
