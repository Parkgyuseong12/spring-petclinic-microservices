# ========================================
# Spring PetClinic 로컬 배포 검증 스크립트 (Windows PowerShell)
# ========================================
# 용도: docker-compose-local.yml으로 배포된 서비스 검증
# 사용법: .\validate_local_deployment.ps1

param(
    [switch]$SkipBuild = $false,
    [switch]$Verbose = $false
)

# 색상 정의
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$BLUE = "Blue"

# 변수
$TIMEOUT = 300  # 5분
$INTERVAL = 5   # 5초
$TOTAL_CHECKS = $TIMEOUT / $INTERVAL

Write-Host "========================================" -ForegroundColor $BLUE
Write-Host "Spring PetClinic 로컬 배포 검증" -ForegroundColor $BLUE
Write-Host "========================================" -ForegroundColor $BLUE
Write-Host ""

# ========================================
# 1. Docker 및 Docker Desktop 확인
# ========================================
Write-Host "[1/8] Docker 및 Docker Desktop 확인 중..." -ForegroundColor $YELLOW

try {
    $dockerVersion = docker --version
    Write-Host "✓ Docker 설치됨: $dockerVersion" -ForegroundColor $GREEN
} catch {
    Write-Host "✗ Docker가 설치되지 않았거나 실행할 수 없습니다" -ForegroundColor $RED
    Write-Host "   Docker Desktop을 설치하고 실행하세요" -ForegroundColor $YELLOW
    exit 1
}

try {
    docker ps 2>&1 | Out-Null
    Write-Host "✓ Docker 데몬 실행 중" -ForegroundColor $GREEN
} catch {
    Write-Host "✗ Docker 데몬이 실행 중이 아닙니다" -ForegroundColor $RED
    Write-Host "   Docker Desktop을 시작하세요" -ForegroundColor $YELLOW
    exit 1
}

try {
    docker compose version 2>&1 | Out-Null
    Write-Host "✓ Docker Compose 설치됨" -ForegroundColor $GREEN
} catch {
    Write-Host "✗ Docker Compose가 설치되지 않았습니다" -ForegroundColor $RED
    exit 1
}
Write-Host ""

# ========================================
# 2. docker-compose-local.yml 파일 확인
# ========================================
Write-Host "[2/8] docker-compose-local.yml 파일 확인 중..." -ForegroundColor $YELLOW

if (-not (Test-Path "docker-compose-local.yml")) {
    Write-Host "✗ docker-compose-local.yml 파일을 찾을 수 없습니다" -ForegroundColor $RED
    exit 1
}
Write-Host "✓ docker-compose-local.yml 파일 존재" -ForegroundColor $GREEN

# 구문 검증
try {
    docker compose -f docker-compose-local.yml config 2>&1 | Out-Null
    Write-Host "✓ docker-compose-local.yml 구문 유효" -ForegroundColor $GREEN
} catch {
    Write-Host "✗ docker-compose-local.yml 구문 오류" -ForegroundColor $RED
    docker compose -f docker-compose-local.yml config
    exit 1
}
Write-Host ""

# ========================================
# 3. 필수 Dockerfile 존재 확인
# ========================================
Write-Host "[3/8] 필수 Dockerfile 확인 중..." -ForegroundColor $YELLOW

$dockerfiles = @(
    "spring-petclinic-api-gateway/Dockerfile",
    "spring-petclinic-customers-service/Dockerfile",
    "spring-petclinic-vets-service/Dockerfile",
    "spring-petclinic-visits-service/Dockerfile",
    "spring-petclinic-genai-service/Dockerfile"
)

foreach ($dockerfile in $dockerfiles) {
    if (-not (Test-Path $dockerfile)) {
        Write-Host "✗ $dockerfile 파일을 찾을 수 없습니다" -ForegroundColor $RED
        exit 1
    }
    Write-Host "✓ $dockerfile 존재" -ForegroundColor $GREEN
}
Write-Host ""

# ========================================
# 4. 포트 충돌 확인
# ========================================
Write-Host "[4/8] 포트 충돌 확인 중..." -ForegroundColor $YELLOW

$ports = @(3306, 8080, 9090, 3000)
$portConflict = $false

