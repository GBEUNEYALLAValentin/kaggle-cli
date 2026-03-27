#!/bin/bash

set -e

echo "===================================================="
echo "    Kaggle Benchmarks CLI - Complete QA Bug Bash    "
echo "===================================================="

if ! command -v hatch &> /dev/null; then
    echo "Warning: hatch could not be found in PATH. You may need to run this script in an active uv/python environment."
fi

KAGGLE_USER=$(hatch run kaggle config view 2>/dev/null | grep 'username' | awk -F': ' '{print $2}' | tr -d " '")
if [ -z "$KAGGLE_USER" ]; then
    KAGGLE_USER="limakaggle"
fi

TEMPLATE_SLUG="limakaggle/test-benchmark-cli"
NEW_SLUG="${KAGGLE_USER}/cli-bugbash-run-$(date +%s)"
TEST_DIR="bugbash_test_ws"
mkdir -p $TEST_DIR

echo "Target Template: $TEMPLATE_SLUG"
echo "Target New Slug: $NEW_SLUG"
echo ""

# ----------------------------------------------------
# PULL PARAMETER COVERAGE
# ----------------------------------------------------
echo ">>> [PULL] 1. Implicit Directory Pull"
echo "$ hatch run kaggle benchmarks tasks pull $TEMPLATE_SLUG"
mkdir -p bugbash_implicit_pull && cd bugbash_implicit_pull
hatch run kaggle benchmarks tasks pull $TEMPLATE_SLUG
echo ""
ls -la
cd ..
echo "[CHECK/EXPECTATION]: Without a -p flag, Kaggle CLI falls back to its default mapping."
echo "If you didn't have a 'path' mapped in kaggle.json, you should see it downloaded directly into"
echo "your active terminal directory exactly as you see in the 'ls' list above!"
read -p "Press Enter to continue..."
echo ""

echo ">>> [PULL] 2. Explicit Local Path (-p path)"
echo "$ hatch run kaggle benchmarks tasks pull $TEMPLATE_SLUG -p $TEST_DIR"
hatch run kaggle benchmarks tasks pull $TEMPLATE_SLUG -p $TEST_DIR
echo ""
echo "[CHECK/EXPECTATION]: Now explicitly targeting the -p flag!"
echo "Verify this folder output below. It should contain EXACTLY the contents of the benchmark:"
ls -la $TEST_DIR
echo ""
echo "[CHECK/EXPECTATION]: Open '$TEST_DIR/benchmark.py'. Notice it is purely Python code with NO bulky # --- Jupytext metadata headers!"
read -p "Press Enter to continue..."
echo ""

# ----------------------------------------------------
# RUN (PUSHING) PARAMETER COVERAGE
# ----------------------------------------------------
echo ">>> [RUN] 3. 'Fork' Run with Explicit Slug"
echo "$ hatch run kaggle benchmarks tasks run $NEW_SLUG -p $TEST_DIR"
hatch run kaggle benchmarks tasks run $NEW_SLUG -p $TEST_DIR
echo ""
echo "[CHECK/EXPECTATION]: Look closely at the Tracking URL printed just above!"
echo "Did it securely override the metadata completely and push to https://kaggle.com/.../$NEW_SLUG?"
read -p "Press Enter to continue..."
echo ""

echo ">>> [RUN] 4. Standard Update (No slug, implicit from metadata)"
echo "$ hatch run kaggle benchmarks tasks run -p $TEST_DIR"
sleep 1
hatch run kaggle benchmarks tasks run -p $TEST_DIR
echo ""
echo "[CHECK/EXPECTATION]: We did NOT pass a slug this time! It should implicitly parse '$TEST_DIR/kernel-metadata.json'."
echo "The new Tracking URL printed above should MATCH your $NEW_SLUG exactly, proving it safely maps to the existing notebook."
read -p "Press Enter to continue..."
echo ""

echo ">>> [RUN] 5. Explicit Custom File Target (-f file)"
mv $TEST_DIR/benchmark.py $TEST_DIR/my_custom_run.py
echo "$ hatch run kaggle benchmarks tasks run -p $TEST_DIR -f my_custom_run.py"
hatch run kaggle benchmarks tasks run -p $TEST_DIR -f my_custom_run.py
echo ""
echo "[CHECK/EXPECTATION]: We renamed the local file! Did the CLI successfully read 'my_custom_run.py' and push it without complaining it couldn't find benchmark.py?"
read -p "Press Enter to continue..."
echo ""

# ----------------------------------------------------
# RESULTS (POLLING) PARAMETER COVERAGE
# ----------------------------------------------------
echo ">>> [RESULTS] 6. Timeout Exhaustion Test (--timeout)"
echo "We force a tiny 5 second timeout to ensure the process gracefully bails out during polling limits."
echo "$ hatch run kaggle benchmarks tasks results $NEW_SLUG -p $TEST_DIR --poll-interval 10 --timeout 5 || true"
hatch run kaggle benchmarks tasks results $NEW_SLUG -p $TEST_DIR --poll-interval 10 --timeout 5 || echo "Timeout cleanly aborted!"
echo ""
echo "[CHECK/EXPECTATION]: Since 5 seconds isn't enough to run a benchmark, it should have printed an explicit Timeout Error and exited cleanly!"
read -p "Press Enter to continue..."
echo ""

echo ">>> [RESULTS] 7. Standard Poll + Redirect Artifact Output Path (-p path)"
echo "We poll using the custom slug using 15s intervals!"
echo "$ hatch run kaggle benchmarks tasks results $NEW_SLUG -p $TEST_DIR"
hatch run kaggle benchmarks tasks results $NEW_SLUG -p $TEST_DIR --poll-interval 15
echo ""
echo "[CHECK/EXPECTATION]: The polling should finally succeed!"
echo "Look closely at the 'Output file downloaded to...' text above."
echo "Every single file (.json, .html, .log) should expressly say it downloaded directly into the '$TEST_DIR/' map!"
ls -la $TEST_DIR
read -p "Press Enter to continue..."
echo ""

echo ">>> [RESULTS] 8. Implicit Poll (No Slug)"
echo "Finally, we CD directly into $TEST_DIR and rely purely on 'kernel-metadata.json'!"
echo "$ cd $TEST_DIR && hatch run kaggle benchmarks tasks results"
cd $TEST_DIR
sleep 1
hatch run kaggle benchmarks tasks results
cd ..
echo ""
echo "[CHECK/EXPECTATION]: Since you pushed minutes ago, the poll should instantly return 'Benchmark $NEW_SLUG completed' without needing you to pass the ID via the command line!"
read -p "Press Enter to conclude..."
echo ""

echo "===================================================="
echo "               WORKSPACE CLEANUP                    "
echo "===================================================="
echo "Cleaning up all generated bugbash test folders..."
rm -rf $TEST_DIR
rm -rf bugbash_implicit_pull
echo "Cleanup completed successfully!"
echo ""
echo "===================================================="
echo "          COMPREHENSIVE QA BUG BASH COMPLETE        "
echo "===================================================="
