# Spring PetClinic 로컬 배포 및 검증 가이드

## 📖 개요

이 가이드는 Kubernetes 마이그레이션된 Spring PetClinic 마이크로서비스를 **로컬 환경에서 Docker Compose로 배포하고 검증**하는 방법을 설명합니다.

---

## 🎯 목표

- ✅ Docker 없이 Kubernetes로 마이그레이션된 서비스가 올바르게 작동하는지 확인
- ✅ 서비스 간 DNS 기반 통신 검증 (Eureka 제거 후)
- ✅ 데이터베이스 연결 확인
- ✅ API Gateway 라우팅 검증
- ✅ Prometheus 모니터링 구성 테스트

---

## 📋 필수 사항

### 시스템 요구사항
- **Docker Desktop** 최신 버전 (또는 Docker + Docker Compose)
  - Windows: Docker Desktop for Windows
  - Mac: Docker Desktop for Mac
  - Linux: Docker Engine + Docker Compose Plugin

### 설치 확인
```bash
# Docker 버전 확인
docker --version
# Docker Desktop 17.06.0 이상 필요

# Docker Compose 확인
docker compose version
# Docker Compose 2.0 이상 필요

# docker ps 실행 가능 확인
docker ps
```

---

## 🚀 빠른 시작

### 1️⃣ 로컬 배포 시작

#### Windows (PowerShell)
```powershell
# 검증 스크립트 실행 (권장)
.\validate_local_deployment.ps1

# 또는 수동 시작
docker compose -f docker-compose-local.yml up -d --build
```

#### Linux/Mac (Bash)
```bash
# 검증 스크립트 실행 (권장)
chmod +x validate_local_deployment.sh
./validate_local_deployment.sh

# 또는 수동 시작
docker compose -f docker-compose-local.yml up -d --build
```

### 2️⃣ 로그 확인
```bash
# 모든 서비스 로그
docker compose -f docker-compose-local.yml logs -f

# 특정 서비스 로그
docker compose -f docker-compose-local.yml logs -f api-gateway
docker compose -f docker-compose-local.yml logs -f customers-service
```

### 3️⃣ 서비스 상태 확인
```bash
# 실행 중인 컨테이너
docker compose -f docker-compose-local.yml ps

# 네트워크 확인
docker network ls
docker network inspect docker-compose-local_petclinic-network
```

### 4️⃣ 서비스 테스트

#### API Gateway 상태
```bash
curl http://localhost:8080/actuator/health
```

#### Customers Service (Gateway 경유)
```bash
curl http://localhost:8080/api/customer/owners
```

#### Vets Service (Gateway 경유)
```bash
curl http://localhost:8080/api/vet/vets
```

#### Visits Service (Gateway 경유)
```bash
curl http://localhost:8080/api/visit/visits
```

### 5️⃣ 모니터링 접근

| 서비스 | URL | 인증 |
|--------|-----|------|
| **API Gateway** | http://localhost:8080 | 없음 |
| **Prometheus** | http://localhost:9090 | 없음 |
| **Grafana** | http://localhost:3000 | admin/admin |
| **MySQL** | localhost:3306 | petclinic/petclinic |

### 6️⃣ 서비스 중지

```bash
# 모든 서비스 중지 (데이터 유지)
docker compose -f docker-compose-local.yml down

# 볼륨 포함 삭제 (완전 초기화)
docker compose -f docker-compose-local.yml down -v

# 이미지까지 삭제
docker compose -f docker-compose-local.yml down --rmi all
```

---

## 📊 docker-compose-local.yml 구성

### 포함된 서비스

```yaml
services:
  mysql:              # 데이터베이스 (포트: 3306)
  customers-service:  # 고객 서비스 (내부)
  vets-service:       # 수의사 서비스 (내부)
  visits-service:     # 방문 기록 서비스 (내부)
  api-gateway:        # API 게이트웨이 (포트: 8080)
  genai-service:      # AI/ML 서비스 (내부)
  prometheus:         # 모니터링 (포트: 9090)
  grafana:            # 시각화 (포트: 3000)
```

### 네트워크 구조

