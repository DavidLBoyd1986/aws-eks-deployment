#!/bin/bash

echo "Starting deployment...."

# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Deploy the Bastion Host VPC and Infrastructure Stacks
echo "Deploy the BH Networking stack"
aws cloudformation deploy --stack-name eks-hacking-bh-vpc-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/bastion_host_vpc_deployment.yml

echo "Deploy the BH Infrastructure stack - EC2 Instance with Security Groups"
aws cloudformation create-stack --stack-name eks-hacking-bh-infrastructure-stack \
    --template-body file://$SCRIPT_DIR/IaC_Templates/bastion_host_infrastructure_deployment.yml \
    --parameters file://$SCRIPT_DIR/parameters.json \
    --capabilities CAPABILITY_IAM

# Deploys the EKS VPC and Infrastructure Stacks
echo "Deploy the EKS Networking stack"
aws cloudformation deploy --stack-name eks-hacking-eks-vpc-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/eks_vpc_deployment.yml

echo "Deploy the EKS IAM stack"
aws cloudformation deploy --stack-name eks-hacking-eks-iam-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/eks_iam_deployment.yml \
    --capabilities CAPABILITY_NAMED_IAM

echo "Deploy the EKS Infrastructure Stack"
aws cloudformation deploy --stack-name eks-hacking-eks-infrastructure-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/eks_infrastructure_deployment.yml

# Must get Target Group ARN to use in Kubernetes Resource Deployments
echo "Get target group ARN from previously deployed stack, to use in EKS Service"
TARGET_GROUP_ARN=$(aws cloudformation describe-stacks \
                    --stack-name eks-hacking-eks-infrastructure-stack \
                    --query "Stacks[0].Outputs[?OutputKey=='EKSHackingALBTargetGroupARN'].OutputValue" \
                    --output text)
echo $TARGET_GROUP_ARN

# Deploy the VPC Peering Connection Stack - Used to connect BH and EKS VPCs
echo "Deploy VPC Peering Connection so Bastion Hosts can connect to EKS Cluster"
aws cloudformation deploy --stack-name eks-hacking-eks-bh-vpc-peering-stack \
    --template-file $SCRIPT_DIR/IaC_Templates/eks_bh_vpc_peering_deployment.yml

# Configure kubectl to connect to eks cluster.
echo "Configuring kubectl to be able to communicate with cluster"
aws eks update-kubeconfig --region us-east-2 --name EKSHackingCluster

# Verify kubectl configuration
echo "verifying kubectl is installed"
kubectl version --client
aws sts get-caller-identity

# Run some test commands
echo "Check nodes were deployed and show as such"
kubectl get nodes
aws eks describe-nodegroup --cluster-name EKSHackingNodeCluster \
    --nodegroup-name EKSHackingNodeGroup

echo "The only user access to the cluster is for the IAM User/Role that created the cluster."
echo "If an authentication error appears, than you are using another IAM User/Role, and must add them to the EKS Cluster"
kubectl get svc

# Deploys necessary kubernetes resources to cluster
echo "Creating vulnerable-web-app namespace if necessary."
if kubectl get namespace vulnerable-web-app &> /dev/null; then
    echo "Namespace vulnerable-web-app exists.";
else
    echo "Creating vulnerable-web-app namespace";
    kubectl create namespace vulnerable-web-app
fi

echo "Apply the deployment manifest to your cluster/namespace...."
kubectl apply -f $SCRIPT_DIR/kubernetes/vulnerable-web-app-deployment.yml

# Need to create separate file to swap out TARGET_GROUP_ARN with the target group of the created ALB
cp $SCRIPT_DIR/kubernetes/vulnerable-web-app-service-template.yml $SCRIPT_DIR/vulnerable-web-app-service.yml
sed "s/{{TARGET_GROUP_ARN}}/$TARGET_GROUP_ARN/g" vulnerable-web-app-service.yml

echo "Apply the service manifest to your cluster/namespace...."
kubectl apply -f $SCRIPT_DIR/kubernetes/vulnerable-web-app-service.yml

# Tests the application deployed successfully
echo "View the created kubernetes resources"
kubectl get all -n vulnerable-web-app
echo "......\n"

echo "View the details of the deployed service"
kubectl -n vulnerable-web-app describe service vulnerable-web-app-service
echo "......\n"

echo "Deployment Finished!"