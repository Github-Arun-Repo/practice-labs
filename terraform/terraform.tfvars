aws_region  = "eu-west-1"
name_prefix = "micah-ireland-lab"
vpc_cidr    = "10.40.0.0/16"

availability_zones = [
  "eu-west-1a",
  "eu-west-1b",
  "eu-west-1c"
]

public_subnet_cidrs = [
  "10.40.0.0/24",
  "10.40.1.0/24",
  "10.40.2.0/24"
]

private_app_subnet_cidrs = [
  "10.40.10.0/24",
  "10.40.11.0/24",
  "10.40.12.0/24"
]

private_data_subnet_cidrs = [
  "10.40.20.0/24",
  "10.40.21.0/24",
  "10.40.22.0/24"
]

common_tags = {
  environment = "dev"
  project     = "micah-vpc-lab"
}
