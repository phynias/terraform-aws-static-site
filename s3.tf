################################################################################
### S3
################################################################################

########################################
### Site bucket
########################################

# Create a bucket
resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name

  #  lifecycle {
  #    prevent_destroy = true
  #  }
}

# Set bucket versioning
resource "aws_s3_bucket_versioning" "site" {
  count  = var.bucket_versioning_site == true ? 1 : 0
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Make sure the bucket is not public
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable logging to log bucket
resource "aws_s3_bucket_logging" "site" {
  bucket = aws_s3_bucket.site.id

  target_bucket = aws_s3_bucket.logging.id
  target_prefix = "s3_${aws_s3_bucket.site.id}/"

  depends_on = [aws_s3_bucket.logging]
}

# Upload all files from a local directory to S3
# Adjust "path/to/your/directory" to the directory you want to upload
locals {
  source_directory = var.upload_dir
  files            = fileset(local.source_directory, "**")
  content_type_map = {
    "js"   = "application/json"
    "html" = "text/html"
    "css"  = "text/css"
    "csv"  = "text/csv"
    "txt"  = "text/plain"
    "xml"  = "text/xml"
    "jpg"  = "image/jpeg"
    "jepg" = "image/jpeg"
    "gif"  = "image/gif"
    "png"  = "image/png"
  }
}

resource "aws_s3_object" "files" {
  for_each = { for file in local.files : file => file }

  bucket       = aws_s3_bucket.site.id
  key          = each.value                                # The key is the relative file path in the bucket
  source       = "${local.source_directory}/${each.value}" # The source file path
  content_type = lookup(local.content_type_map, reverse(split(".", each.value))[0], "binary/octet-stream")
  etag         = filemd5("${local.source_directory}/${each.value}") # Optional, ensures file consistency
}

########################################
### Logging bucket
########################################

# Create a bucket
# Ignore KICS scan: S3 Bucket Logging Disabled
# Reason: This bucket is the logging bucket
# kics-scan ignore-line
resource "aws_s3_bucket" "logging" {
  bucket = "${local.bucket_name}-logging"

  #  lifecycle {
  #    prevent_destroy = true
  #  }
}

# Set bucket versioning
resource "aws_s3_bucket_versioning" "logging" {
  count  = var.bucket_versioning_logs == true ? 1 : 0
  bucket = aws_s3_bucket.logging.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Make sure the bucket is not public
resource "aws_s3_bucket_public_access_block" "logging" {
  bucket                  = aws_s3_bucket.logging.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  bucket = aws_s3_bucket.logging.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Set ownership controls
# https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html
resource "aws_s3_bucket_ownership_controls" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Starting in April 2023, you need to to override the best practice and enable ACLs when sending CloudFront logs to S3
# https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/AccessLogs.html#AccessLogsBucketAndFileOwnership
resource "aws_s3_bucket_acl" "logging" {
  bucket = aws_s3_bucket.logging.id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.logging]
}

# Bucket lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    id     = "move_files_to_IA"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "prune_old_files"
    status = "Enabled"
    expiration {
      days = 365
    }
  }
}
