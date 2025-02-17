output "site_updating_iam_policy_arn" {
  description = "Value of site_updating IAM policy ARN"
  value       = try(aws_iam_policy.site_updating[0].arn, "")
}

output "s3_bucket_id" {
  description = "Value of aws_s3_bucket.site.id"
  value       = try(aws_s3_bucket.site.id, "")
}