```
petclinic-network (Docker 브릿지 네트워크)
├── api-gateway:8080 (호스트 포트: 8080)
├── customers-service:8080 (내부만 접근)
├── vets-service:8080 (내부만 접근)
├── visits-service:8080 (내부만 접근)
├── genai-service:8080 (내부만 접근)
├── mysql:3306 (호스트 포트: 3306)
├── prometheus:9090 (호스트 포트: 9090)
└── grafana:3000 (호스트 포트: 3000)
```

### 환경 변수

모든 서비스에 설정:
```yaml
DB_HOST: mysql                    # MySQL 호스트 (컨테이너 이름)
DB_PORT: 3306                     # MySQL 포트
DB_NAME: petclinic                # 데이터베이스명
DB_USER: petclinic                # DB 사용자명
DB_PASS: petclinic                # DB 비밀번호
SPRING_PROFILES_ACTIVE: mysql     # MySQL 프로필
```

---

## 🔍 트러블슈팅

### ❌ 포트 충돌

**증상**: `bind: address already in use`

**해결**:
```bash
# 포트 확인 (Windows PowerShell)
netstat -ano | findstr :8080

# 포트 확인 (Linux/Mac)
lsof -i :8080

# 기존 컨테이너 중지
docker compose -f docker-compose-local.yml down

# 포트 변경 (선택사항)
# docker-compose-local.yml의 ports 수정:
# ports:
#   - "8081:8080"  # 호스트:컨테이너
```

### ❌ MySQL 연결 실패

**증상**: `Can't connect to MySQL server`

**해결**:
```bash
# MySQL 컨테이너 직접 테스트
docker exec petclinic-mysql mysqladmin ping -u petclinic -ppetclinic -h localhost

# MySQL 로그 확인
docker compose -f docker-compose-local.yml logs mysql

# 데이터 초기화
docker compose -f docker-compose-local.yml down -v
docker compose -f docker-compose-local.yml up -d mysql
```

### ❌ 서비스 간 통신 불가

**증상**: `Connection refused`, `getaddrinfo: Name or service not known`

**해결**:
```bash
# 네트워크 확인
docker network inspect docker-compose-local_petclinic-network

# DNS 테스트
docker exec petclinic-api-gateway nslookup customers-service

# 네트워크 재구성
docker network rm docker-compose-local_petclinic-network
docker compose -f docker-compose-local.yml restart
```

### ❌ 이미지 빌드 실패

**증상**: `failed to solve with frontend dockerfile`

**해결**:
```bash
# 기존 이미지 삭제
docker compose -f docker-compose-local.yml down --rmi all

# 캐시 제거 후 재빌드
docker builder prune -a
docker compose -f docker-compose-local.yml build --no-cache

# 또는 증분 빌드
docker compose -f docker-compose-local.yml up -d --build
```

### ❌ 헬스 체크 실패

**증상**: `Health check failed`

**해결**:
```bash
# 서비스 로그 확인
docker compose -f docker-compose-local.yml logs api-gateway

# 헬스 엔드포인트 직접 테스트
curl http://localhost:8080/actuator/health

# 시작 대기 시간 증가 (docker-compose-local.yml)
# start_period: 40s → 60s 변경
```

### ❌ 메모리/성능 이슈

**증상**: 컨테이너 자주 충돌, 느린 빌드

**해결**:
```bash
# Docker Desktop 리소스 설정 확인 (GUI)
# Settings → Resources → CPU/Memory 증가

# 개별 서비스만 실행
docker compose -f docker-compose-local.yml up -d mysql api-gateway

# 제너인 AI 서비스 비활성화
# docker-compose-local.yml에서 genai-service 주석 처리
```

---

## 📈 성능 최적화

### 이미지 캐시 활용
```bash
# 기존 이미지 사용 (캐시 활용)
docker compose -f docker-compose-local.yml up -d

# 강제 재빌드
docker compose -f docker-compose-local.yml up -d --build

# 캐시 제거 후 재빌드
docker compose -f docker-compose-local.yml build --no-cache
```

### 병렬 빌드
```bash
# 여러 이미지 동시 빌드 (권장)
docker compose -f docker-compose-local.yml build

# 개별 서비스만 빌드
docker compose -f docker-compose-local.yml build api-gateway
```

