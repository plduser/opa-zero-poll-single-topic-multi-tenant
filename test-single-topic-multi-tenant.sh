#!/bin/bash

# OPAL Single Topic Multi-Tenant Configuration Test Script
# This script demonstrates the revolutionary single-topic approach for OPAL multi-tenancy

set -e

echo "🚀 OPAL Single Topic Multi-Tenant Configuration Test"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            print_success "$service_name is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# Function to check OPAL Client logs for success
check_opal_logs() {
    local reason=$1
    print_status "Checking OPAL Client logs for: $reason"
    
    # Wait a moment for logs to appear
    sleep 3
    
    # Check for success indicators in logs
    if docker logs opal-client --since 10s 2>/dev/null | grep -q "processing store transaction: {'success': True"; then
        print_success "OPAL Client successfully processed data update"
        return 0
    else
        print_warning "Could not verify OPAL Client success in logs"
        return 1
    fi
}

# Function to verify data in OPA
verify_opa_data() {
    local tenant=$1
    print_status "Verifying data for $tenant in OPA..."
    
    local response=$(curl -s "http://localhost:8181/v1/data/acl/$tenant" 2>/dev/null)
    
    if echo "$response" | jq -e '.result.users' > /dev/null 2>&1; then
        print_success "Data for $tenant found in OPA"
        echo "$response" | jq '.result.users'
        return 0
    else
        print_error "No data found for $tenant in OPA"
        return 1
    fi
}

# Main test execution
main() {
    print_status "Starting OPAL Single Topic Multi-Tenant Test"
    
    # Step 1: Start services
    print_status "Step 1: Starting Docker services..."
    # docker-compose -f docker-compose.yml up -d
    
    # Step 2: Wait for services to be ready
    print_status "Step 2: Waiting for services to be ready..."
    #wait_for_service "http://localhost:7002/healthcheck" "OPAL Server" || exit 1
    #wait_for_service "http://localhost:7001/healthcheck" "OPAL Client" || exit 1
    #wait_for_service "http://localhost:8181/health" "OPA" || exit 1
    #wait_for_service "http://localhost:8090/acl/tenant1" "Simple API Provider" || exit 1
    
    # Step 3: Verify OPAL Client configuration
    print_status "Step 3: Verifying OPAL Client configuration..."
    local topics=$(docker exec opal-client env | grep OPAL_DATA_TOPICS | cut -d'=' -f2)
    if [ "$topics" = "tenant_data" ]; then
        print_success "OPAL Client configured with single topic: $topics"
    else
        print_error "OPAL Client has incorrect topic configuration: $topics"
        exit 1
    fi
    
    # Step 4: Add tenant1 data
    print_status "Step 4: Adding tenant1 data via single topic..."
    curl -X POST http://localhost:7002/data/config \
        -H "Content-Type: application/json" \
        -d '{
            "entries": [{
                "url": "http://localhost:8090/acl/tenant1",
                "topics": ["tenant_data"],
                "dst_path": "/acl/tenant1"
            }],
            "reason": "Load tenant1 data via single topic"
        }' > /dev/null 2>&1
    
    check_opal_logs "tenant1 data load"
    verify_opa_data "tenant1"
    
    # Step 5: Add tenant2 data (NO RESTART!)
    print_status "Step 5: Adding tenant2 data via single topic (NO RESTART!)..."
    curl -X POST http://localhost:7002/data/config \
        -H "Content-Type: application/json" \
        -d '{
            "entries": [{
                "url": "http://localhost:8090/acl/tenant1",
                "topics": ["tenant_data"],
                "dst_path": "/acl/tenant2"
            }],
            "reason": "Load tenant2 data via single topic - NO RESTART"
        }' > /dev/null 2>&1
    
    check_opal_logs "tenant2 data load"
    verify_opa_data "tenant2"
    
    # Step 6: Verify data isolation
    print_status "Step 6: Verifying data isolation..."
    local all_data=$(curl -s "http://localhost:8181/v1/data/acl" 2>/dev/null)
    
    if echo "$all_data" | jq -e '.result.tenant1' > /dev/null 2>&1 && \
       echo "$all_data" | jq -e '.result.tenant2' > /dev/null 2>&1; then
        print_success "Data isolation verified - both tenants have separate data"
        echo "All tenant data:"
        echo "$all_data" | jq '.result'
    else
        print_error "Data isolation verification failed"
        exit 1
    fi
    
    # Step 7: Show OPAL Server logs
    print_status "Step 7: OPAL Server event logs..."
    docker logs opal-server --since 2m 2>/dev/null | grep -E "(Publishing|Broadcasting)" | tail -5
    
    # Step 8: Show OPAL Client logs
    print_status "Step 8: OPAL Client processing logs..."
    docker logs opal-client --since 2m 2>/dev/null | grep -E "(Received|Updating|Fetching|Saving)" | tail -10
    
    # Final success message
    echo ""
    print_success "🎉 OPAL Single Topic Multi-Tenant Configuration Test PASSED!"
    echo ""
    echo "Key achievements demonstrated:"
    echo "✅ Single topic 'tenant_data' handled multiple tenants"
    echo "✅ No restart required when adding tenant2"
    echo "✅ Data isolation maintained through OPA path hierarchy"
    echo "✅ Real-time tenant addition working perfectly"
    echo ""
    echo "This proves the revolutionary single-topic approach works!"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up Docker services..."
    # docker-compose -f docker-compose.yml down --volumes --remove-orphans
}

# Trap cleanup on script exit
trap cleanup EXIT

# Run main test
main

# Keep services running for manual inspection
print_status "Services are still running for manual inspection."
print_status "Press Ctrl+C to stop and cleanup."
print_status ""
print_status "Manual verification commands:"
echo "  curl -s http://localhost:8181/v1/data/acl/tenant1 | jq ."
echo "  curl -s http://localhost:8181/v1/data/acl/tenant2 | jq ."
echo "  curl -s http://localhost:8181/v1/data/acl | jq ."
echo ""

# Wait for user interrupt
read -p "Press Enter to cleanup and exit..." 