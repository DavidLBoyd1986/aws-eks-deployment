#!/bin/bash

# Variable Assigment:

# Deployment specific variables
CLUSTER_NAME=EKSPublicCluster
KUBE_VERSION="1.32"
KUBE_NAMESPACE=web-app
KUBE_LOAD_BALANCER_TYPE=NLB # Must be (NLB || ALB)
REGION=us-east-1
# Required CICD Variables:
    # ex: export PERSONAL_PUBLIC_IP="11.22.33.44"
BASTION_USERNAME=$BASTION_USERNAME
BASTION_PASSWORD=$BASTION_PASSWORD
PERSONAL_PUBLIC_IP=$PERSONAL_PUBLIC_IP 
# Possible Future Additions:
#IMAGE_REGISTRY=
#IMAGE_REPOSITORY=
#IMAGE_TAG=

#--------------------------
# Replace/Prepare variables
#--------------------------

# Build_script.sh Deployment requires copying the files to ./build_script_deployment
# This is so, only the copies in ./build_script_deployment are updated with the parameters.
# And the script can be ran repeatedly.

# Clean up the directory
rm -rf build_script_deployment/*

# Copy the original files, so they can be safely updated and deployed from this folder
cp -rp parameters/ IaC/ kubernetes/ build_script_deployment/

# Get newest version of HELM to be installed in the Linux Bastion Host:
HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest \
    | grep tag_name | cut -d '"' -f 4)
echo $HELM_VERSION

PUBLIC_IP_RANGE=${PERSONAL_PUBLIC_IP}/32
echo $PUBLIC_IP_RANGE

# Replace variables in the CloudFormation files:
sed -i "s|\\\$PUBLIC_IP_RANGE|${PUBLIC_IP_RANGE}|g" ./build_script_deployment/parameters/eks_vpc_parameters.json
sed -i "s|\\\$PUBLIC_IP_RANGE|${PUBLIC_IP_RANGE}|g" ./build_script_deployment/parameters/bh_infrastructure_parameters.json
sed -i "s|\\\$BASTION_USERNAME|${BASTION_USERNAME}|g" ./build_script_deployment/parameters/bh_infrastructure_parameters.json
sed -i "s|\\\$BASTION_PASSWORD|${BASTION_PASSWORD}|g" ./build_script_deployment/parameters/bh_infrastructure_parameters.json
sed -i "s|\\\$CLUSTER_NAME|${CLUSTER_NAME}|g" ./build_script_deployment/parameters/bh_infrastructure_parameters.json
sed -i "s|\\\$KUBE_VERSION|${KUBE_VERSION}|g" ./build_script_deployment/parameters/bh_infrastructure_parameters.json
sed -i "s|\\\$HELM_VERSION|${HELM_VERSION}|g" ./build_script_deployment/parameters/bh_infrastructure_parameters.json

# Replace variables in the Kubernetes files:
sed -i "s|\\\$KUBE_NAMESPACE|${KUBE_NAMESPACE}|g" ./build_script_deployment/kubernetes/web-app-deployment.yml
sed -i "s|\\\$KUBE_NAMESPACE|${KUBE_NAMESPACE}|g" ./build_script_deployment/kubernetes/web-app-ingress.yml
sed -i "s|\\\$KUBE_NAMESPACE|${KUBE_NAMESPACE}|g" ./build_script_deployment/kubernetes/web-app-nlb.yml
sed -i "s|\\\$KUBE_NAMESPACE|${KUBE_NAMESPACE}|g" ./build_script_deployment/kubernetes/web-app-service.yml

# Get AWS ACCOUNT ID 
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

#Get AMI ID for the aws-eks-optimized AMIs for the region and specific kubernetes version
AMI_ID=$(aws ssm get-parameter \
    --name /aws/service/eks/optimized-ami/${KUBE_VERSION}/amazon-linux-2/recommended/image_id \
    --region ${REGION} --query 'Parameter.Value' --output text)

# Replace the variables ($CLUSTER_NAME) in other files with the actual values:
sed -i "s|\\\$CLUSTER_NAME|${CLUSTER_NAME}|g" ./build_script_deployment/IaC/eks_infrastructure_deployment.yml
sed -i "s|\\\$AMI_ID|${AMI_ID}|g" ./build_script_deployment/IaC/eks_infrastructure_deployment.yml

# Test the variables were replaced successfully
cat ./parameters/bh_infrastructure_parameters.json
cat ./parameters/eks_vpc_parameters.json

echo "Variable preparation is complete."

#------------------------------------
# Deploying the CloudFormation Stacks
#------------------------------------

# Deploy the BH VPC Stack
aws cloudformation deploy --stack-name bh-vpc-stack \
    --template-file ./build_script_deployment/IaC/bastion_host_vpc_deployment.yml --region $REGION

# Deploy the EKS VPC Stack
EKS_VPC_EXISTS=$(aws cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE | grep -c eks-vpc-stack)

if [ $EKS_VPC_EXISTS -gt 0 ]; then
    echo "The eks-vpc-stack already exists. Skipping this step....";
else
    echo "Creating the eks-vpc-stack";
    aws cloudformation create-stack --stack-name eks-vpc-stack \
        --template-body file://./build_script_deployment/IaC/eks_vpc_deployment.yml \
        --parameters file://./build_script_deployment/parameters/eks_vpc_parameters.json \
        --capabilities CAPABILITY_NAMED_IAM --region $REGION;
fi

# Deploy the BH IAM stack
aws cloudformation deploy --stack-name bh-iam-stack \
    --template-file ./build_script_deployment/IaC/bastion_host_iam_deployment.yml \
    --capabilities CAPABILITY_IAM --region $REGION
# Deploy the EKS IAM stack
aws cloudformation deploy --stack-name eks-iam-stack \
    --template-file ./build_script_deployment/IaC/eks_iam_deployment.yml \
    --capabilities CAPABILITY_NAMED_IAM --region $REGION
# Deploy VPC Peering Connection so Bastion Hosts can connect to EKS Cluster
aws cloudformation deploy --stack-name eks-bh-vpc-peering-stack \
    --template-file ./build_script_deployment/IaC/eks_bh_vpc_peering_deployment.yml --region $REGION
# Deploy the EKS Infrastructure Stack
aws cloudformation deploy --stack-name eks-infrastructure-stack \
    --template-file ./build_script_deployment/IaC/eks_infrastructure_deployment.yml \
    --capabilities CAPABILITY_NAMED_IAM --region $REGION

# Deploy the BH Infrastructure Stack

BH_INFRA_EXISTS=$(aws cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE \
    | grep -c bh-infrastructure-stack)
if [ $BH_INFRA_EXISTS -gt 0 ]; then
    echo "The bh-infrastructure-stack already exists. Skipping this step....";
else
    echo "Creating the bh-infrastructure-stack";
    aws cloudformation create-stack --stack-name bh-infrastructure-stack \
        --template-body file://./build_script_deployment/IaC/bastion_host_infrastructure_deployment.yml \
        --parameters file://./build_script_deployment/parameters/bh_infrastructure_parameters.json \
        --capabilities CAPABILITY_NAMED_IAM --region $REGION
fi

echo "CloudFormation deployment is complete."

#----------------------------------
# Deploying the Cluster Connections
#----------------------------------

# Configure kubectl to connect to the Cluster
kubectl version --client
aws sts get-caller-identity
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Allow Bastion Host's IAM Role to access the Cluster
BASTION_HOST_ROLE_ARN=$(aws cloudformation describe-stacks \
    --stack-name bh-iam-stack --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='BastionHostRoleArn'].OutputValue" \
    --output text)

echo $BASTION_HOST_ROLE_ARN

eksctl create iamidentitymapping --cluster $CLUSTER_NAME --region $REGION \
    --arn $BASTION_HOST_ROLE_ARN --username system:node:{{EC2PrivateDNSName}} \
    --group system:masters

#-------------------------------------------
# Deploying the AWS Load Balancer Controller 
#-------------------------------------------

# Connect to the Cluster again - needs done for every stage
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# AWS Load Balancer Controller IAM Policy Name
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"

# Check if AWSLoadBalancerControllerIAMPolicy exists, and if not, create it:
ALB_CONTROLLER_IAM_POLICY_EXISTS=$(aws iam list-policies --scope Local \
    --query "Policies[?PolicyName=='${POLICY_NAME}']" \
    | grep -c ${POLICY_NAME})

if [ $ALB_CONTROLLER_IAM_POLICY_EXISTS -gt 0 ]; then
    echo "The policy ${POLICY_NAME} already exists. Skipping this step..."
else
    curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.12.0/docs/install/iam_policy.json
    aws iam create-policy --policy-name ${POLICY_NAME} --policy-document file://iam_policy.json
fi

# Get AWS ACCOUNT ID 
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Check if the AWS Load Balancer Controller Service Account exists in kubernetes, and if not, create it:
ALB_CONTROLLER_SA_EXISTS=$(kubectl get serviceaccount \
    aws-load-balancer-controller -n kube-system 2> /dev/null \
    | grep -c aws-load-balancer-controller)

if [ $ALB_CONTROLLER_SA_EXISTS -gt 0 ]; then
    echo "The AWS Load Balancer Controller Service Account already exists. \
        Skipping this step..."
else
    eksctl utils associate-iam-oidc-provider --region $REGION --cluster $CLUSTER_NAME --approve
    eksctl create iamserviceaccount --cluster=$CLUSTER_NAME --namespace=kube-system \
        --name=aws-load-balancer-controller --role-name=AWSLoadBalancerController \
        --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME} \
        --override-existing-serviceaccounts --region $REGION --approve
fi

# Have to sleep to give time for everything to get created:
sleep 30

# Test the IAM Role was created automatically when creating the iamserviceaccount:
aws iam get-role --role-name AWSLoadBalancerController

# Test the ServiceAccount was created:
kubectl get serviceaccount aws-load-balancer-controller --namespace kube-system --output yaml

# Check if the AWS Load Balancer Controller is deployed, and if not, deploy it:
ALB_CONTROLLER_EXISTS=$(kubectl get deployment aws-load-balancer-controller \
    -n kube-system -o jsonpath='{.status.availableReplicas}' 2> /dev/null)

echo $ALB_CONTROLLER_EXISTS

if [ $ALB_CONTROLLER_EXISTS -gt 0 ]; then
    echo "The AWS Load Balancer Controller already exists. Skipping this step..."
else
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update eks
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller
    sleep 20
fi

# What until the Load Balancer is launched
# I think sleeping for 20 seconds makes this check unnecessary.

# Check if the AWS Load Balancer Controller is (finally) installed
kubectl get all -n kube-system \
    --selector app.kubernetes.io/name=aws-load-balancer-controller

#---------------------------------
# Deploying the Application to EKS 
#---------------------------------

# If the namespace doesn't exist, then create it:
NAMESPACE_EXISTS=$(kubectl get namespace web-app 2> /dev/null | grep -c web-app)

if [ $NAMESPACE_EXISTS -gt 0 ]; then
    echo "Namespace ${KUBE_NAMESPACE} exists.";
else
    echo "Creating ${KUBE_NAMESPACE} namespace";
    kubectl create namespace ${KUBE_NAMESPACE}
fi

kubectl apply -f ./build_script_deployment/kubernetes/${KUBE_NAMESPACE}-deployment.yml

# Run some test commands:
kubectl get all -n ${KUBE_NAMESPACE}
kubectl get pods -n ${KUBE_NAMESPACE}

#---------------------------------------
# Deploying the EKS Services and AWS LBs
#---------------------------------------

if [ $KUBE_LOAD_BALANCER_TYPE == "NLB" ]; then
    # Create the NLB:
    kubectl apply -f ./build_script_deployment/kubernetes/${KUBE_NAMESPACE}-nlb.yml

    # Wait for deployment: TODO - Add an actual while loop to check
    sleep 180

    # Get the DNS name for the NLB
    NLB_DNS=$(kubectl get svc ${KUBE_NAMESPACE}-nlb-service -n ${KUBE_NAMESPACE} \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    echo $NLB_DNS
    sleep 20

    # Test the application is accessible via the NLB DNS. TODO - Create an actual test
    curl -v http://${NLB_DNS}:8080/WebGoat/login

    echo "Deployment Complete!"
elif [ $KUBE_LOAD_BALANCER_TYPE == "ALB" ]; then
    # Create the ALB:
    kubectl apply -f ./build_script_deployment/kubernetes/${KUBE_NAMESPACE}-service.yml
    kubectl apply -f ./build_script_deployment/kubernetes/${KUBE_NAMESPACE}-ingress.yml

    # Wait for deployment: TODO - Add an actual while loop to check
    sleep 180

    # Get the DNS name for the ALB
    ALB_DNS=$(kubectl get ingress ${KUBE_NAMESPACE}-ingress -n ${KUBE_NAMESPACE} \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    echo $ALB_DNS
    sleep 20

    # Test the application is accessible via the ALB DNS. TODO - Create an actual test
    curl -v http://${ALB_DNS}:8080/WebGoat/login

    echo "Deployment Complete!"
else
    echo "ERROR - No valid AWS Load Balancer selected in variable \
        KUBE_LOAD_BALANCER_TYPE"
fi