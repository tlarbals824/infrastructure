# Terraform 인프라 관리 가이드

## ⚠️ 중요: 로컬 실행 금지

**절대 로컬에서 다음 작업을 하지 마세요:**

- ❌ `terraform.tfvars` 파일 생성
- ❌ `terraform plan` 실행
- ❌ `terraform apply` 실행
- ❌ `terraform destroy` 실행

### 이유

1. **민감 정보 노출 방지**
   - OCI API 키, Cloudflare API 토큰 등 중요한 자격 증명 보호
   - `.gitignore`에 `terraform.tfvars`가 포함되어 있지만 실수 방지

2. **잘못된 설정으로 인한 사고 방지**
   - **실제 사례 (2026-07-28)**: 로컬에서 잘못된 `compartment_ocid`로 실행하여 노드 풀이 삭제됨
   - 잘못된 변수값으로 인프라가 파괴되는 사고 예방

3. **일관성 보장**
   - 모든 변경사항이 GitHub Secrets를 통해 관리됨
   - 환경 차이로 인한 문제 방지

## ✅ 올바른 워크플로우

### 1. 변경사항 작성

```bash
# 새 브랜치 생성
git checkout -b feature/your-change

# Terraform 코드 수정
vim terraform/xxx.tf

# 포맷팅 확인
terraform fmt -check -recursive
```

### 2. PR 생성 및 머지

```bash
# 커밋 및 푸시
git add terraform/
git commit -m "feat: your change description"
git push origin feature/your-change

# PR 생성
gh pr create --title "feat: your change" --body "..."
```

### 3. GitHub Actions 자동 실행

PR이 `main` 브랜치에 머지되면 자동으로 실행됩니다:

1. **Terraform Plan** (PR 단계)
   - `.github/workflows/terraform-plan.yml`
   - 변경사항 미리보기 제공

2. **Terraform Apply** (머지 후)
   - `.github/workflows/terraform-apply.yml`
   - 실제 인프라에 적용

## 📝 Secrets 관리

모든 민감 정보는 GitHub Repository Secrets에 저장됩니다:

### OCI 관련
- `OCI_CLI_TENANCY`
- `OCI_CLI_USER`
- `OCI_CLI_FINGERPRINT`
- `OCI_CLI_KEY_CONTENT`
- `OCI_COMPARTMENT_OCID`
- `OCI_S3_ACCESS_KEY`
- `OCI_S3_SECRET_KEY`

### Cloudflare 관련
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_ACCOUNT_ID`

## 🔍 변경사항 확인 방법

### PR 단계에서 Plan 확인

PR이 생성되면 GitHub Actions가 자동으로 `terraform plan`을 실행하고 결과를 코멘트로 남깁니다.

### 머지 후 Apply 확인

```bash
# GitHub Actions 실행 상태 확인
gh run list --limit 3

# 특정 실행 로그 확인
gh run view <run-id> --log
```

## 🚨 긴급 복구 절차

만약 GitHub Actions에서 문제가 발생하고 수동 개입이 필요한 경우:

1. GitHub Secrets 확인 (설정 → Secrets and variables → Actions)
2. 필요한 경우 Secrets 업데이트
3. 빈 커밋으로 재트리거:
   ```bash
   git commit --allow-empty -m "chore: retrigger terraform apply"
   git push
   ```

## 📚 참고 자료

- [GitHub Actions 워크플로우](../.github/workflows/)
- [Terraform 코드](./)
- [Kubernetes 매니페스트](../k8s/)