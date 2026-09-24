# 엣지와 인증서

공개 호스트는 `terraform/dns.tf`의 `local.public_hosts`와 `k8s/edge/hosts/<이름>/` 한 폴더다. 폴더에는 Gateway 리스너 패치, Certificate, ReferenceGrant, HTTPRoute, CrowdSec Middleware 사본이 있다. 절차는 [호스트 추가](adding-ingress.md), 구조는 [Ingress 구조](ingress-architecture.md)에 있다.

호스트를 추가할 때 DNS만 만들거나 라우트만 만들지 않는다. Access 로그인 호스트는 `/.well-known/acme-challenge/*` 바이패스도 같은 목록에서 나온다. 바이패스가 없으면 Let's Encrypt HTTP-01이 Access에 막힌다.

## Cloudflare가 돌려주는 오류

브라우저에 보이는 Cloudflare 오류는 오리진의 상태다.

| 코드 | 의미 | 이 클러스터에서 확인할 곳 |
| --- | --- | --- |
| 522 | Cloudflare가 오리진 TCP에 연결하지 못함 | NLB에 `134.185.104.125`가 붙어 있는지, Traefik 엔드포인트가 있는지 |
| 526 | 오리진 인증서 이름이 호스트와 다름. SSL은 strict | Gateway가 제시하는 Secret의 SAN |
| 403 | CrowdSec bouncer가 닫혀 있음 | LAPI 주소. 실패하면 오리진에 요청을 보내지 않는다 |
| NXDOMAIN | 레코드가 없거나 리졸버가 음성 캐시를 들고 있음 | `1.1.1.1`에는 있는데 KT `168.126.63.1`만 실패하면 음성 캐시다. SOA minimum은 1800초이고 원격으로 비울 수 없다 |

Traefik의 `no available server`는 HTTPRoute가 가리키는 Service에 ready 엔드포인트가 없을 때다. 네임스페이스를 옮기는 동안 라우트만 먼저 바뀌면 잠깐 이 문구가 나온다.

호스트 이름을 바꾸면 이전 인증서를 그대로 두지 않는다. `serverless.simproject.kr`에 `nuclio.simproject.kr` 인증서를 내면 526이다.

## 인증서

cert-manager HTTP-01은 Gateway solver다. ClusterIssuer의 parent는 `edge/public`이다. Helm 값 `config.enableGatewayAPI: true`가 있어야 `gateway-shim`이 돈다. `--feature-gates=ExperimentalGatewayAPISupport=true`는 1.17에서 이 컨트롤러를 켜지 않는다. 꺼져 있으면 로그가 `skipping disabled controller gateway-shim`이고 챌린지는 `gateway api is not enabled`다.

## Traefik과 CrowdSec

`kubernetesCRD.ingressClass: traefik`을 넣지 않는다. 그 필터가 있으면 ingress class가 없는 Middleware가 보이지 않는다.

Spread 라벨은 `app.kubernetes.io/instance=infra-traefik-edge`다. 릴리스 이름만 맞추면 두 레플리카가 한 노드에 모인다.

Middleware `bouncer`는 HTTPRoute와 같은 네임스페이스에 있어야 한다. ExtensionRef에는 네임스페이스가 없다. LAPI는 `infra-crowdsec-service.crowdsec.svc.cluster.local:8080`이다. `crowdsec-service`라는 Service는 없다. Cloudflare IPv4 목록은 Helm의 `cloudflareIps` 앵커와 Middleware 사본 두 곳이다. 한쪽만 고치면 안 된다.

Argo CD는 Gateway에서 TLS가 끝난다. `server.insecure: "true"`이고 HTTPRoute 백엔드는 `argocd-server:80`이다. 파드 IP로 HTTPS를 치면 인증서에 IP SAN이 없어 Traefik이 500을 반환한다.
