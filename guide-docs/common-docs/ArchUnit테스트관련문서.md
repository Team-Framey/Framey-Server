## ArchUnit 테스트 가이드

### ArchUnit란?
ArchUnit은 Java 프로젝트의 아키텍처 규칙을 자동으로 검증하기 위한 테스트 라이브러리입니다.
일반적인 단위 테스트가 비즈니스 로직의 실행 결과를 검증한다면, ArchUnit은 클래스 간 의존 관계, 계층 간 접근 제한, 패키지 구조 등 코드의 설계 규칙을 검증합니다.
> **FRAMEY에서는 개발 과정에서 발생할 수 있는 아키텍처 위반을 조기에 발견하고, 프로젝트의 설계 일관성을 유지하기 위해 ArchUnit을 추가했습니다.**

### ArchUnit가 검증하는 규칙

ArchUnit을 활용하면 다음과 같은 규칙을 검증할 수 있습니다

- 서비스 간 직접 의존 금지
- Controller에서 Entity 직접 참조 금지
- Controller에서 Infrastructure 계층 직접 참조 금지
- 계층 간 의존 방향 검증
- 특정 패키지의 접근 제한
- 어노테이션 사용 규칙 검증


### 현재 Framey 루트 Gradle 설정
루트 `build.gradle`의 `subprojects` 블록에서 ArchUnit 의존성을 공통으로 관리하고 있습니다
```groovy
subprojects {
    dependencies {
        testImplementation 'com.tngtech.archunit:archunit-junit5:1.4.0'
    }
}
```

이를 통해 각 하위 모듈에서 별도의 의존성 설정 없이 ArchUnit 테스트를 작성할 수 있습니다 (JUnit 5 테스트와 함께 실행됩니다)

### ArchUnit 테스트 방법
#### 1. ArchUnit 테스트 클래스 생성
ArchUnit 테스트가 필요해 테스트를 작성할 경우 기존 테스트 코드와 동일한 src/test/java 디렉터리에 테스트 클래스를 생성하여 진행하면 됩니다.
    * 작성 위치: src/test/java/framey/{domain}/
    * 파일명 예시: ArchitectureTest.java
    * 작성한 ArchUnit 테스트는 기존 테스트와 함께 실행되며, PR CI에서도 자동으로 검증됩니다.

**( 프로젝트 구조 참고)**

```text
server/
└── framey-application/
    │
    ├── member-service/
    │   └── src/
    │       ├── main/java/framey/member/
    │       └── test/java/framey/member/
    │           └── ArchitectureTest.java
    │
    ├── collage-service/
    │   └── src/
    │       ├── main/java/framey/collage/
    │       └── test/java/framey/collage/
    │           └── ArchitectureTest.java
    │
    └── archive-service/
        └── src/
            ├── main/java/framey/archive/
            └── test/java/framey/archive/
                └── ArchitectureTest.java
```
#### 2. ArchUnit 테스트 코드 작성 방법

ArchUnit 테스트는 일반적으로 **분석 대상 지정 → 검증 규칙 정의 → 테스트 실행** 순서로 작성합니다.
검증하려는 아키텍처 규칙에 따라 필요한 구성 요소를 조합하여 사용하면됩니다>!

**( 기본 코드 구조 예시)**

```java
package framey.member;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import jakarta.persistence.Entity;
import org.springframework.web.bind.annotation.RestController;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

// 1. 분석할 패키지 및 클래스 범위 지정
@AnalyzeClasses(
        packages = "framey.member",
        importOptions = ImportOption.DoNotIncludeTests.class
)
class ArchitectureTest {

    // 2. 아키텍처 테스트 등록
    @ArchTest
    static final ArchRule controllerShouldNotDependOnEntity =

            // 3. 검사할 클래스 선택
            noClasses()
                    .that().areAnnotatedWith(RestController.class)

                    // 4. 금지할 의존 관계 정의
                    .should().dependOnClassesThat()
                    .areAnnotatedWith(Entity.class);
}
```
위 코드는 **`@RestController`가 적용된 클래스가 `@Entity` 클래스에 직접 의존하지 않는지** 검증하는 테스트입니다.

