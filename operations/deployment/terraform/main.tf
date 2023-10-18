resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

// Creates an ec2 key pair using the tls_private_key.key public key
resource "aws_key_pair" "aws_key" {
  key_name   = "${var.aws_resource_identifier_supershort}-ec2kp-${random_string.random.result}"
  public_key = tls_private_key.key.public_key_openssh
}

// Creates a secret manager secret for the public key
resource "aws_secretsmanager_secret" "keys_sm_secret" {
  count              = var.create_keypair_sm_entry ? 1 : 0
  name   = "${var.aws_resource_identifier_supershort}-sm-${random_string.random.result}"
}
 
resource "aws_secretsmanager_secret_version" "keys_sm_secret_version" {
  count     = var.create_keypair_sm_entry ? 1 : 0
  secret_id = aws_secretsmanager_secret.keys_sm_secret[0].id
  secret_string = <<EOF
   {
    "key": "public_key",
    "value": "${sensitive(tls_private_key.key.public_key_openssh)}"
   },
   {
    "key": "private_key",
    "value": "${sensitive(tls_private_key.key.private_key_openssh)}"
   }
EOF
}

resource "random_string" "random" {
  length    = 5
  lower     = true
  special   = false
  numeric   = false
}

resource "aws_vpc" "main" {
 cidr_block = "10.0.0.0/16"
 
 tags = {
   Name = "Project VPC"
 }
}

variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

resource "aws_subnet" "public_subnets" {
 count      = length(var.public_subnet_cidrs)
 vpc_id     = aws_vpc.main.id
 cidr_block = element(var.public_subnet_cidrs, count.index)
 
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}

resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.main.id
 
 tags = {
   Name = "Project VPC IG"
 }
}

resource "aws_route_table" "project_rt" {
 vpc_id = aws_vpc.main.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
 }
 
 tags = {
   Name = "Project Route Table"
 }
}

resource "aws_route_table_association" "public_subnet_asso" {
 count = length(var.public_subnet_cidrs)
 subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
 route_table_id = aws_route_table.project_rt.id
}

# data "aws_ami" "amzn-linux-2023-ami" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["al2023-ami-2023.*-x86_64"]
#   }
# }

# resource "aws_instance" "example" {
#   count = length(var.public_subnet_cidrs)
#   ami           = "ami-02a9d4cace1c5a38a"
#   instance_type = "t3.micro"
#   subnet_id     = element(aws_subnet.public_subnets[*].id, count.index)

#   tags = {
#     Name = "Project ec2 insance"
#   }
# }
 


resource "aws_iam_instance_profile" "ec2_profile" {
  name = var.aws_resource_identifier
  role = aws_iam_role.ec2_role.name
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_instance" "server" {
  # ubuntu
  count = length(var.public_subnet_cidrs)
  ami                         = var.aws_ami_id != "" ? var.aws_ami_id : data.aws_ami.ubuntu.id
  availability_zone           = local.preferred_az
  subnet_id                   = element(aws_subnet.public_subnets[*].id, count.index)
  instance_type               = var.ec2_instance_type
  associate_public_ip_address = var.ec2_instance_public_ip
  vpc_security_group_ids      = [aws_security_group.ec2_security_group.id]
  key_name                    = aws_key_pair.aws_key.key_name
  monitoring                  = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  root_block_device {
    volume_size = tonumber(var.ec2_volume_size)
  }
  tags = {
    Name = "${var.aws_resource_identifier} - Instance"
  }
}

data "aws_instance" "server" {
  filter {
    name   = "dns-name"
    values = [aws_instance.server.public_dns]
  }
}

output "instance_public_dns" {
  description = "Public DNS address of the EC2 instance"
  value       = var.ec2_instance_public_ip ? aws_instance.server.public_dns : "EC2 Instance doesn't have public DNS"
}
