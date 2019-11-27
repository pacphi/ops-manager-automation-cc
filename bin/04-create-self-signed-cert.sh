#!/bin/sh

DOMAIN=${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME} ~/ops-manager-automation-cc/bin/mk-ssl-cert-key.sh
