#!/bin/bash
#

# Create Gcloud Instance
echo Creating Virtual Machine
gcloud compute instances create ghz-instance --project=master-no-sm --zone=europe-north1-a --machine-type=e2-medium --network-interface=network-tier=PREMIUM,subnet=default --maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=1039864797421-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --tags=http-server,https-server --create-disk=auto-delete=yes,boot=yes,device-name=instance-1,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20221018,mode=rw,size=10,type=projects/master-no-sm/zones/europe-north1-a/diskTypes/pd-balanced --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any

#Copy VM Library Install here
echo Copying scripts and files to VM
gcloud compute scp  ~/install_vm_apps.sh ghz-instance:/home/james

# SEND MICROSERVICE PROJECT TO REMOTE TESTING MACHINE
gcloud compute scp --recurse ~/microservices-demo ghz-instance:/home/james

#copy proto file
gcloud compute scp  ~/microservices-demo/src/adservice/src/main/proto/demo.proto ghz-instance:/home/james

#copy  test scripts
gcloud compute scp  ~/adservice_test.sh ghz-instance:/home/james
gcloud compute scp  ~/currency_test.sh ghz-instance:/home/james

#copy  cluster setup  scripts
gcloud compute scp  ~/setup_cluster_ad.sh ghz-instance:/home/james
gcloud compute scp  ~/setup_cluster_currency.sh ghz-instance:/home/james

# SSH INTO MACHINE
gcloud compute ssh --zone "europe-north1-a" "james@ghz-instance"  --project "master-no-sm"

