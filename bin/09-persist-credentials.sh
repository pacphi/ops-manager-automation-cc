#!/bin/bash

source ~/.env

NAMESPACE="${CC_SUFFIX}"
INFO=$(GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower info \
    --namespace "${NAMESPACE}" \
    --region us-west1 \
    --iaas gcp \
    --json \
    ${PCF_SUBDOMAIN_NAME}
)

V_CC_ADMIN_PASSWD=$(echo "${INFO}" | jq --raw-output .config.concourse_password)
V_CREDHUB_CA_CERT=$(echo "${INFO}" | jq --raw-output .config.credhub_ca_cert)
V_CREDHUB_CLIENT=credhub_admin
V_CREDHUB_SECRET=$(echo "${INFO}" | jq --raw-output .config.credhub_admin_client_secret)
V_CREDHUB_SERVER=$(echo "${INFO}" | jq --raw-output .config.credhub_url)
V_GAC="eval $(GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json control-tower info --namespace ${NAMESPACE} --region us-west1 --iaas gcp --env ${PCF_SUBDOMAIN_NAME})"

cat >> ~/.env << EOF
CC_ADMIN_PASSWD=${V_CC_ADMIN_PASSWD}
CREDHUB_CA_CERT="${V_CREDHUB_CA_CERT}"
CREDHUB_CLIENT=${V_CREDHUB_CLIENT}
CREDHUB_SECRET=${V_CREDHUB_SECRET}
CREDHUB_SERVER=${V_CREDHUB_SERVER}
${V_GAC}
EOF
