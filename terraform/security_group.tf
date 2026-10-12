resource "aws_security_group" "bastion" {
  name        = "sonarqube-bastion-sg"
  description = "SSH access from approved public IP only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from approved IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sonarqube-bastion-sg"
  }
}

resource "aws_security_group" "sonarqube" {
  name        = "sonarqube-private-sg"
  description = "Private SonarQube access from Bastion only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "SonarQube UI and API from Bastion"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sonarqube-private-sg"
  }
}