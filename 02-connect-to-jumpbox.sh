#!/bin/sh

# Connect to the jumbpbox
GCP_PROJECT_ID=fe-cphillipson

gcloud compute ssh ubuntu@jbox-cc \
  --project "${GCP_PROJECT_ID}" \
  --zone "us-west1-a"
