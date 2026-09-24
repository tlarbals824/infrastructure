# GitOps와 Terraform

클러스터는 `main`만 본다. 브랜치에 커밋해도 Argo CD와 Terraform apply는 돌지 않는다. 적용은 머지 다음이다.

## 동기화 순서

Helm 값이 Application 매니페스트 안에 있으면 `root`를 먼저 동기화한다. 자식을 먼저 동기화하면 이전 값이 적용된다. 이어서 돌린 동기화는 `another operation is already in progress`로 실패할 수 있다. 끝난 뒤에 다시 실행한다.

`argocd --core`는 kubeconfig 컨텍스트의 네임스페이스가 `argocd`일 때만 동작한다. `kubectl config view --raw --minify`로 임시 파일을 만들고 네임스페이스를 맞춘다. 공개 API와 `localhost:38080` 토큰은 이 용도로 쓰지 않는다. 임시 kubeconfig는 확인이 끝나면 지운다.

`gh pr merge`에는 PR 번호를 붙인다. 번호를 빼면 저장소에 묶인 다른 PR이 머지된다.

## Terraform

로컬에서 `terraform plan`, `apply`, `destroy`를 실행하지 않고 `terraform.tfvars`도 만들지 않는다. 잘못된 compartment로 로컬 apply를 해서 노드 풀이 삭제된 적이 있다. 절차는 [Terraform 가이드](../terraform/README.md)에 있다.

plan/apply는 GitHub Actions다. `terraform/**`가 바뀐 PR만 plan이 돈다. 매니페스트만 바꾼 PR의 게이트는 Kubernetes Checks다. lock 파일 `.terraform.lock.hcl`은 커밋하고, Linux와 macOS `h1` 해시를 모두 넣는다. macOS 해시만 있으면 Ubuntu `terraform validate`가 실패한다. `.terraform/`, tfvars, tfstate, pem은 커밋하지 않는다.

OCI provider는 `~> 8.24.0`, Cloudflare provider는 `~> 4.52.8`을 유지한다. Cloudflare v5는 속성 이름이 바뀐다.

## 매니페스트

Kustomize 컴포넌트는 디렉터리 밖 파일을 읽지 못한다. 심볼릭 링크도 거부된다. 컴포넌트에 `namespace:`를 쓰면 이미 모인 리소스까지 그 네임스페이스로 바뀌어 ReferenceGrant 이름이 충돌한다. 각 리소스의 `metadata.namespace`를 직접 적는다.

Sealed Secret은 이름과 네임스페이스에 묶인다. 네임스페이스를 바꾸면 컨트롤러 공개 키로 다시 봉인한다. 평문 Secret과 개인 키는 커밋하지 않고 로컬에서도 바로 지운다. Sealed Secrets 차트 저장소는 `https://bitnami.github.io/sealed-secrets`다. 예전 `bitnami-labs.github.io` 주소는 404다.

Traefik CRD를 가진 별도 Application을 지우기 전에 `argoproj.io/resources-finalizer`를 떼야 한다. 파이널라이저가 있으면 Argo가 CRD까지 지운다. Helm 자체는 차트 삭제 때 CRD를 지우지 않는다.
