output "sonarqube_instance_id" {
  value = aws_instance.sonarqube.id
}

output "sonarqube_public_ip" {
  value = aws_instance.sonarqube.public_ip
}