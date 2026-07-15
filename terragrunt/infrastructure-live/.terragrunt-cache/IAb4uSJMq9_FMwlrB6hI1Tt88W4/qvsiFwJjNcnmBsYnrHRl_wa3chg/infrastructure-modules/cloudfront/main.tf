data "aws_s3_bucket" "existing_bucket" {
  count  = var.origin_type == "s3" ? 1 : 0
  bucket = var.bucket_name
}
resource "aws_cloudfront_origin_access_control" "oac" {
  count                             = var.origin_type == "s3" ? 1 : 0
  name                              = "${var.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_s3_bucket_policy" "cdn_policy" {
  count  = var.origin_type == "s3" ? 1 : 0
  bucket = data.aws_s3_bucket.existing_bucket[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${data.aws_s3_bucket.existing_bucket[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"
  origin {
    domain_name              = var.origin_type == "s3" ? data.aws_s3_bucket.existing_bucket[0].bucket_regional_domain_name : var.alb_dns_name
    origin_id                = var.origin_type == "s3" ? "S3Origin" : "ALBOrigin"
    origin_access_control_id = var.origin_type == "s3" ? aws_cloudfront_origin_access_control.oac[0].id : null
    dynamic "custom_origin_config" {
      for_each = var.origin_type == "alb" ? [1] : []
      content {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.origin_type == "s3" ? "S3Origin" : "ALBOrigin"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl     = var.min_ttl
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl
  }
  price_class = var.price_class
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
    }
  }
}

resource "aws_wafv2_web_acl_association" "cf_waf" {
  count        = var.waf_web_acl_id != "" ? 1 : 0
  resource_arn = aws_cloudfront_distribution.cdn.arn
  web_acl_arn  = var.waf_web_acl_id
}
