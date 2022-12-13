#!/bin/bash
echo starting.....

#Need to go to here and enable and add credentials
#https://console.cloud.google.com/apis/api/cloudresourcemanager.googleapis.com/metrics?project=master-no-sm

# ADD VARAIBALE HERE FOR ZONES ETC
PROJECT_ID=master-no-sm
ZONE=europe-north1-a
CLUSTER_NAME=testing-cluster
NODE_POOL_NAME=adservice
#set project
echo Setting Project
gcloud config set project $PROJECT_ID


# SET REGION
echo SETTING REGION
gcloud config set compute/zone $ZONE


#creating cluster
echo CREATING CLUSTER
gcloud container clusters create $CLUSTER_NAME


#GET CREDENTIALS
echo "RETRIVE CLUSTER CREDS..."
gcloud container clusters get-credentials $CLUSTER_NAME


#CREATE CLUSTER WITH NODE POOL AND AUTOSCALING:  MIN 1 MAX 6
echo "CREATE NODE POOL:  MIN 1 MAX 6"
gcloud container node-pools create adservice  --cluster testing-cluster --enable-autoscaling --num-nodes=1 --min-nodes=1 --max-nodes=6 --machine-type=e2-standard-2 --node-labels=type=adservice

#DELETING DEFAULT POOL
echo "Delete DEFAULT POOLS"
gcloud container node-pools delete default-pool --cluster=NODE_POOL_NAME<<-EOF
y
EOF

