#!/bin/sh

fly targets
fly -t control-tower-${PCF_SUBDOMAIN_NAME} login --insecure --username admin --password ${CC_ADMIN_PASSWD}
fly -t control-tower-${PCF_SUBDOMAIN_NAME} pipelines

