# Configure the AWS Provider
provider "aws" {
  profile = "terraform"
  region  = "ap-northeast-1"
  access_key = "my_access_key"
  secret_key = "my_secret_key"
}

# infomation vpc
variable "vpc" {
  default = {
    vpc1 = {
      name = "vpc1"
      cidr_block = "10.0.0.0/16"
      route_tables = {
        public_rt = {
          name = "public_rt"
        } 
        private_rt = {
          name = "private_rt"
        } 
      }
      subnets = {
        public_subnet_1a = {
          name = "public_subnet_1a"
          availability_zone = "ap-northeast-1a"
          cidr_block = "10.0.0.0/24"
          route_table = "public_rt"
        }
        public_subnet_1c = {
          name = "public_subnet_1c"
          availability_zone = "ap-northeast-1c"
          cidr_block = "10.0.1.0/24"
          route_table = "public_rt"
        }
        private_subnet_1a = {
          name = "private_subnet_1a"
          availability_zone = "ap-northeast-1a"
          cidr_block = "10.0.2.0/24"
          route_table = "private_rt"
        }  
        private_subnet_1c = {
          name = "private_subnet_1c"
          availability_zone = "ap-northeast-1a"
          cidr_block = "10.0.3.0/24"
          route_table = "private_rt"
        }                  
      }
    }
  }    
}

# create vpc
resource "aws_vpc" "main" {
  for_each = var.vpc
  cidr_block = lookup(each.value, "cidr_block")
  tags = {
    Name = lookup(each.value, "name")
  }
}

# create subnet
resource "aws_subnet" "vpc1-subnets" {
  for_each = var.vpc.vpc1.subnets
  cidr_block = lookup(each.value, "cidr_block")
  availability_zone = lookup(each.value, "availability_zone")
  tags = {
    Name = lookup(each.value, "name")
  }
  vpc_id = aws_vpc.main["vpc1"].id
}

# create internet_gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main["vpc1"].id

  tags = {
    Name = "test_gw"
  }
}

# create route table
resource "aws_route_table" "test_route" {
  vpc_id = aws_vpc.main["vpc1"].id
  for_each = var.vpc.vpc1.route_tables
  tags = {
    Name = lookup(each.value, "name")
  }
}

resource "aws_route" "public_route" {
  route_table_id            = aws_route_table.test_route["public_rt"].id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id  = aws_internet_gateway.gw.id
}
resource "aws_route" "vpn_route" {
  route_table_id            = aws_route_table.test_route["private_rt"].id
  destination_cidr_block    = "192.168.0.0/16"
  gateway_id  = aws_vpn_gateway.vpn_gw.id
}

# add main route table to vpc
resource "aws_main_route_table_association" "public_route" {
  vpc_id         = aws_vpc.main["vpc1"].id
  route_table_id = aws_route_table.test_route["public_rt"].id
}


# add subnet to route_table
resource "aws_route_table_association" "a" {
  for_each = var.vpc.vpc1.subnets
  subnet_id = aws_subnet.vpc1-subnets[lookup(each.value, "name")].id
  route_table_id = aws_route_table.test_route[lookup(each.value, "route_table")].id
}

# create customer gateway ip_address change your environment
resource "aws_customer_gateway" "customer_gateway" {
  bgp_asn    = 65000
  ip_address = "172.83.124.10"
  type       = "ipsec.1"

  tags = {
    Name = "main-customer-gateway"
  }
}

# create VGW
resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.main["vpc1"].id
  tags = {
    Name = "test_VGW"
  }
}

# attach VGW
resource "aws_vpn_gateway_attachment" "vpn_attachment" {
  vpc_id         = aws_vpc.main["vpc1"].id
  vpn_gateway_id = aws_vpn_gateway.vpn_gw.id
}

# create site to site VPN
resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.customer_gateway.id
  type                = "ipsec.1"
  static_routes_only  = false
  tags = {
    Name = "test_VPN"
  }
}

resource "aws_vpn_gateway_route_propagation" "example" {
  vpn_gateway_id = aws_vpn_gateway.vpn_gw.id
  route_table_id = aws_route_table.test_route["private_rt"].id
}