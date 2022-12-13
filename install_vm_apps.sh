#!/bin/bash
#

echo updating server
sudo apt update

# install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# install jp for later
echo Installing jq
sudo apt install jq <<-EOF
y
EOF

# Install GoLang
echo Installing Golang

curl -OL https://golang.org/dl/go1.19.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.19.3.linux-amd64.tar.gz
echo "export PATH=$PATH:/usr/local/go/bin" >> $HOME/.profile
. ~/.profile
. $HOME/.profile



#Install GHZ Load Tester
echo Installing GHZ
git clone https://github.com/bojand/ghz
cd ghz/cmd/ghz
go mod tidy
go build .
echo "export PATH=$PATH:/ghz/cmd/ghz" >> $HOME/.profile
. ~/.profile
. $HOME/.profile

##
#login in to get GCLOUD CREDs
echo Installing GCLOUD CLI
sudo apt-get install apt-transport-https ca-certificates gnupg<<-EOF
y
EOF

echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.gpg

sudo apt-get update && sudo apt-get install google-cloud-cli

sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin

#gcloud init
