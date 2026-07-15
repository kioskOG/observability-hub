include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/route53"
}

inputs = {
  # Set create_zone=false and provide existing_zone_id if you already have a zone
  aws_region = "ap-southeast-1"
  create_zone = true
  domain_name = "example.com"

  # Optional health checks
  health_checks = [
    {
      name            = "api-health"
      type            = "HTTPS"
      fqdn            = "api.example.com"
      port            = 443
      resource_path   = "/healthz"
      request_interval= 30
      failure_threshold = 3
      measure_latency = true
    }
  ]

  # Records
  records = [
    # Simple A record
    {
      name    = "www.example.com"
      type    = "A"
      ttl     = 300
      records = ["1.2.3.4"]
    },

    # Alias to CloudFront
    # {
    #   name = "app.example.com"
    #   type = "A"
    #   alias = {
    #     name                   = "d1234567890abcdef.cloudfront.net"
    #     zone_id                = "Z2FDTNDATAQYW2"
    #     evaluate_target_health = false
    #   }
    # },

    # Weighted blue/green
    {
      name           = "bluegreen.example.com"
      type           = "A"
      set_identifier = "blue"
      ttl            = 60
      records        = ["10.0.10.10"]
      weighted_routing_policy = { weight = 20 }
    },
    {
      name           = "bluegreen.example.com"
      type           = "A"
      set_identifier = "green"
      ttl            = 60
      records        = ["10.0.10.11"]
      weighted_routing_policy = { weight = 80 }
    },

    # Failover using health check
    {
      name           = "api.example.com"
      type           = "A"
      set_identifier = "primary"
      ttl            = 30
      records        = ["10.0.20.10"]
      failover_routing_policy = { type = "PRIMARY" }
      health_check_name       = "api-health"
    },
    {
      name           = "api.example.com"
      type           = "A"
      set_identifier = "secondary"
      ttl            = 30
      records        = ["10.0.21.10"]
      failover_routing_policy = { type = "SECONDARY" }
    },

    # TXT (SPF) example
    {
      name    = "example.com"
      type    = "TXT"
      ttl     = 300
      records = ["v=spf1 include:amazonses.com -all"]
    }
  ]

  # Optional ACM validation CNAMEs
  # acm_validation_records = [
  #   {
  #     name    = "_abcde12345.example.com"
  #     type    = "CNAME"
  #     records = ["_fghij67890.acm-validations.aws."]
  #     ttl     = 300
  #   }
  # ]

  tags = {
    Environment = "production"
    Project     = "edge"
    Owner       = "platform"
  }
}
