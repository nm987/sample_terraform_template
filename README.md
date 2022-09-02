# Sample Terraform web hosting environment
This is a sample Terraform project which will create a small web hosting environment. It consists of EC2 instances with Apache server which are created from a Packer template which is included in this repository. I also includes a database server and load balancer as well as auto scaling group.

## Components
* VPC with public, private and database subnets (used VPC module to make my life easier)
* Security groups for various services
* RDS database
* SSH key
* Lunch configuration
* Auto scaling group
* S3 bucket for logs
* Load balancer target group and listener (HTTPS was deliberately omitted)
* Application load balancer

## Misc notes
###### Backend information
This project is using S3 backend. It was created by CLoudformation template which is available on my GitHub account. You can pass the S3 backend information by creating *backend.conf* file with the following content:
```
bucket         = "bucket_name"
key            = "terraform.tfstate"
region         = "bucket_region"
dynamodb_table = "dynamodb_table_name"
```
Usage of the backend config file is as follows:
```
terraform init -backend-config=backend.conf
```

###### DB passwords etc.
HashiCorp Vault was used to securelly pass sensitive information during the Terraform execution.

###### Omitting HTTPS listener
I just didn't feel that it was worth the effort to go through the trouble of setting up Route53 and creating a TLS/SSL certificate for this demo template so I just skipped it :)