- 구성 요소별 작성 위치 및 역할

| 순서 | 구성 요소 | 작성 위치 | 역할 |
|---|---|---|---|
| 1| `@AnalyzeClasses` | `ArchitectureTest` 클래스 위 | 분석할 패키지 및 클래스 범위 지정 |
| 2 | `@ArchTest` | `ArchRule` 필드 위 | 작성한 아키텍처 규칙을 테스트로 등록 |
| 3 | `classes()` / `noClasses()` | `ArchRule` 정의 시작 부분 | 검사할 클래스의 조건 지정 |
| 4 | `.that()` | `classes()` / `noClasses()` 다음 | 검사 대상 클래스 선택 |
| 5 | `.should()` | 검사 대상 지정 이후 | 해당 클래스가 지켜야 할 규칙 정의 |
| 6 | `.dependOnClassesThat()` | `.should()` 다음 | 의존 관계를 검사하도록 지정 |
| 7 | `.allowEmptyShould(true)` | 규칙 마지막 부분 | 검사 대상이 없어도 통과하도록 허용 |

##### 규칙 작성 방식

ArchUnit 규칙은 일반적으로 다음 형태로 작성합니다

```java
@ArchTest
static final ArchRule controllerShouldNotDependOnInfrastructure =
        noClasses()
                .that().areAnnotatedWith(RestController.class) // 검사 대상
                .should().dependOnClassesThat()               // 검증 조건
                .resideInAPackage("..infrastructure..");
```
기본적으로 **검사 대상(WHO)과 검증 조건(WHAT)** 을 구분하여 작성합니다.

**① 검사 대상 선택**
`classes()` 또는 `noClasses()`를 사용합니다.

```java
classes()
```
특정 조건에 해당하는 클래스가 규칙을 만족해야 할 때 사용합니다.

```java
noClasses()
```
특정 조건에 해당하는 클래스가 금지된 관계나 조건을 갖지 않아야 할 때 사용합니다.

**② 검사 대상 조건 지정**

`.that()` 다음에 검사할 클래스의 조건을 작성합니다.

패키지 기준:

```java
.that().resideInAPackage("..application..")
```

어노테이션 기준:

```java
.that().areAnnotatedWith(RestController.class)
```

클래스 이름 기준:

```java
.that().haveSimpleNameEndingWith("Service")
```

**③ 검증 조건 지정**

`.should()` 다음에 검사 대상이 지켜야 할 규칙을 작성합니다.

특정 패키지에 의존하는지 검사:

```java
.should().dependOnClassesThat()
.resideInAPackage("..infrastructure..")
```

특정 어노테이션이 적용된 클래스에 의존하는지 검사:

```java
.should().dependOnClassesThat()
.areAnnotatedWith(Entity.class)
```

특정 어노테이션 사용 여부 검사:

```java
.should().beAnnotatedWith(Service.class)
```
##### (참고용) 규칙 작성 예시

**예시 1. Controller가 Infrastructure 계층에 직접 의존하지 않도록 제한**

```java
@ArchTest
static final ArchRule controllerShouldNotDependOnInfrastructure =
        noClasses()
                .that().areAnnotatedWith(RestController.class)
                .should().dependOnClassesThat()
                .resideInAPackage("..infrastructure..");
```

- **검사 대상:** `@RestController`가 적용된 클래스
- **검증 조건:** `infrastructure` 패키지의 클래스에 직접 의존하지 않아야 함

**예시 2. Application 계층이 Presentation 계층에 의존하지 않도록 제한**

```java
@ArchTest
static final ArchRule applicationShouldNotDependOnPresentation =
        noClasses()
                .that().resideInAPackage("..application..")
                .should().dependOnClassesThat()
                .resideInAPackage("..presentation..");
```

- **검사 대상:** `application` 패키지에 속한 클래스
- **검증 조건:** `presentation` 패키지의 클래스에 직접 의존하지 않아야 함

**예시 3. Application Service 클래스에 `@Service` 어노테이션 적용**

```java
@ArchTest
static final ArchRule applicationServiceShouldHaveServiceAnnotation =
        classes()
                .that().resideInAPackage("..application..")
                .and().haveSimpleNameEndingWith("Service")
                .and().areNotInterfaces()
                .should().beAnnotatedWith(Service.class);
```

