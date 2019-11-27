#!/bin/sh

echo "PRODUCT_SLUG=pivotal-container-service" >> ~/.env
cd ~/terraforming/terraforming-pks || exit
ln -s ~/terraform.tfvars .