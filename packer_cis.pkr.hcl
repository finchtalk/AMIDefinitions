variable "ami_name" {
  default = "Prod-CIS-Latest-AMZN-${formatdate("YYYY-MM-DD_HH-mm-ss", timestamp())}"
}

build {
  name    = "AWS AMI Builder - CIS"
  type    = "amazon-ebs"

  region             = var.AWS_REGION
  source_ami_filter  = {
    filters = {
      "virtualization-type" = "hvm"
      "name"                = "amzn2-ami-hvm-*-x86_64-gp2"
      "root-device-type"    = "ebs"
    }
    owners = ["137112412989", "591542846629", "801119661308"]
    most_recent = true
  }
  instance_type      = "t2.micro"
  ssh_username       = "ec2-user"
  ami_name           = var.ami_name
  ami_description    = "Amazon Linux CIS with Cloudwatch Logs agent"
  associate_public_ip_address = true
  vpc_id             = var.vpc
  subnet_id          = var.subnet

  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y python3 zip unzip",
      "sudo ln -s /usr/bin/pip3 /usr/bin/pip",
      "sudo pip install ansible==2.7.9"
    ]
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

  provisioner "ansible-local" {
    playbook_file  = "/tmp/packer-provisioner-ansible-local/playbook.yaml"
    playbook_dir   = "/tmp/packer-provisioner-ansible-local"
    galaxy_file    = "/tmp/packer-provisioner-ansible-local/requirements.yaml"
    role_paths     = ["/tmp/packer-provisioner-ansible-local/roles/common"]
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
}
