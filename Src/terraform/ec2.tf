############################
# AMI (Ubuntu 22.04 LTS)
############################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################
# Security Groups
############################
resource "aws_security_group" "master" {
  name   = "jenkins-master-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-master-sg"
  }
}

resource "aws_security_group" "worker" {
  name   = "jenkins-worker-sg"
  vpc_id = aws_vpc.main.id

  # egress all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-worker-sg"
  }
}

# Allow SSH to worker from master SG
resource "aws_security_group_rule" "worker_ssh_from_master" {
  type                     = "ingress"
  description              = "SSH from master SG"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.worker.id
  source_security_group_id = aws_security_group.master.id
}

############################
     # Cloud-init for SSH key
############################
locals {
  user_pubkey = trimspace(file(var.public_key_path))
}

############################
# EC2 Instances
############################
resource "aws_instance" "master" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.master_instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.master.id]

  user_data = templatefile("${path.module}/templates/cloudinit-user.yaml", {
    public_key = local.user_pubkey
  })

  tags = {
    Name = "jenkins-master"
  }
}

resource "aws_instance" "worker" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.worker_instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.worker.id]
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/templates/cloudinit-user.yaml", {
    public_key = local.user_pubkey
  })

  # Spot instance: one-time + terminate (valid combo)
  instance_market_options {
    market_type = "spot"

    spot_options {
        spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
    }
  }

  tags = {
    Name = "jenkins-worker"
  }
}

############################
# Ansible inventory (hosts.txt)
############################
resource "null_resource" "ensure_ansible_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/../ansible"
  }
}

resource "local_file" "inventory" {
  depends_on = [
    null_resource.ensure_ansible_dir,
    aws_instance.master,
    aws_instance.worker
  ]

  filename = "${path.module}/../ansible/hosts.txt"
  content  = templatefile("${path.module}/templates/hosts.tpl", {
    master_public_ip  = aws_instance.master.public_ip
    worker_private_ip = aws_instance.worker.private_ip
  })
}                                                                               