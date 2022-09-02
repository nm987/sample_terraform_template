locals {
  app_name = "httpd"
}

source "amazon-ebs" "web-server" {
  ami_name      = "web_server-${formatdate("YYYYMMDD'_'hhmmss", timestamp())}"
  instance_type = "t2.micro"
  region        = "us-west-2"
  source_ami_filter {
    filters = {
      virtualization-type                = "hvm"
      architecture                       = "x86_64"
      name                               = "amzn2-ami-kernel-5.10-hvm-*"
      root-device-type                   = "ebs"
      "block-device-mapping.volume-type" = "gp2"
    }
    owners      = ["amazon"]
    most_recent = true
  }
  ssh_username = "ec2-user"
  tags = {
    Name  = "web_server-${formatdate("YYYYMMDD'_'hhmmss", timestamp())}"
    Group = local.app_name
    Date  = timestamp()
  }
}

build {
  sources = ["source.amazon-ebs.web-server"]
  provisioner "shell" {
    inline = [
      "sudo rpm -Uvh https://yum.puppet.com/puppet7-release-el-7.noarch.rpm",
      "sudo yum -y update",
      "sudo yum -y install httpd",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo yum -y install puppet",
      "sudo systemctl start puppet",
      "sudo systemctl enable puppet"
    ]

  }
}