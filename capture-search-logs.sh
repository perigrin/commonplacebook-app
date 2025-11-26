#!/bin/bash
# ABOUTME: Captures console logs from Commonplace Book app for search debugging
# ABOUTME: Filters for search-related debug output and saves to timestamped file

set -e

# Output file with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/commonplace-search-debug-${TIMESTAMP}.log"

echo "=================================================="
echo "Commonplace Book Search Debug Log Capture"
echo "=================================================="
echo ""
echo "Log file: ${LOG_FILE}"
echo ""
echo "Instructions:"
echo "1. This script is now capturing console output"
echo "2. Go to the Commonplace Book app window"
echo "3. Create a note if you don't have any"
echo "4. Type in the search bar at the bottom"
echo "5. Watch for search results or debug output"
echo "6. Press Ctrl+C when done to stop logging"
echo ""
echo "Waiting for logs... (Press Ctrl+C to stop)"
echo "=================================================="
echo ""

# Capture logs with filters for our debug markers
log stream \
    --predicate 'process == "Commonplace Book"' \
    --level debug \
    --style compact \
    2>&1 | tee "${LOG_FILE}" | grep --line-buffered -E "(🔍|🎯|📥|🔔|❌|✓|✗|EnhancedNoteListView|SearchViewModel|handleQueryChange|VectorSearchEngine|search\(|results|Index contains)" || true

echo ""
echo "=================================================="
echo "Logging stopped."
echo "Full logs saved to: ${LOG_FILE}"
echo ""
echo "Showing search-related logs:"
echo "=================================================="
grep -E "(🔍|🎯|📥|🔔)" "${LOG_FILE}" || echo "No search debug logs found. App may need to be interacted with."
echo ""
echo "To view full logs: cat ${LOG_FILE}"
