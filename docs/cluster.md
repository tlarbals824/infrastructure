# 클러스터 제약

리전은 `ap-chuncheon-1`이다. 워커는 ARM A1 두 대(각 2 OCPU, 12GB)이고 증설 여유가 없다. CNI는 Flannel이라 NetworkPolicy가 적용되지 않는다. Flannel을 바꾸거나 노드 풀을 fault domain으로 나누는 작업은 노드를 다시 만든다. 이 문서의 유지보수 범위가 아니다.

Kubernetes API 6443은 IP 제한을 두지 않는다. 로그인이 게이트다.

## NLB는 하나

공개 오리진은 Traefik Service `edge/infra-traefik`의 OCI NLB 하나다. 예약 주소는 `134.185.104.125`다. Gateway `public`도 이 주소를 쓴다. 두 번째 로드밸런서를 만들지 않는다.

이 Service를 다른 네임스페이스로 옮기면 이전 Service가 예약 IP를 계속 잡는다. 새 Service는 `<pending>`이 되고 Cloudflare는 522를 반환한다. 이전 Service를 지운 뒤에 새 Service에 같은 주소가 붙는지 확인한다.

보안 목록은 80/443과 워커 NodePort `30000–32767`을 Cloudflare IPv4만 허용한다. NLB 헬스체크는 VCN `10.0.0.0/16`이다. 작업 머신에서 그 IP의 443으로 직접 붙으면 응답이 없다. 오리진 확인은 클러스터 안 Service로 한다.

## 네임스페이스는 역할 이름

제품 이름으로 네임스페이스를 만들지 않는다. 프록시를 바꿀 때마다 네임스페이스를 옮기면 NLB IP와 Sealed Secret이 같이 움직인다.

| 네임스페이스 | 역할 |
| --- | --- |
| `edge` | 공개 Gateway와 Traefik |
| `serverless` | Nuclio 대시보드와 함수 |
| `argocd` | Argo CD |
| `crowdsec` | CrowdSec과 공유 디스크 |

`nuclio`, `ingress-nginx`, `traefik` 네임스페이스는 쓰지 않는다.

## 디스크

`crowdsec/core-pvc`는 OCI 블록 볼륨 50Gi, `ReadWriteOnce`다. 클레임은 네임스페이스 밖 파드가 마운트할 수 없고, 한 노드에만 붙는다. 레지스트리 subPath `registry`와 CrowdSec LAPI는 같은 노드에 둔다. `crowdsec`은 역할 이름이 아니다. 디스크가 그 네임스페이스에 있어서 소비자도 거기 있다.

subPath를 쓰는 CrowdSec 값은 `cleanup-subpath-dirs` init container와 같이 둔다. `scripts/lint_crowdsec_convention.py`가 검사한다. 그 정리는 `config/`와 `crowdsec/`만 지운다. `registry/` 데이터는 지우지 않는다.