### 로그 크기 제한
```bash
# 컨테이너 로그 정리
docker system prune -a

# 볼륨 정리
docker volume prune
```

---

## 🧪 검증 체크리스트

배포 후 다음을 확인하세요:

- [ ] 모든 컨테이너 `Up` 상태 확인
- [ ] MySQL 헬스 체크 통과
- [ ] API Gateway 헬스 체크 통과
- [ ] 모든 마이크로서비스 헬스 체크 통과
- [ ] `/api/customer/owners` 응답 확인
- [ ] `/api/vet/vets` 응답 확인
- [ ] `/api/visit/visits` 응답 확인
- [ ] Prometheus metrics 수집 (`http://localhost:9090/targets`)
- [ ] Grafana 대시보드 접근 가능

---

## 🔄 Kubernetes 배포로의 전환

로컬 검증 완료 후 Kubernetes 배포:

```bash
# 1. Docker 이미지 빌드
docker compose -f docker-compose-local.yml build

# 2. 이미지 푸시 (선택사항)
docker tag customers-service:latest yourusername/customers-service:1.0
docker push yourusername/customers-service:1.0

# 3. Kubernetes 배포 준비
# KUBERNETES_REFACTORING_GUIDE.md 참조
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 4. Ingress 설정 (선택사항)
kubectl apply -f k8s/ingress.yaml
```

---

## 📝 주요 차이점: docker-compose vs Kubernetes

| 항목 | docker-compose | Kubernetes |
|-----|-----------------|-----------|
| **서비스 발견** | Docker 네트워크 DNS | K8s Service DNS |
| **설정 관리** | 환경변수 | ConfigMaps/Secrets |
| **로드 밸런싱** | Docker 기본 | K8s Service |
| **자동 재시작** | restart policy | ReplicaSet |
| **헬스 체크** | healthcheck | Probes (Liveness/Readiness) |
| **스케일링** | 수동 (replica) | HPA (Auto Scaling) |
| **모니터링** | Prometheus | Prometheus + 더 많은 메트릭 |

---

## 🎓 학습 포인트

### 1. DNS 기반 서비스 발견
```
# docker-compose에서:
api-gateway → http://customers-service:8080 (Docker DNS)

# Kubernetes에서:
api-gateway → http://customers-service:8080 (K8s DNS)
             또는 http://customers-service.default.svc.cluster.local
```

### 2. 환경 변수 관리
```
# docker-compose
environment:
  DB_HOST: mysql

# Kubernetes
env:
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: db-config
        key: host
```

### 3. 헬스 체크
```
# docker-compose
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]

# Kubernetes
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
```

---

## 📚 참고 문서

1. **KUBERNETES_REFACTORING_GUIDE.md** - K8s 마이그레이션 상세 가이드
2. **REFACTORING_SUMMARY_KO.md** - 한국어 리팩토링 요약
3. **TEST_COMPATIBILITY_ANALYSIS.md** - 테스트 호환성 분석
4. **REFACTORING_FINAL_REPORT.md** - 최종 완료 보고서

---

## 💡 팁과 트릭

### 빠른 테스트
```bash
# 특정 서비스만 시작
docker compose -f docker-compose-local.yml up -d mysql api-gateway customers-service

# 재빌드 없이 시작
docker compose -f docker-compose-local.yml up -d
```

### 디버깅
```bash
# 특정 컨테이너 셸 접근
docker exec -it petclinic-api-gateway /bin/bash

# MySQL 쿼리 실행
docker exec petclinic-mysql mysql -u petclinic -ppetclinic -D petclinic -e "SELECT COUNT(*) FROM owners;"
```

### 모니터링
```bash
# 리소스 사용량 실시간 확인
docker stats

# 컨테이너 상세 정보
docker inspect petclinic-api-gateway
```

---

## 🎉 완료!

로컬 배포 검증 완료 후, Kubernetes 클러스터로 배포할 준비가 되었습니다.

**다음 단계**: `KUBERNETES_REFACTORING_GUIDE.md` 참조하여 실제 K8s 배포 진행

---

**작성일**: 2025년  
**마지막 수정**: 2025년  
**상태**: ✅ Production Ready
