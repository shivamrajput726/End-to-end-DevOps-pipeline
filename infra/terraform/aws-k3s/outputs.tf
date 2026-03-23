output "public_ip" {
  value       = aws_instance.k3s.public_ip
  description = "EC2 public IP"
}

output "ssh_command" {
  value       = "ssh -i <path-to-private-key> ubuntu@${aws_instance.k3s.public_ip}"
  description = "SSH command (update key path)."
}

output "kubeconfig_scp_command" {
  value       = "scp -i <path-to-private-key> ubuntu@${aws_instance.k3s.public_ip}:/etc/rancher/k3s/k3s.yaml ./kubeconfig.yaml"
  description = "Copy kubeconfig locally (update key path)."
}

