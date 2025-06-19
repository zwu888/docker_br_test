#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test configuration
SERVER_IP="172.17.0.2"  # Default Docker bridge network IP
TEST_DURATION=30
PARALLEL_STREAMS=4
INTERVAL=1

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed${NC}"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Docker daemon is not running${NC}"
        exit 1
    fi
}

# Function to start iperf3 server
start_server() {
    echo -e "${BLUE}Starting iperf3 server...${NC}"
    
    # Stop any existing iperf3 server
    docker stop iperf3-server >/dev/null 2>&1
    
    # Start new server
    docker run -d --rm \
        --name=iperf3-server \
        -p 5201:5201 \
        networkstatic/iperf3 -s
    
    # Wait for server to start
    sleep 2
    
    # Get and verify server IP
    SERVER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' iperf3-server)
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}Failed to get server IP${NC}"
        exit 1
    fi
    echo -e "${GREEN}Server started at IP: $SERVER_IP${NC}"
}

# Function to run TCP test
run_tcp_test() {
    echo -e "\n${BLUE}Running TCP test...${NC}"
    docker run --rm \
        --name=iperf3-client-tcp \
        networkstatic/iperf3 \
        -c $SERVER_IP \
        -t $TEST_DURATION \
        -P $PARALLEL_STREAMS \
        -i $INTERVAL
}

# Function to run UDP test
run_udp_test() {
    echo -e "\n${BLUE}Running UDP test...${NC}"
    docker run --rm \
        --name=iperf3-client-udp \
        networkstatic/iperf3 \
        -c $SERVER_IP \
        -u \
        -b 0 \
        -t $TEST_DURATION \
        -P $PARALLEL_STREAMS \
        -i $INTERVAL
}

# Function to run bidirectional test
run_bidirectional_test() {
    echo -e "\n${BLUE}Running bidirectional test...${NC}"
    docker run --rm \
        --name=iperf3-client-bidir \
        networkstatic/iperf3 \
        -c $SERVER_IP \
        -d \
        -t $TEST_DURATION \
        -P $PARALLEL_STREAMS \
        -i $INTERVAL
}

# Function to display network interface statistics
show_interface_stats() {
    echo -e "\n${BLUE}Network Interface Statistics:${NC}"
    docker exec iperf3-server ip -s link
}

# Function to cleanup
cleanup() {
    echo -e "\n${BLUE}Cleaning up...${NC}"
    docker stop iperf3-server >/dev/null 2>&1
    docker rm -f iperf3-client-tcp iperf3-client-udp iperf3-client-bidir >/dev/null 2>&1
}

# Main execution
main() {
    # Setup trap for cleanup on script exit
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites
    
    # Start server
    start_server
    
    # Run tests
    echo -e "\n${GREEN}Starting performance tests...${NC}"
    
    # TCP test
    run_tcp_test
    
    # Short pause between tests
    sleep 2
    
    # UDP test
    run_udp_test
    
    # Short pause between tests
    sleep 2
    
    # Bidirectional test
    run_bidirectional_test
    
    # Show interface statistics
    show_interface_stats
    
    echo -e "\n${GREEN}Tests completed successfully${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--duration)
            TEST_DURATION="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL_STREAMS="$2"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -s|--server)
            SERVER_IP="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-d duration] [-p parallel_streams] [-i interval] [-s server_ip]"
            echo "  -d, --duration       Test duration in seconds (default: 30)"
            echo "  -p, --parallel       Number of parallel streams (default: 4)"
            echo "  -i, --interval       Statistics interval in seconds (default: 1)"
            echo "  -s, --server         Server IP address (default: auto-detect)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main
