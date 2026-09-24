# 운영 메모

이 클러스터에서 같은 실수가 반복된 내용을 주제별로 적는다. 호스트를 추가하거나 구조를 볼 때는 절차 문서를 본다.

## 절차

- [호스트 추가](adding-ingress.md)
- [Ingress 구조](ingress-architecture.md)
- [Nuclio](nuclio.md)
- [Terraform](../terraform/README.md)

## 실수 방지

- [클러스터 제약](cluster.md): NLB 하나, 네임스페이스 이름, 디스크, 건드리면 안 되는 것
- [GitOps와 Terraform](gitops.md): 머지 전 클러스터는 안 바뀜, 동기화 순서, lock, Sealed Secret
- [이미지](images.md): 레지스트리 호스트, 태그, Nuclio 빌드, arm64 베이스
- [엣지와 인증서](edge.md): Cloudflare 522/526/403, Gateway HTTP-01, CrowdSec
