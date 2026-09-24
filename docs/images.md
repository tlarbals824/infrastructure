# 이미지

워커는 레지스트리 호스트가 없는 이미지 이름을 거부한다. `image:`에는 호스트를 붙인다.

- Docker Hub 공식 이미지: `docker.io/library/<name>:<tag>`
- Docker Hub 그 외: `docker.io/<owner>/<name>:<tag>`
- 그 외는 `quay.io/...`, `gcr.io/...`처럼 호스트를 그대로 적는다.

태그는 그 레지스트리에 있는 값만 쓴다.

| 실패한 참조 | 결과 |
| --- | --- |
| `busybox:1.36` | `ImageInspectError` |
| `docker.io/bitnami/kubectl:1.32.4` | `manifest unknown` |
| `docker.io/rancher/kubectl:v1.33.13` | pull은 된다. 이미지에 bash가 없어 `command: ["bash"]`는 실패한다 |

init 컨테이너의 busybox는 `docker.io/library/busybox:1.36`이다. 이 이미지에는 `nslookup`이 있고 `getent`는 없다.

## Nuclio 함수 이미지

대시보드에서 코드를 배포하면 Kaniko가 함수 이미지를 푸시한다. `registry.pushPullUrl`이 비어 있으면 `nuclio/processor-<name>`을 Docker Hub로 밀고 `UNAUTHORIZED`가 난다. 대상은 `registry.crowdsec.svc.cluster.local:5000`이다. `scripts/lint_nuclio_registry.py`가 비어 있는 값을 실패로 처리한다.

레지스트리는 HTTP다. `dashboard.build.insecurePushRegistry`가 켜져 있어야 푸시된다. 데이터는 `crowdsec/core-pvc`의 subPath `registry`다. 배치 제약은 [클러스터 제약](cluster.md)에 있다.

워커의 DNS는 VCN 리졸버 `169.254.169.254`라서 `*.svc.cluster.local`을 풀지 못한다. DaemonSet `registry-node-config`가 ClusterIP를 `/etc/hosts`에 넣고 CRI-O insecure registry로 등록한다. 이 설정이 없으면 kubelet은 `no such host`로 `ImagePullBackOff`가 된다. 레지스트리 안의 pull은 그 다음에야 의미가 있다.

노드는 arm64다. Nuclio 기본 베이스 `gcr.io/iguazio/alpine:3.20`의 루트 파일시스템은 x86_64다. arm64 프로세서가 그 위에 올라가면 `exec /usr/local/bin/processor: no such file or directory`로 죽는다. `exec format error`와 메시지가 다르다. platform `runtimeBaseImages`는 golang과 shell에 `gcr.io/iguazio/arm64v8/alpine:3.20`, nodejs에 `gcr.io/iguazio/arm64v8/node:20`을 쓴다. 대시보드와 컨트롤러 이미지는 `quay.io/nuclio/*:1.15.27-arm64`다.

함수는 `serverless` 네임스페이스에만 있다. 컨트롤러 RBAC가 namespaced라 다른 네임스페이스의 함수는 보이지 않는다. 배포 절차는 [Nuclio](nuclio.md)에 있다.
