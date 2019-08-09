provider "aws" {
	version = "~> 2.19"
	region = "us-east-1"
}

resource "aws_s3_bucket" "site" {
  bucket = "www.${var.site_domain}"

  website {
    index_document = "${var.bucket_index_document}"
    error_document = "${var.bucket_error_document}"
  }

  logging {
    target_bucket = "${aws_s3_bucket.site_log_bucket.id}"
  }

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket" "redirect_to_site" {
  bucket = "${var.site_domain}"

  website {
    redirect_all_requests_to = "https://www.${var.site_domain}"
  }
}

resource "aws_s3_bucket" "site_log_bucket" {
  bucket = "${var.site_domain}-logs"
  acl = "log-delivery-write"
}

resource "aws_s3_bucket_policy" "site" {
  bucket = "${aws_s3_bucket.site.id}"
  policy = "${data.aws_iam_policy_document.site_public_access.json}"
}

data "aws_iam_policy_document" "site_public_access" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type = "AWS"
      identifiers = ["*"]
    }
  }

  statement {
    actions = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.site.arn}"]

    principals {
      type = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "redirect_to_site" {
  bucket = "${aws_s3_bucket.redirect_to_site.id}"
  policy = "${data.aws_iam_policy_document.redirect_to_site.json}"
}

data "aws_iam_policy_document" "redirect_to_site" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.redirect_to_site.arn}/*"]

    principals {
      type = "AWS"
      identifiers = ["*"]
    }
  }

  statement {
    actions = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.redirect_to_site.arn}"]

    principals {
      type = "AWS"
      identifiers = ["*"]
    }
  }
}

provider "aws" {
  alias = "virginia"
  region = "us-east-1"
}

resource "aws_acm_certificate" "default" {
  provider = "aws.virginia"
  domain_name = "*.${var.site_domain}"
  subject_alternative_names = ["www.${var.site_domain}", "${var.site_domain}"]
  validation_method = "DNS"
}

resource "aws_route53_zone" "external" {
	name = "${var.site_domain}"
}

resource "aws_route53_record" "validation" {
	name    = "${aws_acm_certificate.default.domain_validation_options.0.resource_record_name}"
	type    = "${aws_acm_certificate.default.domain_validation_options.0.resource_record_type}"
	zone_id = "${aws_route53_zone.external.zone_id}"
	records = ["${aws_acm_certificate.default.domain_validation_options.0.resource_record_value}"]
	ttl     = "60"
}

resource "aws_acm_certificate_validation" "default" {
	certificate_arn = "${aws_acm_certificate.default.arn}"
	validation_record_fqdns = [
	"${aws_route53_record.validation.fqdn}",
	]
}
