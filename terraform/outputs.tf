output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "sonarqube_private_ip" {
  value = aws_instance.sonarqube.private_ip
}

output "sonarqube_instance_id" {
  value = aws_instance.sonarqube.id
}