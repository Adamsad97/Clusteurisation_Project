#!/bin/bash

# Couleurs pour les logs
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables pour le comptage des tests
TOTAL_TESTS=0
FAILED_TESTS=0

# Fonction pour afficher une ligne de séparation
print_separator() {
    echo -e "\n${BLUE}================================================${NC}"
}

# Fonction pour exécuter les tests d'un service backend
run_backend_tests() {
    local service_name=$1
    local service_dir=$2
    
    print_separator
    echo -e "${YELLOW}🔍 Testing ${service_name}${NC}"
    
    cd $service_dir || return 1
    
    if [ ! -f "package.json" ]; then
        echo -e "${RED}❌ No package.json found in ${service_dir}${NC}"
        cd - > /dev/null || return 1
        return 1
    fi

    echo "📦 Installing dependencies..."
    npm install --silent
    
    echo "🧪 Running tests..."
    if NODE_ENV=test NODE_OPTIONS='--experimental-vm-modules' npm test; then
        echo -e "${GREEN}✅ ${service_name} tests passed${NC}"
        cd - > /dev/null || return 1
        return 0
    else
        echo -e "${RED}❌ ${service_name} tests failed${NC}"
        cd - > /dev/null || return 1
        return 1
    fi
}

# Fonction pour exécuter les tests frontend
run_frontend_tests() {
    print_separator
    echo -e "${YELLOW}🔍 Testing Frontend${NC}"
    
    cd frontend || return 1
    
    if [ ! -f "package.json" ]; then
        echo -e "${RED}❌ No package.json found in frontend directory${NC}"
        cd - > /dev/null || return 1
        return 1
    fi

    echo "📦 Installing dependencies..."
    npm install --silent
    
    echo "🧪 Running unit tests..."
    if npm run test:unit; then
        echo -e "${GREEN}✅ Frontend tests passed${NC}"
        cd - > /dev/null || return 1
        return 0
    else
        echo -e "${RED}❌ Frontend tests failed${NC}"
        cd - > /dev/null || return 1
        return 1
    fi
}

# Fonction principale
main() {
    print_separator
    echo -e "${BLUE}🚀 Starting full application test suite${NC}"
    echo -e "${BLUE}📝 This will test all services and the frontend${NC}"
    print_separator

    # Tests des services backend
    run_backend_tests "Auth Service" "services/auth-service"
    if [ $? -ne 0 ]; then
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    run_backend_tests "Product Service" "services/product-service"
    if [ $? -ne 0 ]; then
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    run_backend_tests "Order Service" "services/order-service"
    if [ $? -ne 0 ]; then
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    # Tests frontend
    run_frontend_tests
    if [ $? -ne 0 ]; then
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    # Résumé final
    print_separator
    echo -e "${BLUE}📊 Test Suite Summary${NC}"
    echo -e "Total test suites: ${TOTAL_TESTS}"
    echo -e "Failed test suites: ${FAILED_TESTS}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}✅ All test suites passed successfully!${NC}"
        exit 0
    else
        echo -e "${RED}❌ ${FAILED_TESTS} test suite(s) failed${NC}"
        exit 1
    fi
}

# Exécution du script
main