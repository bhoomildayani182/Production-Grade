#!/bin/bash

# Docker Swarm Deployment Testing Script
# This script validates the deployment and runs comprehensive tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test infrastructure connectivity
test_infrastructure() {
    log "Testing infrastructure connectivity..."
    
    # Get outputs from Terraform
    if ! MANAGER_IP=$(terraform output -raw swarm_manager_public_ip 2>/dev/null); then
        fail "Cannot get manager IP from Terraform outputs"
        return 1
    fi
    
    if ! LOAD_BALANCER_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null); then
        fail "Cannot get load balancer DNS from Terraform outputs"
        return 1
    fi
    
    success "Retrieved Terraform outputs"
    
    # Test SSH connectivity to manager
    if ssh -i docker-swarm-key.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$MANAGER_IP "echo 'SSH connection successful'" >/dev/null 2>&1; then
        success "SSH connection to manager node"
    else
        fail "SSH connection to manager node"
    fi
    
    # Test load balancer DNS resolution
    if nslookup $LOAD_BALANCER_DNS >/dev/null 2>&1; then
        success "Load balancer DNS resolution"
    else
        fail "Load balancer DNS resolution"
    fi
}

# Test Docker Swarm cluster
test_swarm_cluster() {
    log "Testing Docker Swarm cluster..."
    
    # Check Swarm status
    SWARM_STATUS=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker info --format '{{.Swarm.LocalNodeState}}'" 2>/dev/null || echo "error")
    
    if [ "$SWARM_STATUS" = "active" ]; then
        success "Docker Swarm is active"
    else
        fail "Docker Swarm is not active (status: $SWARM_STATUS)"
    fi
    
    # Check node count
    NODE_COUNT=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker node ls --format '{{.ID}}' | wc -l" 2>/dev/null || echo "0")
    
    if [ "$NODE_COUNT" -ge "3" ]; then
        success "Expected number of nodes in cluster ($NODE_COUNT)"
    else
        fail "Insufficient nodes in cluster (found: $NODE_COUNT, expected: ≥3)"
    fi
    
    # Check manager nodes
    MANAGER_COUNT=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker node ls --filter role=manager --format '{{.ID}}' | wc -l" 2>/dev/null || echo "0")
    
    if [ "$MANAGER_COUNT" -ge "1" ]; then
        success "Manager nodes available ($MANAGER_COUNT)"
    else
        fail "No manager nodes found"
    fi
    
    # Check worker nodes
    WORKER_COUNT=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker node ls --filter role=worker --format '{{.ID}}' | wc -l" 2>/dev/null || echo "0")
    
    if [ "$WORKER_COUNT" -ge "2" ]; then
        success "Worker nodes available ($WORKER_COUNT)"
    else
        fail "Insufficient worker nodes (found: $WORKER_COUNT, expected: ≥2)"
    fi
}

# Test application deployment
test_application_deployment() {
    log "Testing application deployment..."
    
    # Check if stack is deployed
    STACK_SERVICES=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker stack services swarm-app --format '{{.Name}}' 2>/dev/null | wc -l" || echo "0")
    
    if [ "$STACK_SERVICES" -gt "0" ]; then
        success "Docker stack is deployed ($STACK_SERVICES services)"
    else
        fail "Docker stack is not deployed"
        return 1
    fi
    
    # Check service status
    ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker service ls --format 'table {{.Name}}\t{{.Replicas}}\t{{.Image}}'" 2>/dev/null
    
    # Check if all services are running
    RUNNING_SERVICES=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker service ls --filter 'label=com.docker.stack.namespace=swarm-app' --format '{{.Replicas}}' | grep -c '/' || echo '0'" 2>/dev/null)
    
    if [ "$RUNNING_SERVICES" -gt "0" ]; then
        success "Services are running"
    else
        fail "No services are running"
    fi
}

# Test application endpoints
test_application_endpoints() {
    log "Testing application endpoints..."
    
    # Wait for load balancer to be ready
    log "Waiting for load balancer to be ready..."
    sleep 30
    
    # Test main application endpoint
    if curl -f -s -m 10 "http://$LOAD_BALANCER_DNS/" >/dev/null; then
        success "Main application endpoint accessible"
    else
        fail "Main application endpoint not accessible"
    fi
    
    # Test API health endpoint
    if curl -f -s -m 10 "http://$LOAD_BALANCER_DNS/api/health" >/dev/null; then
        success "API health endpoint accessible"
    else
        fail "API health endpoint not accessible"
    fi
    
    # Test API test endpoint
    API_RESPONSE=$(curl -s -m 10 "http://$LOAD_BALANCER_DNS/api/test" 2>/dev/null || echo "")
    if echo "$API_RESPONSE" | grep -q "Docker Swarm Backend API"; then
        success "API test endpoint returns expected response"
    else
        fail "API test endpoint does not return expected response"
    fi
    
    # Test users endpoint
    if curl -f -s -m 10 "http://$LOAD_BALANCER_DNS/api/users" >/dev/null; then
        success "API users endpoint accessible"
    else
        fail "API users endpoint not accessible"
    fi
}

