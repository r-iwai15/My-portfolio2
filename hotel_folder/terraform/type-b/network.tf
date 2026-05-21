module "vpc" {
  source      = "../modules/vpc_type_b"
  region      = var.region
  name_prefix = "hotel-innovative"
}
