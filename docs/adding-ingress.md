# Ingress 추가 가이드

새로운 서비스에 도메인을 연결하고 HTTPS를 적용하는 방법입니다.

## 사전 요구사항

- nginx Ingress Controller 설치됨
- cert-manager 설치됨
- letsencrypt-prod ClusterIssuer 생성됨

## 추가 절차

### 1단계: OCI DNS에 A 레코드 추가

OCI 콘솔에서:

```
Networking → DNS Management → simproject.kr Zone
→ Add Record:
   - Type: A
   - Name: <subdomain>  (예: app, api, dashboard)
   - Address: 158.179.174.184  (NLB IP)
   - TTL: 300
```

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
  ingressClassName: nginx
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

```bash
kubectl apply -f ingress.yaml
```

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
  ingressClassName: nginx
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
    # API 요청 body 크기 제한 증가
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
spec:
  ingressClassName: nginx
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
  ingressClassName: nginx
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
| `nginx.ingress.kubernetes.io/proxy-body-size` | 요청 body 크기 제한 | `50m` |
| `nginx.ingress.kubernetes.io/ssl-redirect` | HTTP→HTTPS 리다이렉트 | `"true"` |
| `nginx.ingress.kubernetes.io/backend-protocol` | 백엔드 프로토콜 | `"HTTPS"` |
| `nginx.ingress.kubernetes.io/rewrite-target` | URL 재작성 | `/` |
| `nginx.ingress.kubernetes.io/cors-allow-origin` | CORS 허용 origin | `"*"` |

## 동작 원리

```
1. Ingress 리소스 생성
        ↓
2. nginx Ingress Controller가 자동 감지
        ↓
3. nginx 설정 업데이트 (server_name, location 등)
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
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

**확인사항:**
- `ingressClassName: nginx` 설정 확인
- namespace 확인

## 체크리스트

새 Ingress 추가 시:

- [ ] OCI DNS에 A 레코드 추가
- [ ] Ingress YAML 작성
- [ ] `ingressClassName: nginx` 확인
- [ ] `cert-manager.io/cluster-issuer: letsencrypt-prod` annotation 확인
- [ ] `kubectl apply` 실행
- [ ] `kubectl get certificate` 로 READY 확인
- [ ] 브라우저에서 HTTPS 접속 테스트
