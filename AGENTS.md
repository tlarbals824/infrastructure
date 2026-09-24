# 에이전트 지침

운영 중 반복된 실수는 [docs/README.md](docs/README.md)에 주제별로 있다. 이미지를 다루면 [docs/images.md](docs/images.md), 엣지나 인증서면 [docs/edge.md](docs/edge.md), 동기화와 Terraform이면 [docs/gitops.md](docs/gitops.md), 네임스페이스와 NLB면 [docs/cluster.md](docs/cluster.md)를 읽고 고친다.

`image:`에는 레지스트리 호스트를 붙인다. 호스트가 없는 이름과 레지스트리에 없는 태그는 파드가 뜨지 않는다.
