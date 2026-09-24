# Nuclio 구축 가이드

이 문서는 OKE 클러스터에 **Nuclio** (서버리스 FaaS 플랫폼)를 배포하는 방법을 설명합니다.
기존에 사용하던 OpenFaaS를 대체하며, 더 나은 웹 대시보드 UI(코드 편집기, 배포,
테스트, 로그, 그래프)를 제공합니다.

## 개요

Nuclio는 고성능 이벤트/데이터 드리븐 서버리스입니다. 이 저장소에서는 ArgoCD를 통해
GitOps 방식으로 배포하며, 대시보드 UI를 `serverless.simproject.kr` 도메인으로
TLS(Let's Encrypt)와 함께 노출합니다.

## 구성 요소

| 컴포넌트 | 역할 | Namespace |
|---------|------|-----------|
| Dashboard | 웹 UI (코드 편집/배포/테스트/로그) | `serverless` |
| Controller | Nuclio CRD(Function 등)를 배포/관리 | `serverless` |
| Processor | 실행된 함수 파드 | `serverless` |

## 배포 구조

```
ArgoCD (k8s/argocd-apps/infra.yaml)
 └── infra-nuclio → Nuclio helm chart (nuclio/nuclio 0.23.4)
```

변경 사항은 `main` 브랜치에 push 되면 ArgoCD가 자동 동기화합니다.

## 인증 흐름

OpenFaaS와 동일하게 **Cloudflare Access** 가 로그인을 담당합니다.

```
Browser → https://serverless.simproject.kr
    ↓
Cloudflare Access 로그인 (허용 이메일: srfsrf0103@gmail.com)
    ↓
Nuclio Dashboard (코드 편집기 + 배포 + 테스트)
```

- Terraform: `terraform/access.tf` 의 `cloudflare_access_application.nuclio`
- 허용 이메일: `terraform/variables.tf` 의 `cloudflare_allowed_emails`
- `/.well-known/acme-challenge/*` 는 `cloudflare_access_application.acme_challenge` 가
  bypass 한다. 인증서 발급 때문에 Access 애플리케이션을 지우지 않는다.

## 주요 설정

- **이미지 아키텍처**: OKE 노드가 arm64이므로 `quay.io/nuclio/{dashboard,controller}`
  이미지를 **`-arm64` 태그**(`1.15.27-arm64`)로 지정합니다. (기본값은 `-amd64`라
  arm64 노드에서 `exec format error` 발생)
- **노출**: Gateway `public` 의 HTTPRoute `serverless/dashboard`. 차트 내장 ingress는 꺼 둔다.
- **RBAC**: `crdAccessMode: namespaced` (함수는 `serverless` 네임스페이스 내 배포)
- **함수 이미지**: `registry.pushPullUrl` 은 `registry.crowdsec.svc.cluster.local:5000`.
  비우면 Kaniko가 Docker Hub로 푸시하다가 `UNAUTHORIZED` 로 실패한다.

## 함수 빌드 관련 참고

Nuclio는 함수 이미지를 빌드하기 위해 docker daemon 또는 kaniko를 사용합니다.
OKE에는 docker daemon이 없으므로 `k8s/argocd-apps/infra.yaml` 의
`dashboard.containerBuilderKind` 는 `kaniko` 입니다.

빌드 결과는 클러스터 안 레지스트리로 푸시합니다. Deployment `registry` 가
`crowdsec` 네임스페이스의 `core-pvc` subPath `registry` 를 마운트하고,
Service `registry:5000` 으로 받습니다. 레지스트리는 HTTP라서
`dashboard.build.insecurePushRegistry` 가 켜져 있습니다. 워커의 CRI-O는
DaemonSet `registry-node-config` 가 적어 둔 insecure registry 설정으로 같은
주소를 pull 합니다.

## 트러블슈팅

### 파드가 ImagePull/exec format error
`quay.io/nuclio/*` 이미지를 `-arm64` 태그로 지정했는지 확인하세요.

### 인증서 발급 확인
```bash
kubectl get certificate -n serverless
```

### DNS 레코드
`serverless.simproject.kr` A 레코드는 `terraform/dns.tf`의
`cloudflare_record.public` (`local.public_hosts`) 로 관리됩니다.
Terraform 적용 후 DNS 전파까지 수 분이 걸릴 수 있습니다.