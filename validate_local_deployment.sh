#!/bin/bash

# ========================================
# Spring PetClinic 로컬 배포 검증 스크립트
# ========================================
# 용도: docker-compose-local.yml으로 배포된 서비스 검증
# 사용법: ./validate_local_deployment.sh

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 변수
TIMEOUT=300  # 5분
INTERVAL=5   # 5초
TOTAL_CHECKS=$((TIMEOUT / INTERVAL))

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Spring PetClinic 로컬 배포 검증${NC}"
echo -e "${BLUE}========================================${NC}\n"

# ========================================
# 1. Docker 및 Docker Compose 확인
# ========================================
echo -e "${YELLOW}[1/8] Docker 및 Docker Compose 확인 중...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker가 설치되지 않았습니다${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker 설치됨${NC}"

if ! docker ps &> /dev/null; then
    echo -e "${RED}✗ Docker 데몬이 실행 중이 아닙니다${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker 데몬 실행 중${NC}"

if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose가 설치되지 않았습니다${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose 설치됨${NC}\n"

# ========================================
# 2. docker-compose-local.yml 파일 확인
# ========================================
echo -e "${YELLOW}[2/8] docker-compose-local.yml 파일 확인 중...${NC}"
if [ ! -f "docker-compose-local.yml" ]; then
    echo -e "${RED}✗ docker-compose-local.yml 파일을 찾을 수 없습니다${NC}"
    exit 1
fi
echo -e "${GREEN}✓ docker-compose-local.yml 파일 존재${NC}"

# 구문 검증
if ! docker compose -f docker-compose-local.yml config > /dev/null 2>&1; then
    echo -e "${RED}✗ docker-compose-local.yml 구문 오류${NC}"
    docker compose -f docker-compose-local.yml config
    exit 1
fi
echo -e "${GREEN}✓ docker-compose-local.yml 구문 유효${NC}\n"

# ========================================
# 3. 필수 Dockerfile 존재 확인
# ========================================
echo -e "${YELLOW}[3/8] 필수 Dockerfile 확인 중...${NC}"
DOCKERFILES=(
    "spring-petclinic-api-gateway/Dockerfile"
    "spring-petclinic-customers-service/Dockerfile"
    "spring-petclinic-vets-service/Dockerfile"
    "spring-petclinic-visits-service/Dockerfile"
    "spring-petclinic-genai-service/Dockerfile"
)

for dockerfile in "${DOCKERFILES[@]}"; do
    if [ ! -f "$dockerfile" ]; then
        echo -e "${RED}✗ $dockerfile 파일을 찾을 수 없습니다${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ $dockerfile 존재${NC}"
done
echo ""

# ========================================
# 4. 포트 충돌 확인
# ========================================
echo -e "${YELLOW}[4/8] 포트 충돌 확인 중...${NC}"
PORTS=(3306 8080 9090 3000)
for port in "${PORTS[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ 포트 $port가 이미 사용 중입니다${NC}"
        echo -e "${YELLOW}  이전 컨테이너를 중지하시겠습니까? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}기존 컨테이너 중지 중...${NC}"
            docker compose -f docker-compose-local.yml down
        else
            echo -e "${RED}✗ 포트 충돌로 인해 계속할 수 없습니다${NC}"
            exit 1
        fi
    fi
done
echo -e "${GREEN}✓ 포트 사용 가능${NC}\n"

# ========================================
# 5. 서비스 시작
# ========================================
echo -e "${YELLOW}[5/8] 서비스 시작 중...${NC}"
echo -e "${YELLOW}이 과정은 몇 분 소요될 수 있습니다${NC}"
docker compose -f docker-compose-local.yml up -d --build

# 이미지 빌드 확인
echo -e "${YELLOW}이미지 빌드 진행 중... (최대 5분 소요)${NC}"
sleep 30

echo -e "${GREEN}✓ 서비스 시작됨${NC}\n"

# ========================================
# 6. 실행 중인 컨테이너 확인
# ========================================
echo -e "${YELLOW}[6/8] 실행 중인 컨테이너 확인 중...${NC}"
RUNNING_CONTAINERS=$(docker compose -f docker-compose-local.yml ps --services --filter "status=running" | wc -l)
TOTAL_SERVICES=$(docker compose -f docker-compose-local.yml config --services | wc -l)

echo -e "${GREEN}실행 중인 서비스: $RUNNING_CONTAINERS / $TOTAL_SERVICES${NC}"
docker compose -f docker-compose-local.yml ps
echo ""

# ========================================
# 7. 서비스 헬스 체크
# ========================================
echo -e "${YELLOW}[7/8] 서비스 헬스 체크 중... (최대 5분)${NC}"

SERVICES=(
    "mysql:3306"
    "api-gateway:8080"
    "customers-service:8080"
    "vets-service:8080"
    "visits-service:8080"
)

check_service() {
    local service=$1
    local name=${service%:*}
    local port=${service##*:}
    
    if [ "$name" = "mysql" ]; then
        # MySQL 헬스 체크
        for ((i=1; i<=TOTAL_CHECKS; i++)); do
            if docker exec petclinic-mysql mysqladmin ping -u petclinic -ppetclinic -h localhost > /dev/null 2>&1; then
                echo -e "${GREEN}✓ $name 준비 완료${NC}"
                return 0
            fi
            if [ $((i % 6)) -eq 0 ]; then
                echo -ne "${YELLOW}. (${i}/${TOTAL_CHECKS})${NC}\r"
            fi
            sleep $INTERVAL
        done
        echo -e "${RED}✗ $name 헬스 체크 실패${NC}"
        return 1
    else
        # HTTP 헬스 체크
        for ((i=1; i<=TOTAL_CHECKS; i++)); do
            if curl -sf http://localhost:$port/actuator/health > /dev/null 2>&1; then
                echo -e "${GREEN}✓ $name 준비 완료${NC}"
                return 0
            fi
            if [ $((i % 6)) -eq 0 ]; then
                echo -ne "${YELLOW}. (${i}/${TOTAL_CHECKS})${NC}\r"
            fi
            sleep $INTERVAL
        done
        echo -e "${RED}✗ $name 헬스 체크 실패${NC}"
        return 1
    fi
}

all_healthy=true
for service in "${SERVICES[@]}"; do
    if ! check_service "$service"; then
        all_healthy=false
    fi
done

if [ "$all_healthy" = false ]; then
    echo -e "\n${RED}일부 서비스가 준비되지 않았습니다${NC}"
    echo -e "${YELLOW}로그 확인:${NC}"
    docker compose -f docker-compose-local.yml logs --tail=50
    exit 1
fi
echo ""

# ========================================
# 8. 서비스 간 통신 확인
# ========================================
echo -e "${YELLOW}[8/8] 서비스 간 통신 확인 중...${NC}"

# API Gateway를 통한 라우팅 테스트
echo -e "${YELLOW}API Gateway 라우팅 테스트:${NC}"

# 1. Customers API 테스트
if curl -sf http://localhost:8080/api/customer/owners > /dev/null 2>&1; then
    echo -e "${GREEN}✓ /api/customer/owners 라우팅 성공${NC}"
else
    echo -e "${RED}✗ /api/customer/owners 라우팅 실패${NC}"
    all_healthy=false
fi

# 2. Vets API 테스트
if curl -sf http://localhost:8080/api/vet/vets > /dev/null 2>&1; then
    echo -e "${GREEN}✓ /api/vet/vets 라우팅 성공${NC}"
else
    echo -e "${RED}✗ /api/vet/vets 라우팅 실패${NC}"
    all_healthy=false
fi

# 3. Visits API 테스트
if curl -sf http://localhost:8080/api/visit/visits > /dev/null 2>&1; then
    echo -e "${GREEN}✓ /api/visit/visits 라우팅 성공${NC}"
else
    echo -e "${RED}✗ /api/visit/visits 라우팅 실패${NC}"
    all_healthy=false
fi

echo ""

# ========================================
# 최종 결과
# ========================================
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ 모든 검증 통과${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    
    echo -e "${BLUE}접근 가능한 서비스:${NC}"
    echo -e "  - API Gateway: ${GREEN}http://localhost:8080${NC}"
    echo -e "    - Customers: http://localhost:8080/api/customer/owners"
    echo -e "    - Vets: http://localhost:8080/api/vet/vets"
    echo -e "    - Visits: http://localhost:8080/api/visit/visits"
    echo -e "  - Prometheus: ${GREEN}http://localhost:9090${NC}"
    echo -e "  - Grafana: ${GREEN}http://localhost:3000${NC} (admin/admin)"
    echo -e "  - MySQL: ${GREEN}localhost:3306${NC} (petclinic/petclinic)"
    echo ""
    
    echo -e "${BLUE}유용한 명령:${NC}"
    echo -e "  로그 확인: docker compose -f docker-compose-local.yml logs -f"
    echo -e "  서비스 중지: docker compose -f docker-compose-local.yml down"
    echo -e "  서비스 상태: docker compose -f docker-compose-local.yml ps"
    echo ""
    
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ 검증 실패${NC}"
    echo -e "${RED}========================================${NC}\n"
    
    echo -e "${YELLOW}문제 해결:${NC}"
    echo -e "  1. 로그 확인:"
    echo -e "     docker compose -f docker-compose-local.yml logs -f"
    echo -e "  2. 컨테이너 상태 확인:"
    echo -e "     docker compose -f docker-compose-local.yml ps"
    echo -e "  3. 서비스 재시작:"
    echo -e "     docker compose -f docker-compose-local.yml restart"
    echo -e "  4. 완전 초기화:"
    echo -e "     docker compose -f docker-compose-local.yml down -v"
    echo ""
    
    exit 1
fi
