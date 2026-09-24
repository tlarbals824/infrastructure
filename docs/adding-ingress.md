# Ingress 추가 가이드

새로운 서비스에 도메인을 연결하고 HTTPS를 적용하는 방법입니다.

## 사전 요구사항

- Traefik Ingress Controller 설치됨
- cert-manager 설치됨
- letsencrypt-prod ClusterIssuer 생성됨

## 추가 절차

### 1단계: Cloudflare DNS에 A 레코드 추가

`terraform/dns.tf`에 레코드를 추가합니다. 주소는 `local.nlb_ip`
(`134.185.104.125`)이고, `proxied = true` 여야 Access와 오리진 제한이 적용됩니다.

```hcl
resource "cloudflare_record" "app" {
  zone_id = var.cloudflare_zone_id
  name    = "app"
  content = local.nlb_ip
  type    = "A"
  proxied = true
  ttl     = 1
}
```

로그인이 필요한 서비스면 `terraform/access.tf`에 Access 애플리케이션을 추가하고,
같은 호스트를 `acme_challenge_hosts`에 넣습니다. ACME 경로 바이패스가 없으면
Let's Encrypt HTTP-01이 Access 로그인에 막혀 인증서가 갱신되지 않습니다.

### 2단계: Ingress 리소스 생성

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <service-name>-ingress
  namespace: <namespace>
  annotations:
    # Let's Encrypt 인증서 자동 발급
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - <subdomain>.simproject.kr
      secretName: <service-name>-tls
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

### 3단계: 적용

Ingress 매니페스트를 저장소에 커밋하고 `main`에 머지합니다. Argo CD가 자동으로 동기화합니다.
Terraform 변경(DNS, Access)은 머지 후 GitHub Actions가 apply 합니다.

### 4단계: 확인

```bash
# Ingress 상태 확인
kubectl get ingress -n <namespace>

# 인증서 발급 상태 확인
kubectl get certificate -n <namespace>

# 인증서가 READY: True 될 때까지 대기 (1-2분 소요)
```

## 예시

### 예시 1: 웹 애플리케이션

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - app.simproject.kr
      secretName: webapp-tls
  rules:
    - host: app.simproject.kr
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: webapp-service
                port:
                  number: 80
```

### 예시 2: API 서버

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.middlewares: ingress-nginx-bouncer@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - api.simproject.kr
      secretName: api-tls
  rules:
    - host: api.simproject.kr
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
```

### 예시 3: 경로 기반 라우팅

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-path-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - www.simproject.kr
      secretName: www-tls
  rules:
    - host: www.simproject.kr
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

## 자주 사용하는 Annotations

| Annotation | 설명 | 예시 값 |
|------------|------|---------|
| `cert-manager.io/cluster-issuer` | 인증서 발급자 | `letsencrypt-prod` |
| `traefik.ingress.kubernetes.io/router.middlewares` | CrowdSec 바운서 | `ingress-nginx-bouncer@kubernetescrd` |
| `traefik.ingress.kubernetes.io/service.serversscheme` | 백엔드 스킴 | `https` |
| `traefik.ingress.kubernetes.io/service.serverstransport` | 백엔드 TLS 설정 | `argocd-backend@kubernetescrd` |

HTTP를 HTTPS로 돌리는 설정은 Ingress annotation이 아니라 Traefik `web` entrypoint에 있다. `/.well-known/acme-challenge/`는 `allowACMEByPass`로 리다이렉트를 통과한다.

## 동작 원리

```
1. Ingress 리소스 생성
        ↓
2. Traefik이 Ingress를 자동 감지
        ↓
3. Traefik 라우터가 Host와 Path를 갱신
        ↓
4. cert-manager가 TLS 설정 감지
        ↓
5. Let's Encrypt에서 인증서 자동 발급
        ↓
6. Secret에 인증서 저장
        ↓
7. HTTPS 트래픽 처리 시작
```

## 트러블슈팅

### 인증서 발급 실패

```bash
# Challenge 상태 확인
kubectl get challenges -n <namespace>

# 상세 정보 확인
kubectl describe certificate <name> -n <namespace>
```

**일반적인 원인:**
- DNS 레코드 미설정 또는 전파 지연
- 방화벽에서 80 포트 차단
- ingressClassName 불일치

### 502 Bad Gateway

```bash
# 백엔드 서비스 확인
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>
```

**일반적인 원인:**
- 백엔드 서비스/파드 미실행
- 포트 번호 불일치
- 백엔드 프로토콜 불일치 (HTTP vs HTTPS)

### Ingress가 인식 안 됨

```bash
# Ingress Controller 로그 확인
kubectl logs -n ingress-nginx deploy/infra-traefik
```

**확인사항:**
- `ingressClassName: traefik` 설정 확인
- namespace 확인

## 체크리스트

새 Ingress 추가 시:

- [ ] `terraform/dns.tf`에 proxied A 레코드 추가 (`local.nlb_ip`)
- [ ] 비공개 서비스면 Access 애플리케이션과 `acme_challenge_hosts` 추가
- [ ] Ingress YAML 작성
- [ ] `ingressClassName: traefik` 확인
- [ ] `cert-manager.io/cluster-issuer: letsencrypt-prod` annotation 확인
- [ ] `main` 머지 후 Argo CD 동기화와 Terraform apply 확인
- [ ] `kubectl get certificate` 로 READY 확인
- [ ] 브라우저에서 HTTPS 접속 테스트
