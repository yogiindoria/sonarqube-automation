data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "sonarqube" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = "t3.small"

  key_name                    = "VM2"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.sonarqube.id]
  associate_public_ip_address = true

  user_data = file("${path.module}/../scripts/install-sonarqube.sh")

  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "sonarqube-server"
  }
}