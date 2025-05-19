<h1>EKS Cluster and Bastion Host Deployment</h1>

This repository contains CloudFormation templates to launch an EKS Cluster in its own VPC, Bastion Hosts in a separate VPC, and a VPC Peering Connection to connect the two VPCS. It also contains the Kubernetes Resource yaml files to deploy an application (WebGoat) to the Cluster, and create an external connection to the application using an AWS Load Balancer Controller that can be used to automatically create an AWS NLB or AWS ALB depending on the Kubernetes resources that are created. Lastly, it contains multiple deployment methods: shell script, Jenkinsfile, and gitlab.ci file.

For external connections to the application on EKS, the deployment methods deploy an AWS Load Balancer Controller to the EKS Cluster so NLBs and ALBs will automatically be created when a Kubernetes Service/Ingress is created for an application. These AWS Load Balancers will automatically allow/route all public access to the applications/deployments they point to on EKS.

<b>IMPORTANT - So, the applications on the Public Cluster will always be 100% publically accessible from any IP. All the discussion of limiting Public Access to the Cluster is in regards to accessing the Cluster API server endpoint (i.e. connecting to the cluster with "kubectl", "helm", etc...) See the section "Limiting Public Cluster traffic" below for a longer explanation.</b>

Cluster Api Server Endpoints explained - https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html


<h2>Public and Private Clusters</h2>

The main branch deploys a Public Cluster, as does the 'public-cluster' branch, where the Cluster API Endpoint is publically accessible, but still limits access based on IAM and EKS RBAC authentication. The 'private-cluster' branch creates a private EKS Cluster where the Cluster API Endpoint is only accessible from within the EKC VPC, or the BH VPC which has a peering connection. Both the Public and Private Clusters can allow full public access to applications based on the Load Balancers that route to them.

I plan to make a fully private cluster in the future, if it is possible.

NOTE - The "private-cluster" branch is not finished!

<h3>Public Clusters</h3>

NOTE - I am going to refactor the PUBLIC_IP_RANGE names and functionality to make sense.

The Public Cluster Endpoint access is currently limited to a defined "personalPublicIp" that is in the parameters.json files under "./parameters" and currently has a value of "$PUBLIC_IP_RANGE". Whatever IP is saved as "$PUBLIC_IP_RANGE" will be given a /32 subnet mask, and it will limit public traffic to the Cluster API Endpoint to only the defined personalPublicIp.

<h4>Creating a fully public cluster:</h4>

To make the accessing Public Cluster API Endpoint on 'main' and 'public-cluster' branches fully public, all you do is remove the "personalPublicIp" from both parameters.json files.

    i.e. remove the below from "bh_infrastructure_parameters.json" and "parametes/eks_vpc_parameters.json":
    
    `
    {
      "ParameterKey": "personalPublicIp",
      "ParameterValue": "$PUBLIC_IP_RANGE"
    },
    `

Removing those parameters will cause the CloudFormation templates to give the SecurityGroups a rule that allows "0.0.0.0/0". Access will still be limited based on IAM and/or RBAC permissions.

<h4>Limiting Cluster Endpoint traffic</h4>

The Bastion Hosts will be able to access the Cluster, as the "BastionHostInstanceRole" is trusted by the Cluster during deployment, and the Bastion Hosts come with kubectl, helm, and eksctl installed; however, you will have to run the command below to configure kubectl to authenticate to the cluster.

    `aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME`

For Public Clusters, the personalPublicIp parameter is only for the Deployment methods, that are deploying everything, to have access to run kubectl commands to setup and configure the Cluster. After the deployment is complete, the EKS NodeGroup Security Group rules allowing access from the personalPublicIp can be removed, and all future cluster interactions can be performed from the Linux Bastion Host using kubectl.

The personalPublicIP is defined as a range, so to limit it to one IP use this format:

    1.2.3.4/32

To make the Cluster API Endpoint fully publicly accessible, remove the personalPublicIp parameters from the parameters.json files, and the personalPublicIp variable will default to 0.0.0.0/0. THIS IS NOT RECOMMENDED.

A completely private EKS Cluster deployment will be created as a separate branch in the future.

<h2>What is Deployed</h2>

<h3>The CloudFormation Templates deploy:</h3>

- EKS VPC - The EKS Cluster is deployed in its own VPC
- Bastion Host VPC - Two Bastion hosts are deployed in their own VPC
- VPC Peering Connection - The EKS and Bastion Hosts are fully connected via a VPC Peering Connection
- BH IAM Resources - Role, policies and Instance Profile are created for the Bastion Hosts.
- EKS IAM Resources - Two Roles are created: EKS Cluster Role and EKS Node Role
- BH Infrastructure - Two ec2 instances are deployed as Bastion Hosts (Linux and Windows)
- EKS Infrastructure - The EKS Cluster and Node Group are created with 1 Running Node

<h3>The Kubernetes Resources deployed:</h3>

- AWS Load Balancer Controller - This is used to automatically create AWS Load Balancers based on created Kubernetes resources that allow/route external access to the cluster: (i.e. Services and Ingress). This will create an IAM Policy and Role to be used by the EKS Cluster, specifically used by a ServiceAccount inside the Cluster.

AWS Load Balancer Controller Docs:
- https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

- Kubernetes Deployment - Deploys WebGoat web application (used for pentesting)
- Kubernetes Services - Deploys Kubernetes services based on if you selected to deploy an AWS NLB/ALB.

     - NLB Load Balancer - Deploys a kubernetes LoadBalancer Service that will create an NLB
     - ALB Load Balancer - Deploys a kubernetes ClusterIP Service and an Ingress that will create an ALB

<h3>Deployment Methods:</h3>

- .gitlab-ci.yml - A Gitlab pipeline that will deploy everything. Only requires gitlab/gitlab-runners have met the pre-requisites listed below.

- Jenkinsfile - A Jenkins pipeline that will deploy everything. Only requires jenkins-master/worker-nodes have met the pre-requisites listed below.

- build_script.sh - A shell script that will deploy everything. Only requires the host running the script has met the pre-requisites listed below.

<h2>Prerequisites</h2>

1. The aws-cli is installed and configured:
    1. Install aws-cli
    2. Configure aws-cli with access key or IAM Role

2. An ssh-keypair has been created to allow access to the Bastion Hosts
    1. ssh-keygen -t rsa -m PEM -b 2048 -f ~/.ssh/aws_bh_id_rsa
        - You can leave off the -f argument to save it here ~/.ssh/id_rsa
        - This could overwrite an existing ssh-key for the user you're using.
    2. Look in '~/.ssh/' and copy the contents of 'id_rsa.pub' 
    3. Paste this in '/IaC_Templates/bastion_host_infrastructure_deployment.yml' under parameters for 'bastionHostPublicKey'

    LINUX NOTE - This key is also configured for the 'userName' configured under parameters.
               - So, you can log in with this key for Linux as 'ec2-user' or the configured user.

    WINDOWS NOTE - The ssh key can be used to decipher the 'Administrator' password for windows.
                 - Use 'connect' under the ec2 instance to decipher the password.
                 - 'userName' added can log into windows instance with 'userPass' configured.
                 - Logging into windows with configured user and password isn't working right now. 

3. Required Parameters need configured as CICD or Environment Variables:
    - PUBLIC_IP_RANGE
    - BASTION_USERNAME
    - BASTION_PASSWORD

4. Other Parameters that can be added directly into Parameters file:
    - bastionHostPublicKey
    - EKSPublicKey
