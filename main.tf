terraform {
  backend "s3" {

  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.2.0"
}

data "aws_caller_identity" "current_account" {

}

data "vault_generic_secret" "aws_db" {
  path = "secret/aws/db"
}

data "vault_generic_secret" "aws_ssh_key" {
  path = "secret/aws/ssh_key"
}

data "aws_ami" "web_server" {
  most_recent = true
  owners      = [data.aws_caller_identity.current_account.account_id]

  filter {
    name   = "name"
    values = ["web_server-*"]
  }

}