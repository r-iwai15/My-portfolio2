resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "public-1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}c"
  tags = {
    Name = "public-1c"
  }
}

resource "aws_eip" "nat_1a" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_1a" {
  allocation_id = aws_eip.nat_1a.id
  subnet_id     = aws_subnet.public_1a.id
  depends_on    = [aws_internet_gateway.gw]
  tags = {
    Name = "${var.name_prefix}-nat-1a"
  }
}

resource "aws_subnet" "app_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "app-1a"
  }
}

resource "aws_subnet" "app_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.region}c"
  tags = {
    Name = "app-1c"
  }
}

resource "aws_subnet" "db_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "db-1a"
  }
}

resource "aws_subnet" "db_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "${var.region}c"
  tags = {
    Name = "db-1c"
  }
}

resource "aws_subnet" "lambda_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.31.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "lambda-1a"
  }
}

resource "aws_subnet" "lambda_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.32.0/24"
  availability_zone = "${var.region}c"
  tags = {
    Name = "lambda-1c"
  }
}

resource "aws_subnet" "llm_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.41.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "llm-1a"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1a.id
  }
  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "llm_a" {
  subnet_id      = aws_subnet.llm_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_c" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app_a" {
  subnet_id      = aws_subnet.app_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_c" {
  subnet_id      = aws_subnet.app_1c.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_c" {
  subnet_id      = aws_subnet.db_1c.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "lam_a" {
  subnet_id      = aws_subnet.lambda_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "lam_c" {
  subnet_id      = aws_subnet.lambda_1c.id
  route_table_id = aws_route_table.private.id
}
