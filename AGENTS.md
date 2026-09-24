# 에이전트 지침

## 컨테이너 이미지

이 클러스터는 short name을 거부한다. `image:` 값에는 레지스트리 호스트를 항상 붙인다.

- Docker Hub 공식 이미지: `docker.io/library/<name>:<tag>`
- Docker Hub 그 외: `docker.io/<owner>/<name>:<tag>`
- 그 외 레지스트리는 `quay.io/...`처럼 호스트를 그대로 적는다.

`busybox:1.36`, `bitnami/kubectl:1.32.4`처럼 호스트가 없는 이름은 파드가 `ImageInspectError`로 뜨지 않는다. 태그도 그 레지스트리에 실제로 있는 값만 쓴다. 없는 태그는 `manifest unknown`으로 실패한다.

## 함수 이미지 레지스트리

Nuclio 대시보드에서 코드를 배포하면 Kaniko가 함수 이미지를 푸시한다. `registry.pushPullUrl` 이 비어 있으면 `nuclio/processor-<name>` 을 Docker Hub로 푸시하고 `UNAUTHORIZED` 로 실패한다. 푸시 대상은 `registry.crowdsec.svc.cluster.local:5000` 이다. 데이터는 `crowdsec` 네임스페이스의 `core-pvc` subPath `registry` 에 있고, LAPI와 같은 노드에 둔다. 워커 노드는 CoreDNS를 쓰지 않으므로 DaemonSet `registry-node-config` 가 그 이름을 `/etc/hosts` 에 넣고 CRI-O insecure registry로 등록한다.
