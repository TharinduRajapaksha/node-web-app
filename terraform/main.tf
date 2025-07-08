provider "aws" {
  region = "ap-south-1"
  
}

####################################### Create VPC and Networking Resources for the EKS Cluster #######################################
#1 Create a VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-vpc"
    }
  
  }

#2 Create Internet Gateway
resource "aws_internet_gateway" "eks_igw" {
    vpc_id = aws_vpc.eks_vpc.id

    tags = {
        Name = "eks-igw"
    }
}

#3 Create Public Subnet
resource "aws_subnet" "eks_public_subnet" {
    count = 2
    vpc_id = aws_vpc.eks_vpc.id
    cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index)
    availability_zone = ["ap-south-1a", "ap-south-1b"][count.index  ]
    map_public_ip_on_launch = true

    tags = {
        Name                                       = "public-${count.index + 1}"
        "kubernetes.io/role/elb"                   = "1"
        "kubernetes.io/cluster/web-app-eks-cluster" = "shared"

    }
}

#4 Create Private Subnet
resource "aws_subnet" "eks_private_subnet" {
    count = 2
    vpc_id = aws_vpc.eks_vpc.id
    cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index +2)
    availability_zone = ["ap-south-1a", "ap-south-1b"][count.index]

    tags = {
        Name                                       = "private-${count.index + 1}"
        "kubernetes.io/role/internal-elb"          = "1"
        "kubernetes.io/cluster/web-app-eks-cluster" = "shared"
    }
}


#5 Create Elastic IP for NAT Gateway
resource "aws_eip" "eks_nat_eip" {

  tags = {
    Name = "nat-eip"
  }
}

#6 Create NAT Gateway
resource "aws_nat_gateway" "eks_nat_gateway" {
  allocation_id = aws_eip.eks_nat_eip.id
  subnet_id = aws_subnet.eks_public_subnet[0].id 

  tags = {
    Name = "eks-nat-gateway"
  }  
}

#7 Create Route Table for Public Subnet
resource "aws_route_table" "eks_public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "eks-public-rt"
  }
}

#8 Route Table Association for Public Subnet
resource "aws_route_table_association" "public_subnet_association" {
  count = 2
  subnet_id = aws_subnet.eks_public_subnet[count.index].id
  route_table_id = aws_route_table.eks_public_rt.id

}

#9 Create Route Table for Private Subnet
resource "aws_route_table" "eks_private_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route{
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat_gateway.id
  }

  tags = {
    Name = "eks-private-rt"
  }
  
}


#10 Route Table Association for Private Subnet
resource "aws_route_table_association" "private_subnet_association" {
  count = 2
  subnet_id = aws_subnet.eks_private_subnet[count.index].id
  route_table_id = aws_route_table.eks_private_rt.id

}
  

##################################################### Create IAM Roles for EKS Cluster #####################################################

# Create IAM Roles for EKS Cluster and Cluster nodes
#01.For the EKS Cluster control plan to access AWS services with 6 policies attached to it.
resource "aws_iam_role" "AmazonEKSAutoClusterRole" {
  name = "AmazonEKSAutoClusterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach required policies to the above role
resource "aws_iam_role_policy_attachment" "AmazonEKSAutoClusterRole_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.AmazonEKSAutoClusterRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSAutoClusterRole_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.AmazonEKSAutoClusterRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSAutoClusterRole_AmazonEKSBlockStoragePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.AmazonEKSAutoClusterRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSAutoClusterRole_AmazonEKSComputePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.AmazonEKSAutoClusterRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSAutoClusterRole_AmazonEKSLoadBalancingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.AmazonEKSAutoClusterRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSAutoClusterRole_AmazonEKSNetworkingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.AmazonEKSAutoClusterRole.name
}

#02.For the EKS Cluster Nodes to access AWS services like EC2 instance and regisster those with 2 policies attached to it.
resource "aws_iam_role" "AmazonEKSAutoNodeRole" {
  name = "AmazonEKSAutoNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
  
}

#Attach required policies to the above role
resource "aws_iam_role_policy_attachment" "AmazonEKSAutoNodeRole_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.AmazonEKSAutoNodeRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSAutoClusterRole_AmazonEKSWorkerNodeMinimalPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.AmazonEKSAutoNodeRole.name
}


############################################ Create EKS Cluster #####################################################

# Fetch existing VPC
data "aws_vpc" "eks_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Fetch existing subnets in the VPC
data "aws_subnets" "eks_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }
}

# Get details of those subnets
data "aws_subnet" "eks_subnet" {
  for_each = toset(data.aws_subnets.eks_subnets.ids)
  id       = each.value
}

# EKS Cluster
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = data.aws_subnets.eks_subnets.ids
  }

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
  }

  version = "1.29" # You can change this to your preferred version

  enabled_cluster_log_types = ["api", "audit", "authenticator"]
}

