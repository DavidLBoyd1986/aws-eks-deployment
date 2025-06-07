<h1>EKS Cluster and Bastion Host Deployment</h1>

This repository contains CloudFormation templates to launch an EKS Cluster in its own VPC, Bastion Hosts in a separate VPC, and a VPC Peering Connection to connect the two VPCS; the private-clusters use a Transit Gateway to connect the VPCs not a VPC Peering Connection. It also contains the Kubernetes Resource yaml files to deploy an application (WebGoat) to the Cluster, and create an external connection to the application using an AWS Load Balancer Controller that can be used to automatically create an AWS NLB or AWS ALB depending on the Kubernetes resources that are created. Lastly, it contains multiple deployment methods: shell script, Jenkinsfile, and gitlab.ci file.

For external connections to the application on EKS, the deployment methods deploy an AWS Load Balancer Controller to the EKS Cluster so NLBs and ALBs will automatically be created when a Kubernetes Service/Ingress is created for an application. These AWS Load Balancers will automatically allow/route all public access to the applications/deployments they point to on EKS.

<b>IMPORTANT:

- The applications on the public-cluster branch will always be 100% publically accessible from any IP; hence, public-cluster.
- The private-cluster-endpoint branch deploys a cluster with a private endpoint, and the applications launched on the cluster are only available from the bastion hosts, but it can be changed to be accessible from any public ip.
- The private-cluster-fully-private has no access outside the AWS VPCs; hence 'fully-private'.</b>

See the section "Public and Private Clusters" below for a longer explanation.

See this documentation for an explanation of the difference between public/private API Endpoints:

- https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html

<h2>Public and Private Clusters</h2>

The 'main' branch deploys a Public Cluster, as does the 'public-cluster' branch, where the Cluster API Endpoint is publically accessible, but still limits access based on IAM and EKS RBAC authentication. <b>The applications launched on this cluster are fully accessible to the public internet.</b>

The 'private-cluster-endpoint' branch creates a private EKS Cluster where the Cluster API Endpoint is only accessible from within the EKC VPC, or the BH VPC which is connected to the EKS VPC with a transit gateway. Applications launched on this cluster can allow full public access based on the Load Balancers that route to them. This is done by changing the value of the service/ingress annotation "service.beta.kubernetes.io/aws-load-balancer-scheme: internal" to "internet-facing".

The 'private-cluster-fully-private' branch deploys a completely private cluster. This cluster is only accessible from within the EKS VPC it is launched in, but can be accessed from the bastion host VPC because it is connected to the EKS VPC with a transit gateway. Since the cluster is fully private any image launched on it needs to come from the ECR Registry, and any access to AWS services from the Cluster requires AWS Service Endpoints.

<h4>Limiting Cluster Endpoint traffic</h4>

The Bastion Hosts will be able to access the Cluster on any of the branches, as the "BastionHostInstanceRole" is added to the configmap of the Cluster during deployment, and the bastion hosts have kubectl, helm, and eksctl installed; however, you will have to run the command below to configure kubectl to authenticate to the cluster.

    `aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME`

The personalPublicIp parameter is only for limiting access to the bastion hosts, and the public-cluster endpoint.

The personalPublicIP is defined as a range, so to limit it to one IP it uses this format:

    1.2.3.4/32

<h2>What is Deployed</h2>

<h3>The CloudFormation Templates deploy:</h3>

- EKS VPC - The EKS Cluster is deployed in its own VPC
- Bastion Host VPC - Two Bastion hosts are deployed in their own VPC
- VPC Peering Connection - The EKS and Bastion Hosts are fully connected via a VPC Peering Connection
- BH IAM Resources - Role, policies and Instance Profile are created for the Bastion Hosts.
- EKS IAM Resources - Two Roles are created: EKS Cluster Role and EKS Node Role
- BH Infrastructure - Two ec2 instances are deployed as Bastion Hosts (Linux and Windows)
- EKS Infrastructure - The EKS Cluster and Node Group are created with 1 Running Node
- ECR Repostiory - For the Image being deployed

Private Clusters:
- Transit gateway - The private-clusters require this to access the private clusters endpoint.

<h3>The Kubernetes Resources deployed:</h3>

- AWS Load Balancer Controller - This is used to automatically create AWS Load Balancers based on created Kubernetes resources that allow/route external access to the cluster: (i.e. Services and Ingress). This will create an IAM Policy and Role to be used by the EKS Cluster, specifically used by a ServiceAccount inside the Cluster.

AWS Load Balancer Controller Docs:
- https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

- Kubernetes Deployment - Deploys WebGoat web application (used for pentesting)
- Kubernetes Services - Deploys Kubernetes services based on if you selected to deploy an AWS NLB/ALB.

     - NLB Load Balancer - Created by deploying a kubernetes LoadBalancer Service
     - ALB Load Balancer - Created by deploying a kubernetes Ingress, requires a ClusterIP Service as well

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
    - REGION
    - BASTION_USERNAME
    - BASTION_PASSWORD
    - PERSONAL_PUBLIC_IP
    - ECR_REGISTRY

4. Other Parameters that can be added directly into Parameters file:
    - bastionHostPublicKey
    - EKSPublicKey