# Test security configuration
test_security() {
    log "Testing security configuration..."
    
    # Check if SSH is properly configured
    SSH_TEST=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "sudo ufw status" 2>/dev/null || echo "inactive")
    if echo "$SSH_TEST" | grep -q "Status: active"; then
        success "UFW firewall is active"
    else
        warning "UFW firewall is not active (relying on security groups)"
    fi
    
    # Check Docker daemon security
    DOCKER_VERSION=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker version --format '{{.Server.Version}}'" 2>/dev/null || echo "unknown")
    if [ "$DOCKER_VERSION" != "unknown" ]; then
        success "Docker daemon is accessible and running version $DOCKER_VERSION"
    else
        fail "Docker daemon is not accessible"
    fi
    
    # Check if non-root user can access Docker
    DOCKER_ACCESS=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker ps >/dev/null 2>&1 && echo 'success' || echo 'fail'")
    if [ "$DOCKER_ACCESS" = "success" ]; then
        success "Non-root user has Docker access"
    else
        fail "Non-root user cannot access Docker"
    fi
}

# Performance tests
test_performance() {
    log "Running basic performance tests..."
    
    # Simple load test with curl
    log "Running concurrent requests test..."
    CONCURRENT_REQUESTS=10
    SUCCESS_COUNT=0
    
    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        if curl -f -s -m 5 "http://$LOAD_BALANCER_DNS/" >/dev/null 2>&1; then
            ((SUCCESS_COUNT++))
        fi &
    done
    
    wait
    
    if [ "$SUCCESS_COUNT" -eq "$CONCURRENT_REQUESTS" ]; then
        success "All concurrent requests succeeded ($SUCCESS_COUNT/$CONCURRENT_REQUESTS)"
    elif [ "$SUCCESS_COUNT" -gt "$((CONCURRENT_REQUESTS / 2))" ]; then
        warning "Most concurrent requests succeeded ($SUCCESS_COUNT/$CONCURRENT_REQUESTS)"
    else
        fail "Many concurrent requests failed ($SUCCESS_COUNT/$CONCURRENT_REQUESTS)"
    fi
    
    # Test response time
    RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "http://$LOAD_BALANCER_DNS/" 2>/dev/null || echo "999")
    RESPONSE_TIME_MS=$(echo "$RESPONSE_TIME * 1000" | bc 2>/dev/null || echo "999")
    
    if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l 2>/dev/null || echo "0") )); then
        success "Response time is acceptable (${RESPONSE_TIME_MS}ms)"
    else
        warning "Response time is slow (${RESPONSE_TIME_MS}ms)"
    fi
}

# Test monitoring and logging
test_monitoring() {
    log "Testing monitoring and logging..."
    
    # Check if logs are being generated
    LOG_COUNT=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "docker service logs swarm-app_backend --tail 10 2>/dev/null | wc -l || echo '0'")
    
    if [ "$LOG_COUNT" -gt "0" ]; then
        success "Application logs are being generated"
    else
        fail "No application logs found"
    fi
    
    # Check system logs
    SYSTEM_LOG_COUNT=$(ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP "sudo journalctl -u docker --since '5 minutes ago' --no-pager | wc -l || echo '0'")
    
    if [ "$SYSTEM_LOG_COUNT" -gt "0" ]; then
        success "System logs are being generated"
    else
        warning "Limited system log activity"
    fi
}

# Generate test report
generate_report() {
    log "Generating test report..."
    
    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
    SUCCESS_RATE=$(echo "scale=2; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc 2>/dev/null || echo "0")
    
    echo
    echo "=================================="
    echo "       TEST REPORT SUMMARY        "
    echo "=================================="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Success Rate: ${SUCCESS_RATE}%"
    echo
    
    if [ "$TESTS_FAILED" -eq "0" ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED! Deployment is successful.${NC}"
        echo
        echo "Your Docker Swarm cluster is ready for use:"
        echo "- Application URL: http://$LOAD_BALANCER_DNS"
        echo "- Manager SSH: ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP"
        echo "- Traefik Dashboard: http://$MANAGER_IP:8080"
        return 0
    else
        echo -e "${RED}❌ Some tests failed. Please review the issues above.${NC}"
        echo
        echo "Common troubleshooting steps:"
        echo "1. Check security group rules"
        echo "2. Verify Docker Swarm status: ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP 'docker node ls'"
        echo "3. Check service logs: ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP 'docker service logs <service-name>'"
        echo "4. Verify load balancer health checks in AWS console"
        return 1
    fi
}

# Main test function
main() {
    log "Starting comprehensive deployment tests..."
    echo
    
    # Check prerequisites
    if [ ! -f "docker-swarm-key.pem" ]; then
        fail "SSH key file not found. Please run deployment first."
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        fail "Terraform not found. Please install Terraform."
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        fail "curl not found. Please install curl."
        exit 1
    fi
    
    # Run test suites
    test_infrastructure
    test_swarm_cluster
    test_application_deployment
    test_application_endpoints
    test_security
    test_performance
    test_monitoring
    
    # Generate final report
    generate_report
}

# Run main function
main "$@"
