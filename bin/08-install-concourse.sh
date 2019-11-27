#!/bin/sh

GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower deploy \
    --region us-west1 \
    --iaas gcp \
    --workers 3 \
    ${PCF_SUBDOMAIN_NAME}