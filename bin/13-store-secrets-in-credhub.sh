#!/bin/bash

set -e

source ~/.env
credhub login

GCP_PROJECT_ID="$(gcloud config get-value core/project)"
OPSMAN_PUBLIC_IP="$(dig +short pcf.${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME})"

credhub set -n pivnet-api-token -t value -v "${PIVNET_UAA_REFRESH_TOKEN}"
credhub set -n domain-name -t value -v "${PCF_DOMAIN_NAME}"
credhub set -n subdomain-name -t value -v "${PCF_SUBDOMAIN_NAME}"
credhub set -n gcp-project-id -t value -v "${GCP_PROJECT_ID}"
credhub set -n opsman-public-ip -t value -v "${OPSMAN_PUBLIC_IP}"
credhub set -n gcp-credentials -t value -v "$(cat ~/gcp_credentials.json)"
credhub set -n om-target -t value -v "${OM_TARGET}"
credhub set -n om-skip-ssl-validation -t value -v "${OM_SKIP_SSL_VALIDATION}"
credhub set -n om-username -t value -v "${OM_USERNAME}"
credhub set -n om-password -t value -v "${OM_PASSWORD}"
credhub set -n om-decryption-passphrase -t value -v "${OM_DECRYPTION_PASSPHRASE}"
credhub set -n domain-crt-ca -t value -v "$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.ca.crt)"
credhub set -n domain-crt -t value -v "$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.crt)"
credhub set -n domain-key -t value -v "$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.key)"
