locals {
  tags = {
    Terraform   = "true"
    Company     = var.project.company
    Environment = var.project.env
  }
}

module "vpc" {
  count  = var.vpc == null ? 0 : 1
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=v5.13.0"

  name = format("%s-%s-vpc", var.project.company, var.project.env)
  cidr = var.vpc.cidr

  azs                 = var.vpc.zones
  private_subnets     = var.vpc.private_subnets
  private_subnet_tags = var.vpc.private_subnet_tags
  public_subnets      = var.vpc.public_subnets
  public_subnet_tags  = var.vpc.public_subnet_tags
  database_subnets    = var.vpc.database_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.vpc.single_nat_gateway
  one_nat_gateway_per_az = true

  tags = local.tags
}

module "ec2" {
  for_each = { for k, v in var.ec2 : k => v if v.autoscaling == null }
  source   = "git::https://github.com/terraform-aws-modules/terraform-aws-ec2-instance.git?ref=v5.7.0"

  name                   = format("%s-%s-%s", var.project.company, var.project.env, each.key)
  instance_type          = each.value.instance_type
  user_data_base64       = try(filebase64(each.value.init_script), null)
  create_eip             = true
  ami                    = each.value.ami
  key_name               = each.value.create_key ? format("%s-%s-%s-key", var.project.company, var.project.env, each.key) : each.value.key_name
  root_block_device      = each.value.root_block_device
  monitoring             = true
  vpc_security_group_ids = [for sg_id in each.value.vpc_security_group_ids : module.sg[sg_id].security_group_id]
  subnet_id              = module.vpc[0].public_subnets[index(var.vpc.zones, each.value.zone)]

  tags = local.tags
}

module "key" {
  for_each           = { for k, v in var.ec2 : k => v if v.create_key }
  source             = "git::https://github.com/terraform-aws-modules/terraform-aws-key-pair.git?ref=v2.0.3"
  key_name           = format("%s-%s-%s-key", var.project.company, var.project.env, each.key)
  create_private_key = true
}
resource "local_sensitive_file" "private_key" {
  for_each = module.key
  content  = each.value.private_key_pem
  filename = format("%s/%s", var.project.key_directory, each.value.key_pair_name)
}

module "sg" {
  for_each = var.sg
  source   = "git::https://github.com/terraform-aws-modules/terraform-aws-security-group.git?ref=v5.1.2"

  name        = format("%s-%s-%s-sg", var.project.company, var.project.env, each.key)
  description = each.value.description
  vpc_id      = module.vpc[0].vpc_id

  ingress_with_cidr_blocks = each.value.ingress_with_cidr_blocks
  egress_with_cidr_blocks = [{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "Allow all egress"
    cidr_blocks = "0.0.0.0/0"
  }]

  tags = local.tags
}

module "rds" {
  for_each = var.rds
  source   = "git::https://github.com/terraform-aws-modules/terraform-aws-rds.git?ref=v6.9.0"

  identifier             = format("%s-%s-%s", var.project.company, var.project.env, each.key)
  vpc_security_group_ids = [for sg_id in each.value.security_groups : module.sg[sg_id].security_group_id]
  db_subnet_group_name   = module.vpc[0].database_subnet_group
  username               = "root"

  engine            = each.value.engine
  engine_version    = each.value.engine_version
  instance_class    = each.value.instance_class
  family            = format("%s%s", each.value.engine, each.value.engine_version)
  storage_type      = "gp3"
  allocated_storage = 30
  multi_az          = true

  deletion_protection                 = true
  iam_database_authentication_enabled = true
  maintenance_window                  = "Mon:00:00-Mon:03:00"
  backup_window                       = "03:00-06:00"

  tags = local.tags
}

module "eks" {
  count  = var.eks == null ? 0 : 1
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=v20.24.0"

