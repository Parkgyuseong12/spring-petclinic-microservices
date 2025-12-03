#!/usr/bin/env bash

# Kubernetes 매니페스트 배포 스크립트
# 환경 변수를 치환하여 실제 값으로 변환 후 kubectl apply 실행

set -euo pipefail

# 필수 환경 변수 확인
REQUIRED_VARS=("ECR_REGISTRY" "RDS_ENDPOINT")
MISSING_VARS=()

for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR:-}" ]]; then
    MISSING_VARS+=("${VAR}")
  fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo "[ERROR] 다음 환경 변수가 설정되지 않았습니다:" >&2
  printf "  - %s\n" "${MISSING_VARS[@]}" >&2
  echo "" >&2
  echo "사용 예시:" >&2
  echo "  export ECR_REGISTRY=123456789012.dkr.ecr.ap-northeast-2.amazonaws.com" >&2
  echo "  export RDS_ENDPOINT=your-rds-endpoint.rds.amazonaws.com" >&2
  echo "  ./k8s/deploy.sh" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "[INFO] 환경 변수 치환 중..."
echo "  ECR_REGISTRY=${ECR_REGISTRY}"
echo "  RDS_ENDPOINT=${RDS_ENDPOINT}"
echo ""

# envsubst를 사용하여 환경 변수 치환
# macOS에서는 gettext 패키지 설치 필요: brew install gettext
if ! command -v envsubst &> /dev/null; then
  echo "[ERROR] envsubst 명령을 찾을 수 없습니다." >&2
  echo "macOS에서는 다음 명령으로 설치하세요: brew install gettext" >&2
  exit 1
fi

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# 각 YAML 파일에 대해 환경 변수 치환
for YAML_FILE in *.yaml; do
  OUTPUT_FILE="${TEMP_DIR}/${YAML_FILE}"
  envsubst < "${YAML_FILE}" > "${OUTPUT_FILE}"
  echo "[INFO] ${YAML_FILE} 처리 완료"
done

echo ""
echo "[INFO] Kubernetes 리소스 배포 중..."
kubectl apply -f "${TEMP_DIR}"

echo ""
echo "[SUCCESS] 배포 완료!"

