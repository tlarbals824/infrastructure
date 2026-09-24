# Ingress Architecture

OKE 클러스터의 Ingress 구조 및 TLS 인증서 관리 방법을 정리한 문서입니다.

## 전체 구조

```
                            인터넷
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  OCI Network Load Balancer (NLB)                                │
│  - L4 로드밸런서 (TCP/UDP)                                       │
│  - Always Free Tier (무료)                                      │
│  - Public IP: 134.185.104.125                                   │
│  - 포트: 80 (HTTP), 443 (HTTPS)                                 │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  Traefik                                                        │
│  - L7 라우팅 (Host/Path 기반)                                    │
│  - TLS 종료                                                     │
│  - Namespace: edge                                              │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  Backend Services                                               │
│  - ArgoCD (argocd.simproject.kr)                               │
│  - Nuclio Dashboard (serverless.simproject.kr)                     │
│  - 추가 서비스 확장 가능                                          │
└─────────────────────────────────────────────────────────────────┘
```

## 구성 요소

### 1. Network Load Balancer (NLB)

OCI의 무료 L4 로드밸런서입니다.

**특징:**
- Always Free Tier에서 1개 무료
- 대역폭 제한 없음
- 클라이언트 IP 보존 (Source NAT 없음)

**Kubernetes 설정:**
```yaml
metadata:
  annotations:
    oci.oraclecloud.com/load-balancer-type: "nlb"
spec:
  type: LoadBalancer
```

**위치:** `k8s/argocd-apps/infra.yaml` 의 `infra-traefik` (`loadBalancerIP` 포함).

### 2. Traefik

L7 라우팅을 담당하는 Ingress Controller입니다. ingress-nginx 유지보수가 끝나서 Traefik 3으로 바꿨습니다.

**기능:**
- Host 기반 라우팅 (예: argocd.simproject.kr)
- Path 기반 라우팅 (예: /api, /web)
- TLS 종료
- 리버스 프록시

**위치:** 차트 값은 `k8s/argocd-apps/infra.yaml` 의 `infra-traefik`. Gateway, SealedSecret, 호스트 묶음은 `k8s/edge`.

### 3. cert-manager

Let's Encrypt 인증서를 자동으로 발급/갱신합니다.

**기능:**
- Let's Encrypt 무료 인증서 발급
- 만료 30일 전 자동 갱신
- HTTP-01 Challenge 사용

**ClusterIssuer 설정:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@simproject.kr
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
```

**위치:** `k8s/infra/cert-manager/`

## HTTPRoute 예시

Argo CD는 Gateway에서 TLS를 끝내고 서버는 HTTP로 받습니다.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  parentRefs:
    - name: public
      namespace: edge
      sectionName: https-argocd
  hostnames:
    - argocd.simproject.kr
  rules:
    - backendRefs:
        - name: argocd-server
          port: 80
```

**위치:** `k8s/edge/hosts/argocd`.

## 새 서비스 추가 방법

### 1. DNS 레코드 추가

Cloudflare DNS는 `terraform/dns.tf`에서 관리합니다. A 레코드는
`local.nlb_ip`(134.185.104.125)를 가리키고 `proxied = true` 로 둡니다.

### 2. Gateway 리스너와 HTTPRoute

`Gateway/public`에 호스트 리스너를 추가하고, 서비스 네임스페이스에
`Certificate`, `ReferenceGrant`, `HTTPRoute`를 둡니다. 백엔드 포트는 Service 포트를 그대로 씁니다.

### 3. 인증서 확인

```bash
kubectl get certificate -n <namespace>
```

## 네트워크 보안

### Worker 노드 보안 규칙

NLB가 클라이언트 IP를 보존하므로, Worker 노드에서 NodePort 트래픽을 허용해야 합니다.

**Terraform 설정** (`terraform/network.tf`):

NLB 리스너(80/443)와 워커 NodePort(30000-32767)는 `cloudflare_ip_ranges` 의
IPv4 CIDR 만 허용합니다. NLB 헬스체크는 워커 보안 리스트의 `10.0.0.0/16` 규칙으로
LB 서브넷에서 들어옵니다.

**보안 참고:**
- 워커 노드는 Private Subnet이라 공인 IP가 없다
- 공개 트래픽은 Cloudflare → NLB → Traefik 순서만 허용된다
- NLB에 오리진 IP로 직접 붙는 연결은 보안 리스트에서 거절된다
- Traefik 은 Cloudflare 대역의 `X-Forwarded-For` 와 `CF-Connecting-IP` 를 실제 클라이언트 주소로 사용한다

## 트러블슈팅

### 인증서 발급 실패

```bash
# 인증서 상태 확인
kubectl get certificate -n <namespace>

# Challenge 상태 확인
kubectl get challenges -n <namespace>

# 상세 로그 확인
kubectl describe certificate <name> -n <namespace>
```

### 일반적인 문제

| 문제 | 원인 | 해결 |
|------|------|------|
| Challenge pending | DNS 미전파 | DNS 전파 대기 (최대 5분) |
| Timeout | 방화벽 차단 | Worker 보안 규칙 확인 |
| 404 에러 | Ingress 설정 오류 | Ingress Controller 로그 확인 |

### CoreDNS 외부 도메인 Resolve 문제

클러스터 내부에서 외부 도메인 resolve가 안 되면:

```bash
# CoreDNS 설정 확인
kubectl get configmap coredns -n kube-system -o yaml

# Google DNS 사용하도록 수정 (forward . 8.8.8.8 8.8.4.4)
```

## 파일 구조

```
k8s/infra/
├── argocd/
│   ├── ingress.yaml          # ArgoCD Ingress + TLS
│   ├── kustomization.yaml
│   └── namespace.yaml
├── cert-manager/
│   ├── cluster-issuer.yaml   # Let's Encrypt ClusterIssuer
│   └── kustomization.yaml
├── ingress-nginx/
│   ├── kustomization.yaml
│   └── namespace.yaml
└── nuclio/   # Nuclio 대시보드 (serverless.simproject.kr) - 차트 내장 ingress 사용
```
> 참고: Nuclio는 helm 차트의 내장 `dashboard.ingress`로 노출하므로
> `k8s/infra/<app>/` 별도 Ingress 파일이 없습니다.

## 참고 링크

- [Traefik](https://doc.traefik.io/traefik/)
- [cert-manager 문서](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [OCI Network Load Balancer](https://docs.oracle.com/en-us/iaas/Content/NetworkLoadBalancer/overview.htm)