  cluster_name                    = format("%s-%s-eks", var.project.company, var.project.env)
  cluster_version                 = var.eks.version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_enabled_log_types = var.eks.cluster_enabled_log_types == null ? ["audit", "api", "authenticator"] : var.eks.cluster_enabled_log_types

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver     = {}
  }

  vpc_id                    = module.vpc[0].vpc_id
  subnet_ids                = module.vpc[0].private_subnets
  cluster_service_ipv4_cidr = var.eks.cluster_service_ipv4_cidr

  kms_key_administrators = var.eks.kms_key_administrators

  node_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "-1"
      from_port                  = 0
      to_port                    = 0
      type                       = "ingress"
      source_node_security_group = true
    }
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_groups = { for k, v in var.eks.eks_managed_node_groups : k => merge(v, { subnet_ids = [module.vpc[0].private_subnets[index(var.vpc.zones, v.zone)]] }) }

  access_entries = { for k, v in var.eks.access_entries : k => merge(v, { policy_associations = {
    admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
  } }) }

  tags = local.tags
}

module "asg" {
  for_each = { for k, v in var.ec2 : k => v if v.autoscaling != null }
  source  = "git::https://github.com/terraform-aws-modules/terraform-aws-autoscaling.git?ref=v8.1.0"

  name = format("%s-%s-%s-asg", var.project.company, var.project.env, each.key)

  min_size                  = each.value.autoscaling.min_size
  max_size                  = each.value.autoscaling.max_size
  desired_capacity          = each.value.autoscaling.desired_capacity
  wait_for_capacity_timeout = 0
  health_check_type         = each.value.autoscaling.health_check_type
  vpc_zone_identifier       = module.vpc[0].private_subnets

  initial_lifecycle_hooks = [
    {
      name                  = "ExampleStartupLifeCycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 60
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_LAUNCHING"
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                  = "ExampleTerminationLifeCycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 180
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
      max_healthy_percentage = 100
    }
    triggers = ["tag"]
  }

  launch_template_name        = format("%s-%s-%s-launch-template", var.project.company, var.project.env, each.key)
  update_default_version      = true

  image_id          = each.value.ami
  instance_type     = each.value.instance_type
  ebs_optimized     = true
  enable_monitoring = true

  create_iam_instance_profile = true
  iam_role_name               = format("%s-%s-%s-role", var.project.company, var.project.env, each.key)
  iam_role_path               = "/ec2/"
  iam_role_permissions_boundary = each.value.iam_role_permissions_boundary

  block_device_mappings = each.value.autoscaling.block_device_mappings

  security_groups = [for sg_id in each.value.vpc_security_group_ids : module.sg[sg_id].security_group_id]

  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }

  cpu_options = {
    core_count       = 1
    threads_per_core = 1
  }

  credit_specification = {
    cpu_credits = "standard"
  }

  placement = {
    availability_zone = "${each.value.zone}"
  }

  tags = local.tags
}

# module "alb" {
#   count = var.asg == nul ? 0 : 1
#   source  = "git::https://github.com/terraform-aws-modules/terraform-aws-alb.git?ref=v9.13.0"

#   name    = var.alb.name
#   vpc_id  = module.vpc.vpc_id
#   subnets = module.vpc.public_subnets

#   security_group_ingress_rules = {
#     all_http = {
#       from_port   = 80
#       to_port     = 80
#       ip_protocol = "tcp"
#       description = "HTTP web traffic"
#       cidr_ipv4   = "0.0.0.0/0"
#     }
#     all_https = {
#       from_port   = 443
#       to_port     = 443
#       ip_protocol = "tcp"
#       description = "HTTPS web traffic"
#       cidr_ipv4   = "0.0.0.0/0"
#     }
#   }
#   security_group_egress_rules = {
#     all = {
#       ip_protocol = "-1"
#       cidr_ipv4   = "0.0.0.0/0"
#     }
#   }

#   access_logs = {
#     bucket = "my-alb-logs"
#   }

#   listeners = {
#     ex-http-https-redirect = {
#       port     = 80
#       protocol = "HTTP"
#       redirect = {
#         port        = "443"
#         protocol    = "HTTPS"
#         status_code = "HTTP_301"
#       }
#     }
#     ex-https = {
#       port            = 443
#       protocol        = "HTTPS"
#       certificate_arn = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"

#       forward = {
#         target_group_key = "asg_target_group"
#       }
#     }
#   }

#   target_groups = {
#     asg_target_group = {
#       protocol         = "HTTP"
#       port             = 80
#       target_type      = "autoscaling_group"
#       target_id        = module.asg.autoscaling_group_id
#     }
#   }

# }
