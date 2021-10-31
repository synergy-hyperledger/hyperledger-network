# hyperledger-network
Hyperledger network setup and configuration

# Setup CentOS8/RHEL8

Note: Ensure to have a static IP address.

yum update -y
yum install -y epel-release.noarch
yum install -y yum-utils
yum install -y jq.x86_64

systemctl disable firewalld
yum remove -y podman.x86_64
yum remove -y buildah.x86_64

# Install Docker
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io
systemctl enable --now docker
systemctl status docker

# Install Docker Compose 
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Application User (non-root)
useradd bcuser
usermod -aG docker bcuser

# Install HLF (login as non-root user ‘bcuser’)

curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.2.1 1.4.9

# Pull couchdb docker images
docker pull couchdb:3.1.1

# Network setup (e.g. mytest-network)
download the repo as ZIP file and extract to your PWD (you may remove org-samples)

Note: you refer the org-samples for directory structure reference.

# Form network with Org1 & Org2
- update the hlf_vars file to your Org requirements
- Run the hlf_setup.sh script to create the CAs and the network structure for Org1
- Run the hlf_setup.sh script to create the CAs and the network structure for Org2
- Copy the Org2 MSP to Org1 server 
- Run the start_org1.sh to start the Org1
- Run the start_org2.sh to start the Org2

# Add Org3
- update the hlf_vars file to your Org requirements
- Run the hlf_setup.sh script to create the CAs and the network structure for Org3
- Run add_org_req.sh to generate Org3 request
- Please share this request file to Org1 to update in the network channel
- Run add_org.sh in Org1 server (after placing the Org3 request file in channel-artifacts directory)
- Please share the Chennal pb file to Org2 to endorse
- Run add_org_endorse.sh in Org2 server (after placing the pb file in channel-artifacts directory)
- Then run start_org3.sh to start the Org3 in Org3 server.


Note: Orderer MSP must be shared to all Organizations.

