# Kubernetes 배포 매니페스트

이 디렉토리에는 AWS EKS에 배포하기 위한 Kubernetes 매니페스트 파일들이 포함되어 있습니다.

## 파일 구조

- `petclinic-config.yaml`: ConfigMap (DB 호스트 등 공통 설정)
- `petclinic-secret.yaml`: Secret (DB 자격증명 - **실제 값으로 교체 필요**)
- `*-service.yaml`: 각 마이크로서비스의 Deployment 및 Service 매니페스트

## 중요: 민감한 정보 마스킹

모든 매니페스트 파일은 실제 값 대신 환경 변수 placeholder를 사용합니다:

- `${ECR_REGISTRY}`: AWS ECR 레지스트리 URL (예: `123456789012.dkr.ecr.ap-northeast-2.amazonaws.com`)
- `${RDS_ENDPOINT}`: AWS RDS MySQL 엔드포인트 (예: `your-db.rds.amazonaws.com`)

## 배포 방법

### 1. 환경 변수 설정

```bash
export ECR_REGISTRY=123456789012.dkr.ecr.ap-northeast-2.amazonaws.com
export RDS_ENDPOINT=your-rds-endpoint.rds.amazonaws.com
```

### 2. Secret 파일 수정

`petclinic-secret.yaml` 파일을 열어 실제 DB 자격증명으로 수정:

```yaml
stringData:
  SPRING_DATASOURCE_USERNAME: your_actual_username
  SPRING_DATASOURCE_PASSWORD: your_actual_password
```

### 3. 배포 실행

#### 방법 1: 배포 스크립트 사용 (권장)

```bash
./k8s/deploy.sh
```

이 스크립트는 `envsubst`를 사용하여 환경 변수를 자동으로 치환합니다.

**macOS에서 envsubst 설치:**
```bash
brew install gettext
```

#### 방법 2: 수동 배포

```bash
# 환경 변수 치환
export ECR_REGISTRY=123456789012.dkr.ecr.ap-northeast-2.amazonaws.com
export RDS_ENDPOINT=your-rds-endpoint.rds.amazonaws.com

# 각 파일에 대해 envsubst 실행
envsubst < petclinic-config.yaml | kubectl apply -f -
envsubst < petclinic-secret.yaml | kubectl apply -f -
envsubst < api-gateway.yaml | kubectl apply -f -
envsubst < customers-service.yaml | kubectl apply -f -
envsubst < vets-service.yaml | kubectl apply -f -
envsubst < visits-service.yaml | kubectl apply -f -
```

## 배포 확인

```bash
# 모든 리소스 확인
kubectl get all -l app

# Pod 상태 확인
kubectl get pods

# 로그 확인
kubectl logs -f deployment/petclinic-api-gateway
```

## 주의사항

1. **Secret 파일**: `petclinic-secret.yaml`에는 실제 DB 자격증명이 포함되므로, Git에 커밋하기 전에 반드시 placeholder로 변경하세요.

2. **환경 변수**: 배포 전에 모든 필수 환경 변수가 설정되었는지 확인하세요.

3. **ECR 인증**: EKS 클러스터가 ECR에서 이미지를 pull할 수 있도록 IAM 역할이 올바르게 설정되어 있어야 합니다.

4. **RDS 접근**: EKS 노드의 보안 그룹이 RDS 인스턴스에 접근할 수 있도록 설정되어 있어야 합니다.