foreach ($port in $ports) {
    try {
        $tcpProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
        $activeTcpListeners = $tcpProperties.GetActiveTcpListeners()
        $portInUse = $activeTcpListeners | Where-Object { $_.Port -eq $port }
        
        if ($null -ne $portInUse) {
            Write-Host "⚠ 포트 $port 가 이미 사용 중입니다" -ForegroundColor $YELLOW
            $portConflict = $true
        }
    } catch {
        # 포트 확인 불가, 계속 진행
    }
}

if ($portConflict) {
    Write-Host "⚠ 포트 충돌이 감지되었습니다" -ForegroundColor $YELLOW
    $response = Read-Host "이전 컨테이너를 중지하시겠습니까? (y/n)"
    if ($response -eq "y" -or $response -eq "Y") {
        Write-Host "기존 컨테이너 중지 중..." -ForegroundColor $YELLOW
        docker compose -f docker-compose-local.yml down 2>&1 | Out-Null
    } else {
        Write-Host "✗ 포트 충돌로 인해 계속할 수 없습니다" -ForegroundColor $RED
        exit 1
    }
}

Write-Host "✓ 포트 사용 가능" -ForegroundColor $GREEN
Write-Host ""

# ========================================
# 5. 서비스 시작
# ========================================
Write-Host "[5/8] 서비스 시작 중..." -ForegroundColor $YELLOW
Write-Host "이 과정은 몇 분 소요될 수 있습니다" -ForegroundColor $YELLOW

if ($SkipBuild) {
    docker compose -f docker-compose-local.yml up -d
} else {
    docker compose -f docker-compose-local.yml up -d --build
}

Write-Host "이미지 빌드 진행 중... (최대 5분 소요)" -ForegroundColor $YELLOW
Start-Sleep -Seconds 30

Write-Host "✓ 서비스 시작됨" -ForegroundColor $GREEN
Write-Host ""

# ========================================
# 6. 실행 중인 컨테이너 확인
# ========================================
Write-Host "[6/8] 실행 중인 컨테이너 확인 중..." -ForegroundColor $YELLOW

$runningContainers = docker compose -f docker-compose-local.yml ps --services --filter "status=running" | Measure-Object -Line | Select-Object -ExpandProperty Lines
$totalServices = docker compose -f docker-compose-local.yml config --services | Measure-Object -Line | Select-Object -ExpandProperty Lines

Write-Host "실행 중인 서비스: $runningContainers / $totalServices" -ForegroundColor $GREEN
docker compose -f docker-compose-local.yml ps
Write-Host ""

# ========================================
# 7. 서비스 헬스 체크
# ========================================
Write-Host "[7/8] 서비스 헬스 체크 중... (최대 5분)" -ForegroundColor $YELLOW

function Test-ServiceHealth {
    param(
        [string]$ServiceName,
        [string]$Port,
        [bool]$IsMySQL = $false
    )
    
    if ($IsMySQL) {
        # MySQL 헬스 체크
        for ($i = 1; $i -le $TOTAL_CHECKS; $i++) {
            try {
                $result = docker exec petclinic-mysql mysqladmin ping -u petclinic -ppetclinic -h localhost 2>&1
                if ($result -match "mysqld is alive") {
                    Write-Host "✓ $ServiceName 준비 완료" -ForegroundColor $GREEN
                    return $true
                }
            } catch {
                # 계속 시도
            }
            
            if ($i % 6 -eq 0) {
                Write-Host -NoNewline "."
            }
            Start-Sleep -Seconds $INTERVAL
        }
        Write-Host "✗ $ServiceName 헬스 체크 실패" -ForegroundColor $RED
        return $false
    } else {
        # HTTP 헬스 체크
        for ($i = 1; $i -le $TOTAL_CHECKS; $i++) {
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:$Port/actuator/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    Write-Host "✓ $ServiceName 준비 완료" -ForegroundColor $GREEN
                    return $true
                }
            } catch {
                # 계속 시도
            }
            
            if ($i % 6 -eq 0) {
                Write-Host -NoNewline "."
            }
            Start-Sleep -Seconds $INTERVAL
        }
        Write-Host "✗ $ServiceName 헬스 체크 실패" -ForegroundColor $RED
        return $false
    }
}

