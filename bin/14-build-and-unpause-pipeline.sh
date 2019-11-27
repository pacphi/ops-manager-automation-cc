#!/bin/bash

source ~/.env

cat > ~/private.yml << EOF
---
product-slug: ${PRODUCT_SLUG}
config-uri: ${GITHUB_PUBLIC_REPO}
gcp-credentials: |
$(cat ~/gcp_credentials.json | sed 's/^/  /')
gcs-bucket: ${PCF_SUBDOMAIN_NAME}-concourse-resources
pivnet-token: ${PIVNET_UAA_REFRESH_TOKEN}
credhub-ca-cert: |
$(echo $CREDHUB_CA_CERT | sed 's/- /-\n/g; s/ -/\n-/g' | sed '/CERTIFICATE/! s/ /\n/g' | sed 's/^/  /')
credhub-client: ${CREDHUB_CLIENT}
credhub-secret: ${CREDHUB_SECRET}
credhub-server: ${CREDHUB_SERVER}
EOF

fly -t control-tower-${PCF_SUBDOMAIN_NAME} set-pipeline -p ${PRODUCT_SLUG} -n \
  -c ~/ops-manager-automation-cc/ci/${PRODUCT_SLUG}/pipeline.yml \
  -l ~/private.yml

fly -t control-tower-${PCF_SUBDOMAIN_NAME} unpause-pipeline -p ${PRODUCT_SLUG}
