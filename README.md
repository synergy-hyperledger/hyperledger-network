# hyperledger-network
Hyperledger network setup and configuration

# Setup CentOS8/RHEL8

Note: Ensure to have a static IP address.

yum update -y <br>
yum install -y epel-release.noarch <br>
yum install -y yum-utils <br>
yum install -y jq.x86_64 <br>
yum install -y tree.x86_64 <br>

systemctl disable firewalld <br>
yum remove -y podman.x86_64 <br>
yum remove -y buildah.x86_64 <br>

# Install Docker
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo <br>
yum install -y docker-ce docker-ce-cli containerd.io <br>
systemctl enable --now docker <br>
systemctl status docker <br>

# Install Docker Compose 
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose <br>
chmod +x /usr/local/bin/docker-compose <br>
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose <br>

# Application User (non-root)
useradd bcuser <br>
usermod -aG docker bcuser <br>

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
- Copy/share the Org2 MSP to Org1 server 
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


Note: Orderer MSP must be shared to all Organizations (Tested with One Orderer running at Org1)

