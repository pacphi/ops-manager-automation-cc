#!/bin/sh

gsutil mb -c regional -l us-west1 gs://${PCF_SUBDOMAIN_NAME}-concourse-resources
gsutil versioning set on gs://${PCF_SUBDOMAIN_NAME}-concourse-resources

echo "---" > ~/state.yml
gsutil cp ~/state.yml gs://${PCF_SUBDOMAIN_NAME}-concourse-resources/
