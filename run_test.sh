#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SERVER_IP="172.17.0.2"  # Default Docker bridge network IP
TEST_DURATION=30
PARALLEL_STREAMS=4
JSON_OUTPUT="iperf_results.json"

# Function to start iperf3 server
start_server() {
    echo "Starting iperf3 server..."
    docker run -d --rm \
        --name=iperf3-server \
        -p 5201:5201 \
        networkstatic/iperf3 -s
    
    # Wait for server to start
    sleep 2
    
    # Get server IP
    SERVER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' iperf3-server)
    echo "Server IP: $SERVER_IP"
}

# Function to run iperf3 client tests
run_client_tests() {
    local server_ip=$1
    
    echo "Running iperf3 client tests..."
    
    # TCP test
    echo "Running TCP test..."
    docker run --rm \
        --name=iperf3-client \
        networkstatic/iperf3 \
        -c $server_ip \
        -t $TEST_DURATION \
        -P $PARALLEL_STREAMS \
        -J > "${JSON_OUTPUT}.tcp"
    
    # UDP test
    echo "Running UDP test..."
    docker run --rm \
        --name=iperf3-client \
        networkstatic/iperf3 \
        -c $server_ip \
        -u \
        -b 0 \
        -t $TEST_DURATION \
        -P $PARALLEL_STREAMS \
        -J > "${JSON_OUTPUT}.udp"
}

# Function to parse and display results
parse_results() {
    echo -e "\nTest Results:"
    echo "=============="
    
    # Parse TCP results
    echo "TCP Test:"
    cat "${JSON_OUTPUT}.tcp" | jq '.end.sum_received.bits_per_second/1000000000' | \
        xargs printf "Throughput: %.2f Gbps\n"
    
    # Parse UDP results
    echo -e "\nUDP Test:"
    cat "${JSON_OUTPUT}.udp" | jq '.end.sum.bits_per_second/1000000000' | \
        xargs printf "Throughput: %.2f Gbps\n"
}

# Main execution
main() {
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Docker is not running${NC}"
        exit 1
    fi
    
    # Start server
    start_server
    
    # Wait for server to be ready
    sleep 2
    
    # Run tests
    run_client_tests $SERVER_IP
    
    # Parse results
    parse_results
    
    # Cleanup
    docker stop iperf3-server >/dev/null 2>&1
    
    echo -e "${GREEN}Tests completed${NC}"
}

# Run main function
main
