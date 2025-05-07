variable "vpc" {
  default = "${env("BUILD_VPC_ID")}"
}

variable "subnet" {
  default = "${env("BUILD_SUBNET_ID")}"
}

variable "aws_region" {
  default = "${env("AWS_REGION")}"
}

variable "ami_name" {
  default = "Prod-CIS-Latest-AMZN-${formatdate("2006-01-02 15_04_05", timestamp())}"
}

builder "amazon-ebs" {
  name               = "AWS AMI Builder - CIS"
  region             = var.aws_region
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
    }
    owners = [
      "137112412989", "591542846629", "801119661308",
      "102837901569", "013907871322", "206029621532",
      "286198878708", "443319210888"
    ]
    most_recent = true
  }
  instance_type               = "t2.micro"
  ssh_username                = "ec2-user"
  ami_name                    = var.ami_name
  tags = {
    Name = var.ami_name
  }
  run_tags = {
    Name = var.ami_name
  }
  run_volume_tags = {
    Name = var.ami_name
  }
  snapshot_tags = {
    Name = var.ami_name
  }
  ami_description            = "Amazon Linux CIS with Cloudwatch Logs agent"
  associate_public_ip_address = true
  vpc_id                     = var.vpc
  subnet_id                  = var.subnet
}

provisioner "file" {
  source      = "ansible/playbook.yaml"
  destination = "/tmp/packer-provisioner-ansible-local/playbook.yaml"
}

provisioner "file" {
  source      = "ansible/requirements.yaml"
  destination = "/tmp/packer-provisioner-ansible-local/requirements.yaml"
}

provisioner "file" {
  source      = "ansible/roles"
  destination = "/tmp/packer-provisioner-ansible-local/roles"
}

provisioner "shell" {
  inline = [
    "ansible-galaxy install -r /tmp/packer-provisioner-ansible-local/requirements.yaml --force --ignore-errors"
  ]
}

provisioner "ansible-local" {
  playbook_file   = "/tmp/packer-provisioner-ansible-local/playbook.yaml"
  playbook_dir    = "/tmp/packer-provisioner-ansible-local"
  galaxy_file     = "/tmp/packer-provisioner-ansible-local/requirements.yaml"
  role_paths      = ["/tmp/packer-provisioner-ansible-local/roles/common"]
  extra_arguments = [
    "--connection=local",
    "--inventory=localhost,"
  ]
}

provisioner "shell" {
  inline = [
    "rm .ssh/authorized_keys ; sudo rm /root/.ssh/authorized_keys"
  ]
}
