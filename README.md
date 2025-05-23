<h1>Private Cluster - Fully Private Cluster</h1>

IMPORTANT:
- Only the gitlab deployment method is supported for the fully Private Cluster
- The Jenkinsfile and build_script.sh have NOT been updated for this Cluster

This branch deploys an actual Private Cluster. The Cluster only exists in Private Subnets with no traffic able to enter or leave the subnets; There are NO Public Subnets in the VPC.

All required Private Cluster traffic occurs in the VPC, and uses Interface Endpoints to communicate with AWS Services.

All outside traffic occurs from connecting VPCs using Transit Gateways. The Bastion Host VPC is connected to the EKS VPC with a Transit Gateway. So, the Bastion Host VPC can be used to interact with the cluster.

The AWS-LB Controller will still create a Load Balancer, but it will only accept traffic from inside the VPC, as no outside traffic will be able to reach the created Load Balancer.

All images have to be pulled from ECR (obviously) since there is no outside connections. The basic kubernetes pods in the kube-system namespace don't have to be hosted in ECR; EKS takes care of deploying those.

<h2>Differences in this branch:</h2>

- Fully Private Cluster - No Public Subnets in the VPC

- Hosts Images in the ECR repositories as it is the only registry the cluster can access

- Private API Endpoint

- Most of the deployment happens from the Linux Bastion Host
    - Because only IPs inside the EKS VPC can connect to the Private API Endpoint
    - This is done with the eks_deploy_script.sh

- An S3 Bucket is created to copy the eks_deploy_script.sh to/from Bastion Host

- Bastion Host VPC is connected to EKS VPC with a Transit Gateway

- Bastion Host deploys the EKS Cluster so it is given Cluster permissions since it created the Cluster