- **검사 대상:** `application` 패키지에서 이름이 `Service`로 끝나는 구현 클래스
- **검증 조건:** `@Service` 어노테이션이 적용되어 있어야 함

해당 규칙은 Application Service를 `@Service`로 등록하는 설계를 사용하는 경우에 적용합니다.


##### 여러 규칙을 작성할 경우

하나의 `ArchitectureTest.java`에 여러 개의 `@ArchTest`를 정의할 수 있습니다.

```java
@AnalyzeClasses(
        packages = "framey.member",
        importOptions = ImportOption.DoNotIncludeTests.class
)
class ArchitectureTest {

    // Controller → Entity 의존 금지
    @ArchTest
    static final ArchRule controllerShouldNotDependOnEntity =
            noClasses()
                    .that().areAnnotatedWith(RestController.class)
                    .should().dependOnClassesThat()
                    .areAnnotatedWith(Entity.class);

    // Controller → Infrastructure 의존 금지
    @ArchTest
    static final ArchRule controllerShouldNotDependOnInfrastructure =
            noClasses()
                    .that().areAnnotatedWith(RestController.class)
                    .should().dependOnClassesThat()
                    .resideInAPackage("..infrastructure..");

    // Application → Presentation 의존 금지
    @ArchTest
    static final ArchRule applicationShouldNotDependOnPresentation =
            noClasses()
                    .that().resideInAPackage("..application..")
                    .should().dependOnClassesThat()
                    .resideInAPackage("..presentation..");
}
```

각 규칙은 독립적인 테스트로 실행됩니다.

따라서 필요한 규칙만 선택하여 추가해 테스트 진행하면됩니다.!


#### 3. 테스트 실행 방법

작성한 ArchUnit 테스트는 기존 JUnit 테스트와 함께 실행됩니다.

**Member 서비스 전체 테스트**
```bash
./gradlew :framey-application:member-service:test
```

**ArchitectureTest만 실행**
```bash
./gradlew :framey-application:member-service:test \
  --tests "framey.member.ArchitectureTest"
```

**전체 프로젝트 테스트**
```bash
./gradlew test
```

테스트 실행 시 정의한 아키텍처 규칙을 위반하는 클래스가 발견되면 해당 테스트가 실패하게되며,  작성한 ArchUnit 테스트는 PR CI에서도 일반 테스트와 함께 자동 실행됩니다.

#### ⚠️ ArchUnit 테스트 코드 작성 시 주의 사항

- `@AnalyzeClasses`의 `packages`는 실제 도메인의 패키지명에 맞게 설정해야 합니다.
- `resideInAPackage()`는 실제 프로젝트의 패키지 구조를 기준으로 작성해야 합니다.
- `classes()`와 `noClasses()`는 검증하려는 아키텍처 규칙의 목적에 따라 구분하여 사용합니다.
- `allowEmptyShould(true)`는 검사 대상 클래스가 존재하지 않아도 되는 경우에만 사용합니다. 해당 설정을 사용하면 검사 대상이 없어도 테스트가 통과할 수 있으므로 주의해야 합니다.
- 테스트가 정상적으로 통과하는지 확인하는 것뿐만 아니라, 의도적으로 규칙을 위반했을 때 테스트가 실패하는지도 확인하는 것을 권장합니다.
- **ArchUnit 테스트 작성은 필수가 아닙니다.** 각 서비스 필요에 따라 검증할 아키텍처 규칙을 자율적으로 정의하고 테스트에 활용하면 됩니다.

### 4. GitHub Actions CI 연동

현재 FRAMEY는 PR 생성 시 GitHub Actions에서 Gradle 빌드 및 테스트를 자동으로 실행하고 있습니다.

```yaml
- name: Build and Test
  run: ./gradlew clean build --no-daemon
```

Gradle의 `build` 작업에는 `check` 작업이 포함되며, 이를 통해 일반 JUnit 테스트와 작성된 ArchUnit 테스트가 함께 실행됩니다.

