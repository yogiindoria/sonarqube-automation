data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.bastion_instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "sonarqube-bastion"
  }
}


resource "aws_instance" "sonarqube" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.sonarqube_instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.sonarqube.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "sonarqube-server"
  }
}
