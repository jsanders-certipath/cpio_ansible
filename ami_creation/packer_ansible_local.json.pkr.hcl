packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

variable "ami_name" {
  type    = string
  default = "ubuntu2004-lts-amd64" 
}

variable "ansible_roles_path" {
  type    = string
  default = "ansible/galaxy"
}

variable "aws_region" {
  type    = string
  default = "${env("AWS_REGION")}"
}

variable "build_version" {
  type    = string
  default = "${env("VERSION")}"
}

variable "git_commit_id" {
  type    = string
  default = "${env("GITHUB_SHA")}"
}

variable "subnet" {
  type    = string
  default = "${env("BUILD_SUBNET_ID")}"
}

variable "vpc" {
  type    = string
  default = "${env("BUILD_VPC_ID")}"
}

variable "ami_users" {
  type    = list(string)
  default = []
}

variable "arch" {
  type    = string
  default = "${env("RUNNER_ARCH")}"
}

data "amazon-ami" "autogenerated_1" {
  filters = {
    name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = "${var.aws_region}"
}

source "amazon-ebs" "AWS_AMI_Builder" {
  ami_description             = var.ami_name
  ami_name                    = var.ami_name
  ami_users                   = var.ami_users
  associate_public_ip_address = "true"
  ena_support                 = true
  encrypt_boot                = false
  instance_type               = "t3a.micro"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/sda1"
    volume_size           = 15
    volume_type           = "gp3"
  }
  region = "${var.aws_region}"
  run_tags = {
    Name = "${var.ami_name}"
  }
  run_volume_tags = {
    Name = "${var.ami_name}"
  }
  security_group_filter {
    filters = {
      "tag:Name" = "packer-build-sg"
    }
  }
  snapshot_tags = {
    Name = "${var.ami_name}"
  }
  source_ami   = "${data.amazon-ami.autogenerated_1.id}"
  ssh_username = "ubuntu"
  subnet_id    = "${var.subnet}"
  tags = {
    "Git Commit Id" = "${var.git_commit_id}"
    Name            = "${var.ami_name}"
  }
  vpc_id = "${var.vpc}"
}

build {
  sources = ["source.amazon-ebs.AWS_AMI_Builder"]

  provisioner "shell" {
    script       = "ami_creation/scripts/pre-work.sh"
    pause_before = "10s"
    timeout      = "10s"
  }

  provisioner "ansible-local" {
    command           = "ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 ANSIBLE_PIPELINING=True ansible-playbook"
    extra_arguments   = ["--extra-vars \"ami_name='${var.ami_name}'\""]
    galaxy_file       = "ami_creation/requirements.yaml"
    galaxy_roles_path = "roles"
    playbook_dir      = "ami_creation"
    playbook_file     = "ami_creation/playbook.yaml"
    role_paths        = ["ami_creation/roles/common"]
  }

  provisioner "shell" {
    script       = "ami_creation/scripts/post-work.sh"
    pause_before = "10s"
    timeout      = "10s"
  }

}
