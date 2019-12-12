#!/bin/sh

cat >> ~/.env << EOF
CC_SUFFIX="$(uuidgen)"
EOF

GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower deploy \
    --namespace "${CC_TAG}" \
    --region us-west1 \
    --iaas gcp \
    --workers 3 \
    ${PCF_SUBDOMAIN_NAME}