output "cluster_id" {
  description = "Regional Kapsule cluster ID."
  value       = scaleway_k8s_cluster.main.id
}

output "cluster_name" {
  description = "Kapsule cluster name."
  value       = scaleway_k8s_cluster.main.name
}

output "cluster_api_url" {
  description = "Public Kapsule API server URL protected by the configured ACL."
  value       = scaleway_k8s_cluster.main.apiserver_url
}

output "vpc_id" {
  description = "Regional VPC ID."
  value       = scaleway_vpc.main.id
}

output "private_network_id" {
  description = "Regional Private Network ID."
  value       = scaleway_vpc_private_network.main.id
}

output "private_network_cidr" {
  description = "IPv4 CIDR assigned to the Private Network."
  value       = var.private_network_cidr
}

output "pod_cidr" {
  description = "IPv4 CIDR assigned to Kubernetes pods."
  value       = var.pod_cidr
}

output "service_cidr" {
  description = "IPv4 CIDR assigned to Kubernetes services."
  value       = var.service_cidr
}

output "public_gateway_id" {
  description = "Zonal Public Gateway ID."
  value       = scaleway_vpc_public_gateway.main.id
}

output "public_gateway_ip" {
  description = "Public egress address of the Public Gateway."
  value       = scaleway_vpc_public_gateway_ip.main.address
}

output "kubeconfig" {
  description = "Kubeconfig used by the validation script. Do not print or persist it."
  value       = scaleway_k8s_cluster.main.kubeconfig[0].config_file
  sensitive   = true
}
