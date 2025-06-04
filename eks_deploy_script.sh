#!/bin/bash

# IMPORTANT:
# This is the script that runs off the Bastion Host to configure the cluster

#-------------------
# Variable Assigment
#-------------------
# Deployment specific variables
CLUSTER_NAME=${SCRIPT_CLUSTER_NAME}
KUBE_VERSION=${SCRIPT_KUBE_VERSION}
KUBE_NAMESPACE=${SCRIPT_KUBE_NAMESPACE}
KUBE_LOAD_BALANCER_TYPE=${SCRIPT_KUBE_LOAD_BALANCER_TYPE}
REGION=${SCRIPT_REGION}
APP_PORT=${SCRIPT_APP_PORT}
export HOME=/root
# Get AWS ACCOUNT ID 
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com


#--------------------------------------
# Deploying the Cluster and connections
#--------------------------------------

# IMPORTANT - Run script out of /tmp!!!
# Hard-coded to run the script out of /tmp since it is \
#   designed to be ran automatically after being copied to the host.
#
# i.e.:
#       tar -xvf /tmp/eks_deploy_script.tar -C /tmp/
#       chmod _x /tmp/build_script_deployment/eks_deploy_script.sh
#       /tmp/build_script_deployment/eks_deploy_script.sh
#
# Could easily change this by updating /tmp.

# Deploy the EKS Infrastructure Stack
aws cloudformation deploy --stack-name eks-infrastructure-stack \
    --template-file /tmp/build_script_deployment/IaC/eks_infrastructure_deployment.yml \
    --capabilities CAPABILITY_NAMED_IAM --region $REGION

# TODO - Below didn't fix it. Might delete it if long sleep command solves the problem
# Wait for EKS cluster to become ACTIVE
echo "Waiting for EKS cluster to become ACTIVE..."
CLUSTER_STATUS="INACTIVE"
until [ $CLUSTER_STATUS = "ACTIVE" ]; do
    CLUSTER_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
        --region "$REGION" --query 'cluster.status' --output text)
    echo "Cluster status is not ACTIVE yet. Sleeping for 30 seconds..."
    sleep 30
done
echo "Cluster is ACTIVE."

# Configure kubectl to connect to the Cluster
kubectl version --client
aws sts get-caller-identity
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
whoami
cat /root/.kube/config
cat /home/ec2-user/.kube/config
env | grep AWS
sleep 20
kubectl cluster-info

# Test kubectl configuration/connection to Cluster
kubectl get all -A
#-------------------------------------------
# Deploying the AWS Load Balancer Controller 
#-------------------------------------------

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

# Check if the AWS Load Balancer Controller Service Account exists in kubernetes, and if not, create it:
ALB_CONTROLLER_SA_EXISTS=$(kubectl get serviceaccount \
    aws-load-balancer-controller -n kube-system 2> /dev/null \
    | grep -c aws-load-balancer-controller)

# TEMP TEST - Delete if cluster status loop worked
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
kubectl get all -A

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
        --set serviceAccount.name=aws-load-balancer-controller \
        --set image.repository=${ECR_REGISTRY}/eks/aws-load-balancer-controller \
        --set image.tag=v2.13.2
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

kubectl apply -f /tmp/build_script_deployment/kubernetes/${KUBE_NAMESPACE}-deployment.yml

# Run some test commands:
kubectl get all -n ${KUBE_NAMESPACE}
kubectl get pods -n ${KUBE_NAMESPACE}

#---------------------------------------
# Deploying the EKS Services and AWS LBs
#---------------------------------------

if [ $KUBE_LOAD_BALANCER_TYPE == "NLB" ]; then
    # Create the NLB:
    kubectl apply -f /tmp/build_script_deployment/kubernetes/${KUBE_NAMESPACE}-nlb.yml

    # Wait for deployment: TODO - Add an actual while loop to check
    sleep 180

    # Get the DNS name for the NLB
    NLB_DNS=$(kubectl get svc ${KUBE_NAMESPACE}-nlb-service -n ${KUBE_NAMESPACE} \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    echo $NLB_DNS
    sleep 20

    # Test the application is accessible via the NLB DNS. TODO - Create an actual test
    curl -v http://${NLB_DNS}:${APP_PORT}

    echo "Deployment Complete!"
elif [ $KUBE_LOAD_BALANCER_TYPE == "ALB" ]; then
    # Create the ALB:
    kubectl apply -f /tmp/build_script_deployment/kubernetes/${KUBE_NAMESPACE}-service.yml
    kubectl apply -f /tmp/build_script_deployment/kubernetes/${KUBE_NAMESPACE}-ingress.yml

    # Wait for deployment: TODO - Add an actual while loop to check
    sleep 180

    # Get the DNS name for the ALB
    ALB_DNS=$(kubectl get ingress ${KUBE_NAMESPACE}-ingress -n ${KUBE_NAMESPACE} \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    echo $ALB_DNS
    sleep 20

    # Test the application is accessible via the ALB DNS. TODO - Create an actual test
    curl -v http://${ALB_DNS}:${APP_PORT}

    echo "Deployment Complete!"
else
    echo "ERROR - No valid AWS Load Balancer selected in variable \
        KUBE_LOAD_BALANCER_TYPE"
fi