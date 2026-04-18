terraform {
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "lab_bucket" {
  bucket = "lab1-insecure-demo-bucket-123456"

  tags = {
    Name = "lab1-insecure-demo-bucket"
  }
}

resource "aws_s3_bucket_acl" "lab_bucket_acl" {
  bucket = aws_s3_bucket.lab_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "lab_bucket_pab" {
  bucket = aws_s3_bucket.lab_bucket.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_security_group" "lab_sg" {
  name        = "lab1-open-ssh"
  description = "Open SSH to the world"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}