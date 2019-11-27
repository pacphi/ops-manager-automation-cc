#!/bin/sh

# Create your jumpbox from your local machine or Google Cloud Shell
## Expects that an environent variable named GCP_PROJECT_ID has already been exported

gcloud auth login --project ${GCP_PROJECT_ID} --quiet # ... if necessary

gcloud services enable compute.googleapis.com \
  --project "${GCP_PROJECT_ID}"

gcloud compute instances create "jbox-cc" \
  --image-project "ubuntu-os-cloud" \
  --image-family "ubuntu-1804-lts" \
  --boot-disk-size "200" \
  --machine-type=g1-small \
  --project "${GCP_PROJECT_ID}" \
  --zone "us-west1-a"