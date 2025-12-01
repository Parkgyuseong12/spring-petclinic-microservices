# 테스트 호환성 분석 및 수정 계획

## 1. 테스트 파일 현황 분석

### 발견된 테스트 파일 (총 18개)

#### A. Discovery Server 관련 테스트 (⚠️ 높은 위험도)

**파일**: `spring-petclinic-discovery-server/src/test/java/org/springframework/samples/petclinic/discovery/DiscoveryServerApplicationTests.java`

```java
@SpringBootTest
class DiscoveryServerApplicationTests {
    @Test
    void contextLoads() {
    }
}
```

**문제점**:
- ❌ `@SpringBootTest`는 전체 Application Context를 로드
- ❌ `spring-cloud-starter-netflix-eureka-server` 제거됨
- ❌ Spring Cloud 의존성이 없으면 Context 로드 실패 가능

**권장 해결방안**:
- 🔧 `@Disabled` 주석 추가 (K8s 환경에서는 불필요)
- 또는 Spring Cloud 의존성을 테스트 스코프에만 유지

---

#### B. API Gateway 테스트 (⚠️ 중간 위험도)

**파일**: `spring-petclinic-api-gateway/src/test/java/org/springframework/samples/petclinic/api/ApiGatewayApplicationTests.java`

```java
@ActiveProfiles("test")
@SpringBootTest
class ApiGatewayApplicationTests {
    @Test
    void contextLoads() {
    }
}
```

**문제점**:
- ❌ `@SpringBootTest`는 전체 Context 로드 시도
- ⚠️ `spring-cloud-starter-netflix-eureka-client` 제거됨
- ⚠️ WebFlux 환경에서 특수한 처리 필요 가능

**권장 해결방안**:
- 🔧 `webEnvironment` 지정
- 🔧 Cloud 자동 등록 비활성화

**파일**: `spring-petclinic-api-gateway/src/test/java/org/springframework/samples/petclinic/api/boundary/web/ApiGatewayControllerTest.java`

**상태**: ✅ 안전
- `@WebFluxTest`는 필요한 Bean만 로드
- Cloud 의존성 불필요

---

#### C. 마이크로서비스 테스트 (✅ 낮은 위험도)

**파일들**:
- `spring-petclinic-customers-service/src/test/java/.../PetResourceTest.java`
- `spring-petclinic-vets-service/src/test/java/.../VetResourceTest.java`
- `spring-petclinic-visits-service/src/test/java/.../VisitResourceTest.java`

```java
@ExtendWith(SpringExtension.class)
@WebMvcTest(PetResource.class)
@ActiveProfiles("test")
class PetResourceTest {
    // ...
}
```

**상태**: ✅ 안전
- `@WebMvcTest`는 필요한 컴포넌트만 로드
- Cloud 의존성 없이도 작동 가능

---

#### D. 통합 테스트 (⚠️ 중간 위험도)

**파일**: `spring-petclinic-api-gateway/src/test/java/.../VisitsServiceClientIntegrationTest.java`

**문제점**:
- ⚠️ 서비스 간 통신 테스트
- ⚠️ K8s DNS 설정에 따라 달라질 수 있음

---

## 2. 리팩토링 후 예상 문제점

### 문제 1: Discovery Server Application Context
```
ERROR: 
org.springframework.context.ApplicationContextException: 
Failed to start bean 'eurekaServiceRegistry'; 
nested exception is java.lang.ClassNotFoundException: 
org.springframework.cloud.netflix.eureka.EurekaClientAutoConfiguration
```

**해결방안**:
```java
@Disabled("Discovery Server는 K8s 환경에서 불필요")
@SpringBootTest
class DiscoveryServerApplicationTests {
    @Test
    void contextLoads() {
    }
}
```

### 문제 2: API Gateway Cloud Context
```
ERROR: 
No bean of type 'com.netflix.eureka.EurekaClient' available
```

**해결방안**:
```java
@ActiveProfiles("test")
@SpringBootTest(
    properties = {
        "spring.cloud.service-registry.auto-registration.enabled=false",
        "spring.cloud.discovery.enabled=false"
    }
)
class ApiGatewayApplicationTests {
    @Test
    void contextLoads() {
    }
}
```

---

## 3. 수정 계획

### Phase 1: Discovery Server 테스트 비활성화

**변경 파일**: `spring-petclinic-discovery-server/src/test/java/.../DiscoveryServerApplicationTests.java`

```java
// 추가: import org.junit.jupiter.api.Disabled;

@Disabled("Discovery Server는 K8s 환경에서 Eureka 기반이므로 불필요")
@SpringBootTest
class DiscoveryServerApplicationTests {
    @Test
    void contextLoads() {
    }
}
```

### Phase 2: API Gateway 테스트 수정

