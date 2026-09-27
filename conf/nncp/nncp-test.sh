#!/bin/bash
# Test NNCP connectivity between two stations
#
# Usage:
#   Remote test (run on calling station):
#     ./nncp-test.sh call <peer_name>
#
#   Remote test (run on receiving station):
#     ./nncp-test.sh listen [bind_addr]
#
# Example:
#   On estacao3: ./nncp-test.sh listen
#   On estacao2: ./nncp-test.sh call estacao3

set -e

MODE=$1

case "$MODE" in
    listen)
        BIND_ADDR=${2:-"0.0.0.0:5400"}
        echo "Starting NNCP daemon on ${BIND_ADDR}..."
        echo "Press Ctrl-C to stop."
        nncp-daemon -bind "$BIND_ADDR" -debug -autotoss
        ;;

    call)
        PEER=$2
        if [ -z "$PEER" ]; then
            echo "Usage: $0 call <peer_name>"
            exit 1
        fi

        # Create test file
        echo "Hello from $(hostname) at $(date)" > /tmp/nncp-testfile.txt

        echo "Queuing test file to ${PEER}..."
        nncp-file /tmp/nncp-testfile.txt "${PEER}:"

        echo "Queue status:"
        nncp-stat

        echo "Calling ${PEER}..."
        nncp-call "${PEER}" -debug

        echo "Done. Check received files on ${PEER} with: nncp-toss -node <this_station>"
        rm -f /tmp/nncp-testfile.txt
        ;;

    *)
        echo "NNCP connectivity test"
        echo ""
        echo "Usage:"
        echo "  $0 listen [bind_addr]     - Start daemon (default 0.0.0.0:5400)"
        echo "  $0 call <peer_name>       - Queue test file and call peer"
        exit 1
        ;;
esac
