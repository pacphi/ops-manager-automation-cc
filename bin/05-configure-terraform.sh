#!/bin/sh

cat > ~/terraform.tfvars <<-EOF
dns_suffix             = "${PCF_DOMAIN_NAME}"
env_name               = "${PCF_SUBDOMAIN_NAME}"
region                 = "us-west1"
zones                  = ["us-west1-b", "us-west1-a", "us-west1-c"]
project                = "$(gcloud config get-value core/project)"
opsman_image_url       = ""
opsman_vm              = 0
create_gcs_buckets     = "false"
external_database      = 0
isolation_segment      = 0
ssl_cert            = <<SSL_CERT
$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.crt)
SSL_CERT
ssl_private_key     = <<SSL_KEY
$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.key)
SSL_KEY
service_account_key = <<SERVICE_ACCOUNT_KEY
$(cat ~/gcp_credentials.json)
SERVICE_ACCOUNT_KEY
EOF
