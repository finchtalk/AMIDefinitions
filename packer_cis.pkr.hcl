variable "aws_region" {
  default = "ap-southeast-1"
}

variable "ami_name" {
  default = "cis-hardened-ami"
}

source "amazon-ebs" "cis_ami" {
  region                  = var.aws_region
  instance_type           = "t2.micro"
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    most_recent = true
    owners      = ["137112412989"]
  }
  ssh_username            = "ec2-user"
  ami_name                = "${var.ami_name}-${formatdate("20060102-150409", timestamp())}"
  # Adding tags to the AMI
  tags = {
    Name = "${var.ami_name}-${formatdate("20060102-150409", timestamp())}"
    name = "${var.ami_name}-${formatdate("20060102-150409", timestamp())}"
  }
}

build {
  name    = "cis_build"
  sources = [
    "source.amazon-ebs.cis_ami"
  ]

provisioner "shell" {
  inline = [
    "mkdir -p /home/ec2-user/ansible/roles", 
    "chmod -R 777 /home/ec2-user/ansible/roles",
    "sudo amazon-linux-extras enable ansible2",
    "sudo yum update -y",  # Ensure the system is up-to-date
    # Install basic utilities, retrying if yum is locked
    "for i in {1..5}; do",
    "  sudo yum install -y zip unzip git gcc make python3-pip python3-devel dnf && break || echo 'yum is locked, retrying...';",
    "  sleep 10;",
    "done",
    "sudo amazon-linux-extras enable python3.8",
    "sudo yum install -y ansible",
    "echo 'Installation completed!'",
    "ansible --version"
  ]
}


  provisioner "file" {
    source      = "ansible/playbook.yaml"
    destination = "/home/ec2-user/ansible/playbook.yaml"
  }

  provisioner "file" {
    source      = "ansible/roles/"
    destination = "/home/ec2-user/ansible/roles"
  }

  provisioner "file" {
    source      = "ansible/ansible.cfg"
    destination = "/home/ec2-user/ansible.cfg"
  }

  provisioner "shell" {
    inline = [
      "sudo chmod -R 755 /home/ec2-user/ansible.cfg",
      "ls -ltrh /home/ec2-user/ansible/roles",
      "export ANSIBLE_CONFIG=/home/ec2-user/ansible.cfg",
      "sudo ansible-playbook /home/ec2-user/ansible/playbook.yaml -i localhost, -c local"
    ]
  }
  # Install Trivy and scan the instance
  provisioner "shell" {
    inline = [
      "echo 'Installing Trivy...'",
      "wget -qO- https://github.com/aquasecurity/trivy/releases/latest/download/trivy_0.49.1_Linux-64bit.tar.gz | tar xz -C /usr/local/bin",
      "chmod +x /usr/local/bin/trivy",
      "echo 'Running Trivy image scan on base OS packages...'",
      "trivy rootfs --severity CRITICAL,HIGH,MEDIUM --format table --output /home/ec2-user/trivy_scan_report.txt /",
      "echo 'Trivy scan completed.'"
    ]
  }

  # Download the Trivy scan report to local machine
  provisioner "file" {
    direction   = "download"
    source      = "/home/ec2-user/trivy_scan_report.txt"
    destination = "./trivy_scan_report.txt"
  }
}
