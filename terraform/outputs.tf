# =============================================================================
# Outputs
# =============================================================================
# 리소스 생성 후 이 파일에 output 블록을 추가하세요.

output "project_info" {
  description = "Project information"
  value = {
    project_name = var.project_name
    region       = "ap-chuncheon-1"
  }
}

output "cluster_id" {
  description = "OKE cluster OCID"
  value       = oci_containerengine_cluster.k8s.id
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.k8s.id} --file $HOME/.kube/config --region ap-chuncheon-1 --token-version 2.0.0"
}
