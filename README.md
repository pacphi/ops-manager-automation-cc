# ops-manager-automation-cc (fork)

## What will you find here?

Infrastructure-as-code.

This repository employs [Control Tower](https://github.com/EngineerBetter/control-tower) to build a [Concourse](https://concourse-ci.org/) instance on [Google Cloud Platform](https://cloud.google.com/), then uses a combination of [GCS](https://cloud.google.com/storage/) buckets, [Credhub](https://docs.cloudfoundry.org/credhub/), a suite of [Platform Automation](http://docs.pivotal.io/platform-automation) tools and a single Concourse pipeline to deploy (and upgrade) an Operations Manager.  Not only that but you can choose to install and configure an assortment of product tiles that offer a complement of commercial and industrial capabilities from the Cloud Foundry eco-system sourced from the [Pivotal Network](https://network.pivotal.io).

The pipelines currently support [Pivotal Container Service](https://pivotal.io/platform/pivotal-container-service) and [Pivotal Application Service](https://pivotal.io/platform/pivotal-application-service) with a curated complement of related products.

## Fork this repository

I recommend forking this repository so you can:

* Make modifications to suit your own requirements
* Protect your active pipelines from config changes made here

## Recycling GCP projects

If you wish to re-use an existing GCP project for this exercise, it is often useful to clean up any existing resources beforehand.
For guidance, follow [these instructions](https://github.com/amcginlay/gcp-cleanup). You might also want to take a look at [leftovers](https://github.com/genevieve/leftovers).

## For the impatient

If you don't want to spend time following step-by-step instructions, you might want to peruse the `*.sh` scripts in the root of this repository and in the `bin` directory.  These are a work in progress and the goal is to shrink the time-to-value (and keystrokes).  Basically, you'll want to execute them in order starting with the scripts in the root and then moving on to executing the ones in the `bin` directory.  You'll want to follow the instructions in the [Prepare your environment file](#prepare-your-environment-file) section first.

## Create your jumpbox from your local machine or Google Cloud Shell

> Feel free to replace the `--zone` values below with any other [supported](https://cloud.google.com/compute/docs/regions-zones/) zone on Google Cloud.

```bash
GCP_PROJECT_ID=<TARGET_GCP_PROJECT_ID>
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
```

## Move to the jumpbox and log in to GCP

```bash
gcloud compute ssh ubuntu@jbox-cc \
  --project "${GCP_PROJECT_ID}" \
  --zone "us-west1-a"
```

```bash
gcloud auth login --quiet
```

All following commands should be executed from the jumpbox unless otherwise instructed.

## Prepare your environment file

```bash
cat > ~/.env << EOF
# *** your environment-specific variables will go here ***
export PIVNET_UAA_REFRESH_TOKEN=CHANGE_ME_PIVNET_UAA_REFRESH_TOKEN  # e.g. xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-r
export PCF_DOMAIN_NAME=CHANGE_ME_DOMAIN_NAME                        # e.g. "mydomain.com", "pal.pivotal.io", "pivotaledu.io", etc.
export PCF_SUBDOMAIN_NAME=CHANGE_ME_SUBDOMAIN_NAME                  # e.g. "pks", "pas", "cls66env99", "maroon", etc.
export GITHUB_PUBLIC_REPO=CHANGE_ME_GITHUB_PUBLIC_REPO              # e.g. https://github.com/pacphi/ops-manager-automation-cc.git

export OM_TARGET=https://pcf.\${PCF_SUBDOMAIN_NAME}.\${PCF_DOMAIN_NAME}
export OM_USERNAME=admin
export OM_PASSWORD=$(uuidgen)
export OM_DECRYPTION_PASSPHRASE=\${OM_PASSWORD}
export OM_SKIP_SSL_VALIDATION=true
EOF
```

__Before__ continuing, open the `.env` file and update the `CHANGE_ME` values accordingly.

Ensure these variables get set into the shell every time the ubuntu user connects to the jumpbox:

```bash
echo "source ~/.env" >> ~/.bashrc
```

Load the variables into your shell with the source command so we can use them immediately:

```bash
source ~/.env
```

## Update an existing Cloud DNS Zone

**Note:** A Cloud DNS Zone for `PCF_DOMAIN_NAME` above should already exist.  You will need to add an `NS` recordset to your top-level Cloud DNS zone.
> //TODO Adjust Terraform to add an NS record into existing Cloud DNS zone

E.g.

```bash
gcloud dns record-sets transaction add --zone="my-zone-name" \
    --name="${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}." \
    --type=NS \
    --ttl=60 "ns-cloud-b1.googledomains.com"

gcloud dns record-sets transaction add --zone="my-zone-name" \
    --name="${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}." \
    --type=NS \
    --ttl=60 "ns-cloud-b2.googledomains.com"
gcloud dns record-sets transaction add --zone="my-zone-name" \
    --name="${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}." \
    --type=NS \
    --ttl=60 "ns-cloud-b3.googledomains.com"
gcloud dns record-sets transaction add --zone="my-zone-name" \
    --name="${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}." \
    --type=NS \
    --ttl=60 "ns-cloud-b4.googledomains.com"
```
> You will need to adjust both the `--zone` value and the final parameter value of each `gcloud dns` command above according to your configuration needs

## Prepare jumpbox and generate service account

```bash
gcloud services enable iam.googleapis.com --async
gcloud services enable cloudresourcemanager.googleapis.com --async
gcloud services enable dns.googleapis.com --async
gcloud services enable sqladmin.googleapis.com --async

sudo apt update --yes && \
sudo apt install --yes jq && \
sudo apt install --yes build-essential && \
sudo apt install --yes ruby-dev && \
sudo gem install cf-uaac
```

```bash
cd ~

FLY_VERSION=5.6.0
wget -O fly.tgz https://github.com/concourse/concourse/releases/download/v${FLY_VERSION}/fly-${FLY_VERSION}-linux-amd64.tgz && \
  tar -xvf fly.tgz && \
  sudo mv fly /usr/local/bin && \
  rm fly.tgz

CT_VERSION=0.8.3
wget -O control-tower https://github.com/EngineerBetter/control-tower/releases/download/${CT_VERSION}/control-tower-linux-amd64 && \
  chmod +x control-tower && \
  sudo mv control-tower /usr/local/bin/

OM_VERSION=4.3.0
wget -O om https://github.com/pivotal-cf/om/releases/download/${OM_VERSION}/om-linux-${OM_VERSION} && \
  chmod +x om && \
  sudo mv om /usr/local/bin/

PIVNET_VERSION=0.0.75
wget -O pivnet https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PIVNET_VERSION}/pivnet-linux-amd64-${PIVNET_VERSION} && \
  chmod +x pivnet && \
  sudo mv pivnet /usr/local/bin/

BOSH_VERSION=6.1.1
wget -O bosh https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${BOSH_VERSION}-linux-amd64 && \
  chmod +x bosh && \
  sudo mv bosh /usr/local/bin/

CREDHUB_VERSION=2.6.1
wget -O credhub.tgz https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${CREDHUB_VERSION}/credhub-linux-${CREDHUB_VERSION}.tgz && \
  tar -xvf credhub.tgz && \
  sudo mv credhub /usr/local/bin && \
  rm credhub.tgz

TF_VERSION=0.11.13
wget -O terraform.zip https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip && \
  unzip terraform.zip && \
  sudo mv terraform /usr/local/bin && \
  rm terraform.zip

TGCP_VERSION=0.95.0
wget -O terraforming-gcp.tar.gz https://github.com/pivotal-cf/terraforming-gcp/releases/download/v${TGCP_VERSION}/terraforming-gcp-v${TGCP_VERSION}.tar.gz && \
  tar -zxvf terraforming-gcp.tar.gz && \
  rm terraforming-gcp.tar.gz

pivnet login --api-token="${PIVNET_UAA_REFRESH_TOKEN}" && \
  pivnet download-product-files --product-slug='pivotal-container-service' --release-version='1.6.0' --product-file-id=528557 && \
  mv pks-linux-amd64-1.6.0-build.225 pks && \
  chmod +x pks && \
  sudo mv pks /usr/local/bin

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
  chmod +x kubectl && \
  sudo mv kubectl /usr/local/bin
```

```bash
gcloud iam service-accounts create p-service --display-name "Pivotal Service Account"

gcloud projects add-iam-policy-binding $(gcloud config get-value core/project) \
  --member "serviceAccount:p-service@$(gcloud config get-value core/project).iam.gserviceaccount.com" \
  --role 'roles/owner'

cd ~
gcloud iam service-accounts keys create 'gcp_credentials.json' \
  --iam-account "p-service@$(gcloud config get-value core/project).iam.gserviceaccount.com"
```

> **Shortcut:** Wait until you've cloned this repository on your jumpbox.  The above are encapsulated and located in the `bin` directory and the scripts are named `02-install-tools-on-jumpbox.sh` and `03-prepare-service-account.sh`.  Make sure you execute these!

## Clone this repo

The scripts, pipelines and config you need to complete the following steps are inside this repo, so clone it to your jumpbox:

```bash
git clone ${GITHUB_PUBLIC_REPO} ~/ops-manager-automation-cc
```

## Create a self-signed certificate

Run the following script to create a certificate and key for the installation:

```bash
DOMAIN=${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME} ~/ops-manager-automation-cc/bin/mk-ssl-cert-key.sh
```

## Configure Terraform

```bash
cat > ~/terraform.tfvars <<-EOF
dns_suffix             = "${PCF_DOMAIN_NAME}"
env_name               = "${PCF_SUBDOMAIN_NAME}"
region                 = "us-west1"
zones                  = ["us-west1-b", "us-west1-a", "us-west1-c"]
project                = "$(gcloud config get-value core/project)"
opsman_image_url       = ""
opsman_vm              = 0
create_gcs_buckets     = "false"
external_database      = 0
isolation_segment      = 0
ssl_cert            = <<SSL_CERT
$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.crt)
SSL_CERT
ssl_private_key     = <<SSL_KEY
$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.key)
SSL_KEY
service_account_key = <<SERVICE_ACCOUNT_KEY
$(cat ~/gcp_credentials.json)
SERVICE_ACCOUNT_KEY
EOF
```

Note the `opsman_image_url == ""` setting which prohibits Terraform from downloading and deploying the Ops Manager VM.
The Concourse pipelines will take responsibility for this.

## Terraform the infrastructure

The PKS and PAS platforms have different baseline infrastructure requirements which are configured from separate dedicated directories.
Terraform is directory-sensitive and needs local access to your customized `terraform.tfvars` files so symlink it in from the home directory.

### If you're targetting PAS ...

```bash
echo "PRODUCT_SLUG=cf" >> ~/.env
cd ~/terraforming/terraforming-pas
ln -s ~/terraform.tfvars .
```

### ... or, if you're targetting PKS

```bash
echo "PRODUCT_SLUG=pivotal-container-service" >> ~/.env
cd ~/terraforming/terraforming-pks
ln -s ~/terraform.tfvars .
```

### Launch Terraform

Confirm you're in the correct directory for your chosen platform and `terraform.tfvars` is present, then execute the following:

```bash
terraform init
terraform apply --auto-approve
```

This will take about 2 mins to complete.

## Install Concourse

We use Control Tower to install Concourse, as follows:

```bash
GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower deploy \
    --namespace "$(uuidgen)" \
    --region us-west1 \
    --iaas gcp \
    --workers 3 \
    ${PCF_SUBDOMAIN_NAME}
```

This will take about 20 mins to complete.

## Persist a few credentials

```bash
NAMESPACE=$(uuidgen)
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

source ~/.env
```

## Verify BOSH and Credhub connectivity

```bash
bosh env
credhub --version
```

## Check Concourse targets and check the pre-configured pipeline:

```bash
fly targets
fly -t control-tower-${PCF_SUBDOMAIN_NAME} pipelines
```

Navigate to the `url` shown for `fly targets`.

Use `admin` user and the value of `CC_ADMIN_PASSWD` to login and see the pre-configured pipeline.

__Note__ `control-tower` will log you in but valid access tokens will expire every 24 hours. The command to log back in is:

```bash
fly -t control-tower-${PCF_SUBDOMAIN_NAME} login --insecure --username admin --password ${CC_ADMIN_PASSWD}
```

## Set up dedicated GCS bucket for downloads

```bash
gsutil mb -c regional -l us-west1 gs://${PCF_SUBDOMAIN_NAME}-concourse-resources
gsutil versioning set on gs://${PCF_SUBDOMAIN_NAME}-concourse-resources
```

## Add a dummy state file

The `state.yml` file is produced by the `create-vm` platform automation task and serves as a flag to indicate that an Ops Manager exists.
We currently store the `state.yml` file in GCS.
The `install-opsman` job also consumes this file so it can short-circuit the `create-vm` task if an Ops Manager does exist.
This is a mandatory input and does not exist by default so we create a dummy `state.yml` file to kick off proceedings.
Storing the `state.yml` file in git may work around this edge case but, arguably, GCS/S3 is a more appropriate home.

```bash
echo "---" > ~/state.yml
gsutil cp ~/state.yml gs://${PCF_SUBDOMAIN_NAME}-concourse-resources/
```

If required, be aware that versioned buckets require you to use `gsutil rm -a` to take files fully out of view.

## Store secrets in Credhub

```bash
credhub set -n pivnet-api-token -t value -v "${PIVNET_UAA_REFRESH_TOKEN}"
credhub set -n domain-name -t value -v "${PCF_DOMAIN_NAME}"
credhub set -n subdomain-name -t value -v "${PCF_SUBDOMAIN_NAME}"
credhub set -n gcp-project-id -t value -v "$(gcloud config get-value core/project)"
credhub set -n opsman-public-ip -t value -v "$(dig +short pcf.${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME})"
credhub set -n gcp-credentials -t value -v "$(cat ~/gcp_credentials.json)"
credhub set -n om-target -t value -v "${OM_TARGET}"
credhub set -n om-skip-ssl-validation -t value -v "${OM_SKIP_SSL_VALIDATION}"
credhub set -n om-username -t value -v "${OM_USERNAME}"
credhub set -n om-password -t value -v "${OM_PASSWORD}"
credhub set -n om-decryption-passphrase -t value -v "${OM_DECRYPTION_PASSPHRASE}"
credhub set -n domain-crt-ca -t value -v "$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.ca.crt)"
credhub set -n domain-crt -t value -v "$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.crt)"
credhub set -n domain-key -t value -v "$(cat ~/certs/${PCF_SUBDOMAIN_NAME}.${PCF_DOMAIN_NAME}.key)"
```

Take a moment to review these settings with `credhub get -n <NAME>`.

## Build the pipeline

Create a `private.yml` to contain the secrets required by `pipeline.yml`:

```bash
cat > ~/private.yml << EOF
---
product-slug: ${PRODUCT_SLUG}
config-uri: ${GITHUB_PUBLIC_REPO}
gcp-credentials: |
$(cat ~/gcp_credentials.json | sed 's/^/  /')
gcs-bucket: ${PCF_SUBDOMAIN_NAME}-concourse-resources
pivnet-token: ${PIVNET_UAA_REFRESH_TOKEN}
credhub-ca-cert: |
$(echo $CREDHUB_CA_CERT | sed 's/- /-\n/g; s/ -/\n-/g' | sed '/CERTIFICATE/! s/ /\n/g' | sed 's/^/  /')
credhub-client: ${CREDHUB_CLIENT}
credhub-secret: ${CREDHUB_SECRET}
credhub-server: ${CREDHUB_SERVER}
EOF
```

Set and unpause the pipeline:

```bash
fly -t control-tower-${PCF_SUBDOMAIN_NAME} set-pipeline -p ${PRODUCT_SLUG} -n \
  -c ~/ops-manager-automation-cc/ci/${PRODUCT_SLUG}/pipeline.yml \
  -l ~/private.yml

fly -t control-tower-${PCF_SUBDOMAIN_NAME} unpause-pipeline -p ${PRODUCT_SLUG}
```

This should begin to execute in ~60 seconds.

Be aware that you may be required to manually accept the PivNet EULAs before a product can be downloaded
so watch for pipeline failures which contain the necessary URLs to follow.

You may also observe that on the first run, the `export-installation` job will fail because the Ops Manager
is missing.
Run this job manually once the `install-opsman` job has run successfully.

## Teardown

The following steps will help you when you're ready to dispose of everything.

### Delete your deployed products and BOSH director:

Use the `om` tool to delete the installation (be careful, you will __not__ be asked to confirm this operation):

```bash
om delete-installation
```

### Delete the Ops Manager VM

```bash
gcloud compute instances delete "ops-manager-vm" --zone "us-west1-a" --quiet
```

### Unwind the remaining PCF infrastructure

If you're targeting PAS ...

```bash
cd ~/terraforming/terraforming-pas
terraform destroy --auto-approve
```

... or, if you're targeting PKS

```bash
cd ~/terraforming/terraforming-pks
terraform destroy --auto-approve
```

### Uninstall Concourse

```bash
GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower destroy \
    --region us-west1 \
    --iaas gcp \
    ${PCF_SUBDOMAIN_NAME}
```

### Otherwise ...

If all else fails, follow [these steps](https://github.com/amcginlay/gcp-cleanup)
