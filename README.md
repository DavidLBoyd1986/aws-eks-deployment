<h1>Private Cluster - Fully Private Cluster</h1>

This branch deploys an actual Private Cluster. The Cluster only exists in Private Subnets with no traffic able to enter or leave the subnets; There are NO Public Subnets in the VPC.

All required Private Cluster traffic occurs in the VPC, and uses Interface Endpoints to communicate with AWS Services.

All outside traffic occurs from connecting VPCs using Transit Gateways.

The AWS-LB Controller will still create a Load Balancer, but it will only accept traffic from inside the VPC, as no outside traffic will be able to reach the created Load Balancer.

<h2>Differences in this branch:</h2>

- Private API Endpoint

- Most of the deployment happens from the Linux Bastion Host
    - Because only IPs inside the EKS VPC can connect to the Private API Endpoint
    - This is done with the eks_deploy_script.sh

- An S3 Bucket is created to copy the eks_deploy_script.sh to/from Bastion Host

- Bastion Host VPC is connected to EKS VPC with a Transit Gateway
    - The main branch connects them with a VPC Peering connection
    - VPC Peering doesn't allow connections to the private endpoint from connected VPC.

- Bastion Host deploys the EKS Cluster so it is given Cluster permissions since it created the Cluster
