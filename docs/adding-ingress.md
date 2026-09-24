# 호스트 추가 가이드

새로운 서비스에 도메인을 연결하고 HTTPS를 적용하는 방법입니다.

## 사전 요구사항

- Traefik이 `Gateway/public`을 받고 있음
- cert-manager와 `letsencrypt-prod` ClusterIssuer가 있음

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

### 2단계: Gateway 리스너, 인증서, HTTPRoute

공개 라우트는 `k8s/infra/ingress-nginx/gateway.yaml`의 `Gateway/public`에
호스트 리스너를 추가합니다. 포트는 Traefik entrypoint인 `8443`입니다.

```yaml
- name: https-app
  protocol: HTTPS
  port: 8443
  hostname: app.simproject.kr
  allowedRoutes:
    namespaces:
      from: All
  tls:
    mode: Terminate
    certificateRefs:
      - group: ""
        kind: Secret
        name: app-tls
        namespace: <namespace>
```

서비스 네임스페이스에는 `Certificate`, Gateway가 Secret을 읽게 하는 `ReferenceGrant`,
`HTTPRoute`를 둡니다. CrowdSec Middleware는 `k8s/components/crowdsec-bouncer`를
그 kustomization의 component로 넣습니다.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
  namespace: <namespace>
spec:
  parentRefs:
    - name: public
      namespace: ingress-nginx
      sectionName: https-app
  hostnames:
    - app.simproject.kr
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      filters:
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: bouncer
      backendRefs:
        - name: <service-name>
          port: <port>
```

인증서는 Ingress annotation이 아니라 `Certificate`입니다. `dnsNames`에 같은 호스트를 넣습니다.
cert-manager의 HTTP-01은 임시 Ingress를 만들므로 ClusterIssuer의 `ingressClassName: traefik`은 유지합니다.

### 3단계: 적용

매니페스트를 저장소에 커밋하고 `main`에 머지합니다. Argo CD가 자동으로 동기화합니다.
Terraform 변경(DNS, Access)은 머지 후 GitHub Actions가 apply 합니다.

### 4단계: 확인

```bash
kubectl get httproute -n <namespace>
kubectl get certificate -n <namespace>
```

인증서가 `READY: True`가 되기까지 1-2분 걸립니다.

## 동작 원리

```
1. Gateway 리스너와 HTTPRoute 생성
        ↓
2. Traefik이 Gateway API를 감지해 라우터를 만든다
        ↓
3. Certificate가 발급 대상 호스트를 가진다
        ↓
4. cert-manager가 HTTP-01로 Let's Encrypt에 요청한다
        ↓
5. Secret에 인증서 저장
        ↓
6. Gateway 리스너가 그 Secret으로 HTTPS를 받는다
```

HTTP를 HTTPS로 돌리는 설정은 Traefik `web` entrypoint에 있다. `/.well-known/acme-challenge/`는 `allowACMEByPass`로 리다이렉트를 통과한다.

## 트러블슈팅

### 인증서 발급 실패

```bash
kubectl get challenges -n <namespace>
kubectl describe certificate <name> -n <namespace>
```

**일반적인 원인:**

- DNS 레코드가 없거나 아직 퍼지지 않음
- Access가 ACME 경로를 막고 `acme_challenge_hosts`에 호스트가 없음
- Gateway 리스너가 그 Secret을 가리키지 않음

### 502 Bad Gateway

```bash
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>
```

**일반적인 원인:**

- 백엔드 서비스나 파드가 없음
- HTTPRoute의 포트가 Service 포트와 다름

### 호스트가 열리지 않음

```bash
kubectl get gateway public -n ingress-nginx
kubectl get httproute -n <namespace>
kubectl logs -n ingress-nginx deploy/infra-traefik
```

**확인사항:**

- HTTPRoute `parentRefs.sectionName`이 Gateway 리스너 이름과 같음
- ReferenceGrant가 Gateway의 Secret 참조를 허용함

## 체크리스트

- [ ] `terraform/dns.tf`에 proxied A 레코드 추가 (`local.nlb_ip`)
- [ ] 비공개 서비스면 Access 애플리케이션과 `acme_challenge_hosts` 추가
- [ ] `Gateway/public`에 HTTPS 리스너 추가
- [ ] `Certificate`, `ReferenceGrant`, `HTTPRoute` 추가
- [ ] `k8s/components/crowdsec-bouncer` component 포함
- [ ] `main` 머지 후 Argo CD 동기화와 Terraform apply 확인
- [ ] `kubectl get certificate` 로 READY 확인
- [ ] 브라우저에서 HTTPS 접속 테스트
