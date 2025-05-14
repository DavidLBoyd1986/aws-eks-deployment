#!/bin/bash

# Replace with your variables:

echo "Starting deployment...."

# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Deploy the Bastion Host VPC and Infrastructure Stacks
echo "Deploy the BH Networking stack"
aws cloudformation deploy --stack-name bh-vpc-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/bastion_host_vpc_deployment.yml

echo "Deploy the BH IAM stack"
aws cloudformation deploy --stack-name bh-iam-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/bastion_host_iam_deployment.yml \
    --capabilities CAPABILITY_IAM

echo "Deploy the BH Infrastructure stack - EC2 Instance with Security Groups"
aws cloudformation create-stack --stack-name bh-infrastructure-stack \
    --template-body file://$SCRIPT_DIR/IaC_Templates/bastion_host_infrastructure_deployment.yml \
    --parameters file://$SCRIPT_DIR/parameters.json \
    --capabilities CAPABILITY_NAMED_IAM

# Deploys the EKS VPC and Infrastructure Stacks
echo "Deploy the EKS Networking stack"
aws cloudformation deploy --stack-name eks-vpc-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/eks_vpc_deployment.yml

echo "Deploy the EKS IAM stack"
aws cloudformation deploy --stack-name eks-iam-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/eks_iam_deployment.yml \
    --capabilities CAPABILITY_NAMED_IAM

# Deploy the VPC Peering Connection Stack - Used to connect BH and EKS VPCs
echo "Deploy VPC Peering Connection so Bastion Hosts can connect to EKS Cluster"
aws cloudformation deploy --stack-name eks-bh-vpc-peering-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/eks_bh_vpc_peering_deployment.yml

echo "Deploy the EKS Infrastructure Stack"
aws cloudformation deploy --stack-name eks-infrastructure-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/eks_infrastructure_deployment.yml

# The rest need to be done manually.
# It is too convoluted to automate since the PC running this script
# can NOT access the Cluster.

# I'd have to dynamically pull bastion-host-ip, and have a specific private key location

# Must SSH into Bastion Host to connect to Cluster
# and run commands to configure cluster and finish deployment

# ------------------------------------------------------------------------------

# SCP/SSH into the linux bastion host is required. 
# Can use either the USER created or ec2-user
# using private key of bastionHostKeyPair

# SCP the kubernetes files to the bastion host

    # scp -i /path/to/bastionHostPrivateKey kubernetes/* ec2-user@<bastion-host-ip>:/home/ec2-user/

# SSH into bastion host using private key of bastionHostKeyPair:

    # ssh -i /path/to/bastionHostPrivateKey ec2-user@<bastion-host-ip>

# Configure kubectl to connect to eks cluster.
    # kubectl version --client
    # aws sts get-caller-identity
    # aws eks update-kubeconfig --region us-east-1 --name EKSHackingCluster
        # TODO - Region here needs updated manually

# Configure Kubernetes:
    # kubectl create namespace vulnerable-${KUBE_NAMESPACE}
    # kubectl apply -f vulnerable-${KUBE_NAMESPACE}-deployment.yml
    # kubectl apply -f service.yml


# Run some test commands
    # kubectl get nodes
    # aws eks describe-nodegroup --cluster-name EKSHackingNodeCluster --nodegroup-name EKSHackingNodeGroup
    # kubectl get all -n vulnerable-${KUBE_NAMESPACE}
    # kubectl -n vulnerable-${KUBE_NAMESPACE} describe service vulnerable-${KUBE_NAMESPACE}-service

echo "Deployment Finished!"