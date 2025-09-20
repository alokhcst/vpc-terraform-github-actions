# AWS Cognito S3 Barcode Generator - Deployment Guide

This guide will help you deploy an AWS Cognito-authenticated S3-hosted website that generates barcodes based on JWT session tokens.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version 1.0+)
- Node.js and npm (for Lambda function dependencies)

## File Structure

Create the following file structure in your project directory:

```
cognito-barcode-app/
├── main.tf                 # Main Terraform configuration
├── lambda_function.js      # Lambda function template
├── website/
│   ├── index.html         # Main website file
│   └── callback.html      # OAuth callback handler
└── README.md
```

## Step-by-Step Deployment

### 1. Initialize Terraform

```bash
# Clone or create your project directory
mkdir cognito-barcode-app
cd cognito-barcode-app

# Initialize Terraform
terraform init
```

### 2. Configure Variables

Edit the `main.tf` file and update the variables section:

```hcl
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "my-barcode-app"  # Change this
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "yourdomain.com"  # Change this
}
```

### 3. Create Lambda Function File

Copy the Lambda function template to `lambda_function.js` in your root directory.

### 4. Create Website Files

Create a `website` directory and add the `index.html` and `callback.html` files.

### 5. Deploy Infrastructure

```bash
# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 6. Upload Website Files

After Terraform deployment, upload your website files to the S3 bucket:

```bash
# Get the bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# Upload website files
aws s3 cp website/index.html s3://$BUCKET_NAME/index.html
aws s3 cp website/callback.html s3://$BUCKET_NAME/callback.html
```

### 7. Configure the Website

1. Open your website URL (from Terraform output)
2. In the Configuration section, enter:
   - **User Pool ID**: From Terraform output `cognito_user_pool_id`
   - **Client ID**: From Terraform output `cognito_client_id`
   - **AWS Region**: Your deployment region
   - **API URL**: From Terraform output `barcode_api_url`
3. Click "Save Configuration"

## Testing the Application

### 1. Create a User Account

1. Click "Sign Up" on the website
2. Enter your email and password
3. Check your email for the verification code
4. Verify your account (if using email verification)

### 2. Sign In and Generate Barcode

1. Sign in with your credentials
2. Once authenticated, click "Generate Barcode"
3. View the generated barcode based on your JWT token

## Configuration Details

### Cognito User Pool Settings

The configuration includes:

- Email-based usernames
- Strong password policy (8+ chars, mixed case, numbers, symbols)
- Email verification
- Advanced security features enabled
- OAuth 2.0 flows configured

### Lambda Function Features

The barcode generator:

- Validates JWT tokens from Cognito
- Extracts user information from token claims
- Generates ASCII and SVG barcodes
- Returns comprehensive barcode metadata

### Security Features

- S3 bucket configured for static website hosting
- IAM roles with least privilege access
- CORS configured for API Gateway
- JWT token validation in Lambda
- Secure token storage in browser memory

## Customization Options

### Modify Barcode Content

Edit the Lambda function to change what information is encoded:

```javascript
// In lambda_function.js, modify this section:
const barcodeContent = `USER:${barcodeData.username}|ID:${barcodeData.user_id}|SESSION:${barcodeData.session_id}|EXP:${barcodeData.exp}`;
```

### Update UI Styling

Modify the CSS in `index.html` to match your brand:

```css
/* Change color scheme */
background: linear-gradient(135deg, #your-color1 0%, #your-color2 100%);
```

### Add Additional User Attributes

Update the Cognito User Pool configuration in `main.tf`:

```hcl
resource "aws_cognito_user_pool" "main" {
  # Add custom attributes
  schema {
    attribute_data_type = "String"
    name                = "department"
    required            = false
    mutable             = true
  }
}
```

## Troubleshooting

### Common Issues

1. **CORS Errors**: Ensure your API Gateway has proper CORS configuration
2. **Token Validation Fails**: Check that the User Pool ID in Lambda environment variables matches your pool
3. **S3 Access Denied**: Verify bucket policy allows public read access
4. **Lambda Timeout**: Increase timeout in Terraform configuration if needed

### Debug Steps

1. Check CloudWatch logs for Lambda function errors
2. Verify Cognito user pool and client configuration
3. Test API Gateway endpoints directly
4. Validate S3 bucket permissions and website configuration

### Useful Commands

```bash
# View Terraform outputs
terraform output

# Check Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/your-function-name"

# Test API Gateway endpoint
curl -X POST "your-api-url" -H "Content-Type: application/json" -d '{"jwt_token":"your-token"}'
```

## Security Considerations

1. **Token Storage**: Tokens are stored in browser memory, not localStorage
2. **HTTPS Only**: Use CloudFront or custom domain with SSL in production
3. **Token Expiration**: Implement proper token refresh logic
4. **Input Validation**: Lambda function validates all inputs
5. **Rate Limiting**: Consider adding API Gateway rate limiting

## Production Deployment

For production use, consider:

1. **Custom Domain**: Configure Route 53 and CloudFront
2. **SSL Certificate**: Use AWS Certificate Manager
3. **Monitoring**: Set up CloudWatch alarms
4. **Backup**: Enable S3 versioning
5. **CDN**: Use CloudFront for better performance

## Cost Estimation

Typical monthly costs (based on moderate usage):

- S3 hosting: ~$1-5
- Cognito: ~$0-5 (first 50,000 users free)
- Lambda: ~$0-1 (first 1M requests free)
- API Gateway: ~$1-10
- **Total**: ~$2-20/month

## Support and Updates

- Monitor