**변경 파일**: `spring-petclinic-api-gateway/src/test/java/.../ApiGatewayApplicationTests.java`

```java
@ActiveProfiles("test")
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = {
        "spring.cloud.service-registry.auto-registration.enabled=false",
        "spring.cloud.discovery.enabled=false",
        "spring.cloud.config.enabled=false"
    }
)
class ApiGatewayApplicationTests {
    @Test
    void contextLoads() {
    }
}
```

### Phase 3: Config Server 테스트

**파일**: `spring-petclinic-config-server/src/test/java/.../PetclinicConfigServerApplicationTests.java`

- Config Server는 필요하지 않으므로 테스트 생략 가능
- 또는 `@Disabled` 적용

---

## 4. 테스트 실행 계획

### 단계 1: 단위 테스트 (안전)
```bash
# Customers Service 단위 테스트
mvn -pl spring-petclinic-customers-service test

# Vets Service 단위 테스트
mvn -pl spring-petclinic-vets-service test

# Visits Service 단위 테스트
mvn -pl spring-petclinic-visits-service test
```

**예상 결과**: ✅ 모두 PASS

---

### 단계 2: API Gateway 테스트 (수정 후)
```bash
# API Gateway 테스트 (수정 필요)
mvn -pl spring-petclinic-api-gateway test
```

**수정 전 예상**: ❌ FAIL
**수정 후 예상**: ✅ PASS

---

### 단계 3: 통합 테스트
```bash
# 전체 프로젝트 테스트
mvn test
```

**예상 결과**: ✅ 대부분 PASS (Discovery/Config Server 제외)

---

## 5. 테스트 비활성화 전략

### 임시 비활성화 (권장)
```java
@Disabled("K8s 환경에서는 Eureka 기반 Discovery가 불필요. " +
          "Kubernetes DNS를 사용합니다.")
@SpringBootTest
class DiscoveryServerApplicationTests {
    @Test
    void contextLoads() {
    }
}
```

### 조건부 비활성화
```java
@DisabledIfEnvironmentVariable(
    named = "DEPLOYMENT_ENV",
    matches = "kubernetes"
)
@SpringBootTest
class DiscoveryServerApplicationTests {
    @Test
    void contextLoads() {
    }
}
```

---

## 6. 검증 체크리스트

- [ ] `spring-petclinic-discovery-server` 테스트에 `@Disabled` 추가
- [ ] `spring-petclinic-api-gateway` 테스트에 Cloud 설정 비활성화 추가
- [ ] `spring-petclinic-config-server` 테스트에 `@Disabled` 추가
- [ ] 마이크로서비스 테스트 (`@WebMvcTest`) 검증
- [ ] `mvn test` 전체 테스트 실행
- [ ] 테스트 커버리지 확인
- [ ] 빌드 산출물(JAR) 생성 확인

---

## 7. 예상 테스트 결과

| 모듈 | 상태 | 비고 |
|------|------|------|
| Customers Service | ✅ PASS | `@WebMvcTest` 사용 |
| Vets Service | ✅ PASS | `@WebMvcTest` 사용 |
| Visits Service | ✅ PASS | `@WebMvcTest` 사용 |
| API Gateway | ⚠️ → ✅ | 수정 후 PASS |
| Discovery Server | ⏭️ SKIPPED | `@Disabled` |
| Config Server | ⏭️ SKIPPED | `@Disabled` |
| GenAI Service | ✅ PASS | 테스트 최소 |
| Admin Server | ✅ PASS | 테스트 최소 |

**전체 테스트 예상 결과**: ✅ BUILD SUCCESS

---

## 8. 빌드 명령어

```bash
# 테스트 스킵 (빠른 검증)
./mvnw clean package -DskipTests

# 테스트 포함 (전체 검증)
./mvnw clean package

# 특정 모듈만 테스트
./mvnw -pl spring-petclinic-customers-service test

# 테스트 결과 상세 보기
./mvnw clean test -X
```

---

## 9. 주의사항

1. **Spring Cloud 의존성**
   - pom.xml에서 Eureka/Config 의존성이 완전히 제거되었는지 확인
   - `spring-cloud-starter-gateway`는 API Gateway에서만 유지

2. **테스트 프로필**
   - `application-test.yml` 파일이 있는지 확인
   - 테스트 환경에서 Cloud 설정이 비활성화되었는지 확인

3. **Docker/K8s 환경**
   - 로컬 테스트는 성공해도 K8s 배포 시 추가 설정 필요 가능
   - 환경 변수 주입 확인 필수

---

## 다음 단계

1. 테스트 파일 수정 실행
2. `mvn test` 실행 및 결과 확인
3. 빌드 아티팩트(JAR) 생성 확인
4. Docker 이미지 빌드 테스트
5. Local Docker Compose 배포 테스트
