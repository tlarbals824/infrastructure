# =============================================================================
# Outputs
# =============================================================================
# 리소스 생성 후 이 파일에 output 블록을 추가하세요.

output "project_info" {
  description = "Project information"
  value = {
    project_name = var.project_name
    environment  = var.environment
    region       = var.region
  }
}
