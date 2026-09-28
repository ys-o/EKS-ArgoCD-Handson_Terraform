#VPC
resource "aws_vpc" "eksargocd_vpc" {
  cidr_block                       = var.cidr_vpc
  enable_dns_hostnames             = true
  enable_dns_support               = true
  instance_tenancy                 = "default"
  assign_generated_ipv6_cidr_block = false
  tags = {
    Name = "${var.project}-vpc"
  }
}


#パブリックサブネット２つ（ALB、NATGW等用）
resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.eksargocd_vpc.id
  availability_zone       = var.az_1a
  cidr_block              = var.cidr_public_1a
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project}-public-subnet-${var.az_1a}"
  }
}

resource "aws_subnet" "public_subnet_1c" {
  vpc_id                  = aws_vpc.eksargocd_vpc.id
  availability_zone       = var.az_1c
  cidr_block              = var.cidr_public_1c
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project}-public-subnet-${var.az_1c}"
  }
}


#プライベートサブネット２つ（ワーカーノード等用）
resource "aws_subnet" "private_subnet_1a" {
  vpc_id                  = aws_vpc.eksargocd_vpc.id
  availability_zone       = var.az_1a
  cidr_block              = var.cidr_private_1a
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project}-private-subnet-${var.az_1a}"
  }
}

resource "aws_subnet" "private_subnet_1c" {
  vpc_id                  = aws_vpc.eksargocd_vpc.id
  availability_zone       = var.az_1c
  cidr_block              = var.cidr_private_1c
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project}-private-subnet-${var.az_1c}"
  }
}


#パブリック用ルートテーブルと、サブネット紐づけ
resource "aws_route_table" "public_routetable" {
  vpc_id = aws_vpc.eksargocd_vpc.id
  tags = {
    Name = "${var.project}-public_routetable"
  }
}

resource "aws_route_table_association" "public_routetable_subnet_1a" {
  route_table_id = aws_route_table.public_routetable.id
  subnet_id      = aws_subnet.public_subnet_1a.id
}

resource "aws_route_table_association" "public_routetable_subnet_1c" {
  route_table_id = aws_route_table.public_routetable.id
  subnet_id      = aws_subnet.public_subnet_1c.id
}


#プライベート用ルートテーブルと、サブネット紐づけ
resource "aws_route_table" "private_routetable" {
  vpc_id = aws_vpc.eksargocd_vpc.id
  tags = {
    Name = "${var.project}-private_routetable"
  }
}

resource "aws_route_table_association" "private_routetable_subnet_1a" {
  route_table_id = aws_route_table.private_routetable.id
  subnet_id      = aws_subnet.private_subnet_1a.id
}

resource "aws_route_table_association" "private_routetable_subnet_1c" {
  route_table_id = aws_route_table.private_routetable.id
  subnet_id      = aws_subnet.private_subnet_1c.id
}

#IGWと、IGWへのルート
resource "aws_internet_gateway" "eksargocd_igw" {
  vpc_id = aws_vpc.eksargocd_vpc.id
  tags = {
    Name = "${var.project}-igw"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.public_routetable.id
  destination_cidr_block = var.cidr_all
  gateway_id             = aws_internet_gateway.eksargocd_igw.id
}


#NATGWとNATGW用EIP、NATGWへのルート
resource "aws_nat_gateway" "eksargocd_natgw" {
  subnet_id     = aws_subnet.public_subnet_1a.id
  allocation_id = aws_eip.eip_natgw.id
  tags = {
    Name = "${var.project}-natgw"
  }
  depends_on = [aws_internet_gateway.eksargocd_igw]
}

resource "aws_eip" "eip_natgw" {
  domain = "vpc"
  tags = {
    Name = "${var.project}-eip-natgw"
  }
}

resource "aws_route" "natgw_route" {
  route_table_id         = aws_route_table.private_routetable.id
  destination_cidr_block = var.cidr_all
  nat_gateway_id         = aws_nat_gateway.eksargocd_natgw.id
}