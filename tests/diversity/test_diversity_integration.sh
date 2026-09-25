#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Files2Tuebingen Diversity Integration Test ==="
echo ""

# Test R wrapper
echo "Testing R diversity wrapper..."
mkdir -p /tmp/diversity_test

# Determine which Rscript to use (conda r-diversity env or system R)
if [ -f "/home/ubuntu/miniconda3/envs/r-diversity/bin/Rscript" ]; then
    RSCRIPT="/home/ubuntu/miniconda3/envs/r-diversity/bin/Rscript"
    export PATH="/home/ubuntu/miniconda3/bin:$PATH"
    export LD_LIBRARY_PATH="/home/ubuntu/miniconda3/envs/r-diversity/lib:$LD_LIBRARY_PATH"
else
    RSCRIPT="Rscript"
fi

"$RSCRIPT" "$PIPELINE_DIR/modules/local/diversity_analysis/diversity_analysis.R" \
  --matrixCSV="$SCRIPT_DIR/matrix.csv" \
  --samplesheet="$SCRIPT_DIR/input_diversity.csv" \
  --demoInfo="$SCRIPT_DIR/demo_info.csv" \
  --outdir=/tmp/diversity_test \
  --numCores=1

# Verify outputs
OUTPUTS=$(find /tmp/diversity_test -type f \( -name "*.RData" -o -name "*.csv" -o -name "*.pdf" \) 2>/dev/null | wc -l)
echo "Output files generated: $OUTPUTS"

if [ "$OUTPUTS" -gt 0 ]; then
  echo "✅ R wrapper test PASSED"
  find /tmp/diversity_test -type f \( -name "*.RData" -o -name "*.csv" -o -name "*.pdf" \) | sort
else
  echo "❌ R wrapper test FAILED - no output files"
  exit 1
fi

echo ""
echo "=== All tests passed ==="