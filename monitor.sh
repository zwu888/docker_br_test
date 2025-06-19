#!/bin/bash

# Monitor iperf3 tests
monitor_test() {
    local container=$1
    
    echo "Monitoring $container..."
    
    while docker ps --format '{{.Names}}' | grep -q "$container"; do
        echo "Container Stats:"
        docker stats --no-stream $container
        
        echo "Network Stats:"
        docker exec $container netstat -s | grep -E "segments|packets"
        
        sleep 1
    done
}

# Start monitoring
monitor_test "iperf3-server"
