

resource "aws_s3_bucket" "personal" {
  bucket = "ulznq8eve3wu6ov5vflmbiztx-personal"
  tags = {
    Environment = "global"
    Resources   = "personal"
  }
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "personal" {
  bucket = aws_s3_bucket.personal.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "personal" {
  bucket = aws_s3_bucket.personal.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "personal" {
  depends_on = [
    aws_s3_bucket_ownership_controls.personal,
    aws_s3_bucket_public_access_block.personal
  ]

  bucket = aws_s3_bucket.personal.id
  acl    = "private"
}
