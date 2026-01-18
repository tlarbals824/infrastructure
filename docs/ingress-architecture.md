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
│  - Public IP: ...                                   │
│  - 포트: 80 (HTTP), 443 (HTTPS)                                 │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  nginx Ingress Controller                                       │
│  - L7 라우팅 (Host/Path 기반)                                    │
│  - TLS 종료                                                     │
│  - Namespace: ingress-nginx                                     │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  Backend Services                                               │
│  - ArgoCD (argocd.simproject.kr)                               │
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

**위치:** `k8s/infra/ingress-nginx/`

### 2. nginx Ingress Controller

L7 라우팅을 담당하는 Ingress Controller입니다.

**기능:**
- Host 기반 라우팅 (예: argocd.simproject.kr)
- Path 기반 라우팅 (예: /api, /web)
- TLS 종료
- 리버스 프록시

**위치:** `k8s/infra/ingress-nginx/`

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
            ingressClassName: nginx
```

**위치:** `k8s/infra/cert-manager/`

## Ingress 리소스 예시

ArgoCD Ingress 설정:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - argocd.simproject.kr
      secretName: argocd-server-tls
  rules:
    - host: argocd.simproject.kr
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
```

**위치:** `k8s/infra/argocd/ingress.yaml`

## 새 서비스 추가 방법

### 1. DNS 레코드 추가

OCI DNS에서 A 레코드 추가:
```
Type: A
Name: <subdomain>
Address: 158.179.174.184 (NLB IP)
```

### 2. Ingress 리소스 생성

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service-ingress
  namespace: <namespace>
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - <subdomain>.simproject.kr
      secretName: my-service-tls
  rules:
    - host: <subdomain>.simproject.kr
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <service-name>
                port:
                  number: <port>
```

### 3. 인증서 확인

```bash
kubectl get certificate -n <namespace>
```

## 네트워크 보안

### Worker 노드 보안 규칙

NLB가 클라이언트 IP를 보존하므로, Worker 노드에서 NodePort 트래픽을 허용해야 합니다.

**Terraform 설정** (`terraform/network.tf`):
```hcl
# NLB NodePort 트래픽 허용
ingress_security_rules {
  protocol = "6"              # TCP
  source   = "0.0.0.0/0"
  tcp_options {
    min = 30000
    max = 32767               # NodePort 범위
  }
}
```

**보안 참고:**
- Worker 노드는 Private Subnet에 있어 외부에서 직접 접근 불가
- 외부 트래픽은 반드시 NLB를 통해서만 Worker에 도달

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
└── ingress-nginx/
    ├── kustomization.yaml
    └── namespace.yaml
```

## 참고 링크

- [nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager 문서](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [OCI Network Load Balancer](https://docs.oracle.com/en-us/iaas/Content/NetworkLoadBalancer/overview.htm)