$allHealthy = $true
$allHealthy = $allHealthy -and (Test-ServiceHealth "MySQL" "3306" $true)
$allHealthy = $allHealthy -and (Test-ServiceHealth "API Gateway" "8080" $false)
$allHealthy = $allHealthy -and (Test-ServiceHealth "Customers Service" "8080" $false)
$allHealthy = $allHealthy -and (Test-ServiceHealth "Vets Service" "8080" $false)
$allHealthy = $allHealthy -and (Test-ServiceHealth "Visits Service" "8080" $false)

Write-Host ""

if (-not $allHealthy) {
    Write-Host "일부 서비스가 준비되지 않았습니다" -ForegroundColor $RED
    Write-Host "로그 확인:" -ForegroundColor $YELLOW
    docker compose -f docker-compose-local.yml logs --tail=50
    exit 1
}

# ========================================
# 8. 서비스 간 통신 확인
# ========================================
Write-Host "[8/8] 서비스 간 통신 확인 중..." -ForegroundColor $YELLOW
Write-Host "API Gateway 라우팅 테스트:" -ForegroundColor $YELLOW

# 1. Customers API 테스트
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/api/customer/owners" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ /api/customer/owners 라우팅 성공" -ForegroundColor $GREEN
    }
} catch {
    Write-Host "✗ /api/customer/owners 라우팅 실패" -ForegroundColor $RED
    $allHealthy = $false
}

# 2. Vets API 테스트
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/api/vet/vets" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ /api/vet/vets 라우팅 성공" -ForegroundColor $GREEN
    }
} catch {
    Write-Host "✗ /api/vet/vets 라우팅 실패" -ForegroundColor $RED
    $allHealthy = $false
}

# 3. Visits API 테스트
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/api/visit/visits" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ /api/visit/visits 라우팅 성공" -ForegroundColor $GREEN
    }
} catch {
    Write-Host "✗ /api/visit/visits 라우팅 실패" -ForegroundColor $RED
    $allHealthy = $false
}

Write-Host ""

# ========================================
# 최종 결과
# ========================================
if ($allHealthy) {
    Write-Host "========================================" -ForegroundColor $GREEN
    Write-Host "✓ 모든 검증 통과" -ForegroundColor $GREEN
    Write-Host "========================================" -ForegroundColor $GREEN
    Write-Host ""
    
    Write-Host "접근 가능한 서비스:" -ForegroundColor $BLUE
    Write-Host "  - API Gateway: http://localhost:8080" -ForegroundColor $GREEN
    Write-Host "    - Customers: http://localhost:8080/api/customer/owners"
    Write-Host "    - Vets: http://localhost:8080/api/vet/vets"
    Write-Host "    - Visits: http://localhost:8080/api/visit/visits"
    Write-Host "  - Prometheus: http://localhost:9090" -ForegroundColor $GREEN
    Write-Host "  - Grafana: http://localhost:3000" -ForegroundColor $GREEN
    Write-Host "    (기본 사용자명: admin, 비밀번호: admin)"
    Write-Host "  - MySQL: localhost:3306" -ForegroundColor $GREEN
    Write-Host "    (사용자명: petclinic, 비밀번호: petclinic)"
    Write-Host ""
    
    Write-Host "유용한 명령:" -ForegroundColor $BLUE
    Write-Host "  로그 확인: docker compose -f docker-compose-local.yml logs -f"
    Write-Host "  서비스 중지: docker compose -f docker-compose-local.yml down"
    Write-Host "  서비스 상태: docker compose -f docker-compose-local.yml ps"
    Write-Host ""
    
    exit 0
} else {
    Write-Host "========================================" -ForegroundColor $RED
    Write-Host "✗ 검증 실패" -ForegroundColor $RED
    Write-Host "========================================" -ForegroundColor $RED
    Write-Host ""
    
    Write-Host "문제 해결:" -ForegroundColor $YELLOW
    Write-Host "  1. 로그 확인:"
    Write-Host "     docker compose -f docker-compose-local.yml logs -f"
    Write-Host "  2. 컨테이너 상태 확인:"
    Write-Host "     docker compose -f docker-compose-local.yml ps"
    Write-Host "  3. 서비스 재시작:"
    Write-Host "     docker compose -f docker-compose-local.yml restart"
    Write-Host "  4. 완전 초기화:"
    Write-Host "     docker compose -f docker-compose-local.yml down -v"
    Write-Host ""
    
    exit 1
}
