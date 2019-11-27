#!/bin/sh

cd ~/terraforming/terraforming-pks || exit
terraform init
terraform apply --auto-approve
