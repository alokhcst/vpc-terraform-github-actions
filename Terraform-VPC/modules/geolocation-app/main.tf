# main.tf

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "geolocation-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "aws_region"
  type        = string
  default     = "us-east-1"
}


# Random string for unique bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket for static website hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.project_name}-${var.environment}-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "${var.project_name}-website"
    Environment = var.environment
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "website_bucket_pab" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "website_bucket_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# S3 bucket policy for public read access
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website_bucket_pab]
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
  }
}

# IAM role policy attachment for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Archive Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda function
resource "aws_lambda_function" "geolocation_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-geolocation"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = {
    Name        = "${var.project_name}-geolocation"
    Environment = var.environment
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "geolocation_api" {
  name        = "${var.project_name}-api-${random_string.bucket_suffix.result}"
  description = "API for geolocation service"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "geolocation_resource" {
  rest_api_id = aws_api_gateway_rest_api.geolocation_api.id
  parent_id   = aws_api_gateway_rest_api.geolocation_api.root_resource_id
  path_part   = "geolocation"
}

resource "aws_api_gateway_method" "geolocation_method" {
  rest_api_id   = aws_api_gateway_rest_api.geolocation_api.id
  resource_id   = aws_api_gateway_resource.geolocation_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "geolocation_options" {
  rest_api_id   = aws_api_gateway_rest_api.geolocation_api.id
  resource_id   = aws_api_gateway_resource.geolocation_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.geolocation_api.id
  resource_id             = aws_api_gateway_resource.geolocation_resource.id
  http_method             = aws_api_gateway_method.geolocation_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.geolocation_function.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.geolocation_api.id
  resource_id = aws_api_gateway_resource.geolocation_resource.id
  http_method = aws_api_gateway_method.geolocation_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "geolocation_response" {
  rest_api_id = aws_api_gateway_rest_api.geolocation_api.id
  resource_id = aws_api_gateway_resource.geolocation_resource.id
  http_method = aws_api_gateway_method.geolocation_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "geolocation_options_response" {
  rest_api_id = aws_api_gateway_rest_api.geolocation_api.id
  resource_id = aws_api_gateway_resource.geolocation_resource.id
  http_method = aws_api_gateway_method.geolocation_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "lambda_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.geolocation_api.id
  resource_id = aws_api_gateway_resource.geolocation_resource.id
  http_method = aws_api_gateway_method.geolocation_method.http_method
  status_code = aws_api_gateway_method_response.geolocation_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.lambda_integration]
}

resource "aws_api_gateway_integration_response" "lambda_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.geolocation_api.id
  resource_id = aws_api_gateway_resource.geolocation_resource.id
  http_method = aws_api_gateway_method.geolocation_options.http_method
  status_code = aws_api_gateway_method_response.geolocation_options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.lambda_options_integration]
}

resource "aws_api_gateway_deployment" "geolocation_deployment" {
  rest_api_id = aws_api_gateway_rest_api.geolocation_api.id
  stage_name  = var.environment

  depends_on = [
    aws_api_gateway_method.geolocation_method,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method.geolocation_options,
    aws_api_gateway_integration.lambda_options_integration,
    aws_api_gateway_method_response.geolocation_response,
    aws_api_gateway_method_response.geolocation_options_response,
    aws_api_gateway_integration_response.lambda_integration_response,
    aws_api_gateway_integration_response.lambda_options_integration_response,
  ]
}

resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.geolocation_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.geolocation_api.execution_arn}/*/*"
}



# Upload website files
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/index.html")
}

resource "aws_s3_object" "error_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "error.html"
  source       = "${path.module}/error.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/error.html")
}

resource "aws_s3_object" "styles_css" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "styles.css"
  source       = "${path.module}/styles.css"
  content_type = "text/css"
  etag         = filemd5("${path.module}/styles.css")
}

# Outputs
output "website_url" {
  description = "URL of the static website"
  value       = "http://${aws_s3_bucket.website_bucket.bucket}.s3-website-${var.aws_region}.amazonaws.com"
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.geolocation_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.geolocation_function.function_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.website_bucket.id
}