따라서 **ArchUnit 테스트를 작성한 경우 별도의 CI 설정 없이도 PR에서 아키텍처 규칙을 자동으로 검증할 수 있습니다.**

#### CI 실행 흐름

```text
Feature Branch → PR 생성
          │
          ▼
     GitHub Actions
          │
          ▼
   Gradle Build & Test
          │
          ├── 일반 단위 테스트
          ├── 통합 테스트
          └── ArchUnit 테스트 (작성된 경우)
                    │
                    ├── 규칙 준수 → 테스트 성공
                    │
                    └── 규칙 위반 → 테스트 실패
                                     │
                                     ▼
                                  CI 실패
```

- 작성된 ArchUnit 규칙을 위반하면 테스트 및 해당 CI 작업이 실패합니다.
- ArchUnit 테스트를 작성하지 않은 경우에는 기존 테스트만 실행됩니다.
- ArchUnit 테스트 작성 여부 자체는 CI 실패 조건이 아닙니다.

### 5. ArchUnit 운영 정책

FRAMEY에서는 ArchUnit 의존성을 공통으로 제공하되, **각 서비스 담당자가 필요한 아키텍처 규칙을 자율적으로 작성하여 활용하는 방식**으로 운영합니다.

#### 기본 운영 원칙

- **자율적 활용:** ArchUnit 테스트 작성은 필수가 아니며, 각 서비스의 설계와 필요에 따라 선택적으로 사용합니다.
- **도메인별 관리:** 작성한 아키텍처 규칙은 해당 서비스의 테스트 코드에서 관리합니다.
- **자동 검증:** 작성된 ArchUnit 테스트는 기존 JUnit 테스트와 함께 PR CI에서 실행됩니다.
- **규칙 유지보수:** 아키텍처 변경으로 기존 규칙의 수정이 필요한 경우 관련 테스트도 함께 갱신합니다.
- **공통 규칙 관리:** 여러 서비스에 공통으로 적용할 필요가 있는 규칙은 팀 논의를 통해 별도로 관리할 수 있습니다.

#### 테스트 작성 시 고려 사항

ArchUnit은 작성된 규칙과 지정된 분석 범위 내에서 정적으로 확인할 수 있는 구조만 검증합니다.

따라서 테스트가 통과하더라도 모든 아키텍처 원칙이 보장되는 것은 아닙니다.

또한 ArchUnit은 다음과 같은 항목을 직접 검증하기에는 한계가 있습니다.

- 비즈니스 로직의 정확성
- 런타임 동작 및 예외 처리
- 트랜잭션 경계의 적절성
- 서비스 간 API 및 이벤트 계약의 정확성
- 아키텍처 설계 의도의 타당성

이러한 부분은 일반 단위 테스트, 통합 테스트 및 코드 리뷰 등을 통해 별도로 검증해야 합니다.

### 6. CLAUDE.md 및 다른 품질 도구와의 관계

FRAMEY에서는 여러 도구를 활용하여 코드 품질과 아키텍처를 검증합니다.

| 도구 | 역할 |
|---|---|
| `CLAUDE.md` | 프로젝트 아키텍처 원칙 및 개발 규칙 정의 |
| ArchUnit | 작성된 아키텍처 규칙을 테스트 코드로 자동 검증 |
| Checkstyle | Java 코드 스타일 및 컨벤션 검사 |
| SonarQube | 정적 분석, 코드 품질 및 테스트 커버리지 분석 |
| CodeRabbit | PR 코드 리뷰 |
| Claude Code | 아키텍처 변경 영향 분석 및 설계 개선 방향 검토 |

`CLAUDE.md`에 아키텍처 규칙을 정의했다고 ArchUnit이 해당 규칙을 자동으로 검증하는 것은 아닙니다.

ArchUnit은 개발자가 작성한 테스트 규칙을 검증하며, Claude Code는 `CLAUDE.md`에 정의된 설계 원칙을 참고하여 코드 변경 사항을 추가로 검토할 수 있습니다.

단, Claude Code의 자동 검토는 별도의 리뷰 워크플로가 구성되어 실행될 때 수행됩니다.

각 도구는 서로 다른 역할을 수행하며 상호 보완적으로 활용합니다.
