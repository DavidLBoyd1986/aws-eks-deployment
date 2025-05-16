<h1>EKS Cluster and Bastion Host Deployment</h1>

This repository contains CloudFormation templates to launch an EKS Cluster in its own VPC, Bastion Hosts in a separate VPC, and a VPC Peering Connection to connect the two VPCS. It also contains the Kubernetes Resource yaml files to deploy an application (WebGoat) to the Cluster, and create an external connection to the application. Lastly, it contains multiple deployment methods: shell script, Jenkinsfile, and gitlab.ci file.

Only the Jenkinsfile is finished to fully deploy everything.

The deployment methods deploy an AWS Load Balancer Controller to the EKS Cluster so NLBs and ALBs will automatically be created when a Kubernetes Service/Ingress is created for an application.

<h2>Public and Private Clusters</h2>

The current cluster is deployed as a Public Cluster; however, the parameters.json files under ./parameters have a "personalPublicIP" parameter, which if defined, will limit traffic to the cluster to the defined personalPublicIp.

Limiting incoming traffic to the Cluster, to only the personalPublicIp, is only in regards to accessing the cluster/nodes directly; i.e. running kubectl

Once the Load Balancer is deployed and functioning, all Public HTTP(s) traffic will be allowed to the port defined for the Load Balancer/Application. However, that Public HTTP traffic will NOT be able to access the Cluster itself.

The Bastion Hosts will be able to access the Cluster, and come configured with kubectl, and having authenticated access to the Cluster.

The personalPublicIp is only for the Deployment methods to run kubectl commands to setup and configure the Cluster. The EKS NodeGroup Security Group rules allowing access from the personalPublicIp can be removed after the deployment is complete, and all cluster interactions can be performed from the Linux Bastion Host using kubectl.

The personalPublicIP is defined as a range, so to limit it to one IP use this format:

    1.2.3.4/32

To make the cluster fully publicly accessible, remove the personalPublicIp parameters from the parameters.json files, and the personalPublicIp variable will default to 0.0.0.0/0. THIS IS NOT RECOMMENDED.

A completely private EKS Cluster deployment will be created as a separate branch in the future.

<h2>CloudFormation Deployment</h2>

Generates a VPC with Bastion Hosts (Linux and Windows), and a VPC running a Private EKS Cluster.

The Bastion Host VPC will have a full VPC Peering connection with the EKS Cluster's VPC.

I'm working on deploying this using Jenkins, hence the Jenkinsfile. It can be deployed using the build_script.sh as well. I plan on adding a gitlab pipeline deployment as well.

This guide will only explain the build_script.sh deployment, as the Jenkins and Gitlab deployments are too complicated to explain here.

I attempted to keep this fully private at first, but have kinks to work out, so I'm changing it to a public cluster, and will change it to be private later. The problem with private deployment is I can't deploy kubernetes apps using the pipelines since the private Cluster can only be accessed using the bastion hosts. I will eventually make two eks deployments, one public and one private.

<h3>Prerequisites</h3>

1. The aws-cli is installed and configured on the host running the build_script.sh
    a. Install aws-cli
    b. Configure aws-cli with access key or IAM Role

2. Create an ssh-keypair
    a. ssh-keygen -t rsa -m PEM -b 2048 -f ~/.ssh/aws_bh_id_rsa
        - You can leave off the -f argument to save it here ~/.ssh/id_rsa
        - This could overwrite an existing ssh-key for the user you're using.
    b. Look in '~/.ssh/' and copy the contents of 'id_rsa.pub' 
    c. Paste this in '/IaC_Templates/bastion_host_infrastructure_deployment.yml' under parameters for 'bastionHostPublicKey'

    LINUX NOTE - This key is also configured for the 'userName' configured under parameters.
               - So, you can log in with this key for Linux as 'ec2-user' or the configured user.

    WINDOWS NOTE - The ssh key can be used to decipher the 'Administrator' password for windows.
                 - Use 'connect' under the ec2 instance to decipher the password.
                 - 'userName' added can log into windows instance with 'userPass' configured.
                 - Logging into windows with configured user and password isn't working right now. 

3. Required Parameters need added in parameters.json:
    - personalPublicIP
    - userName
    - userPass
    - bastionHostPublicKey
    - EKSPublicKey - This should be a separate key to access EKS Nodes from Bastion Hosts.
                   - Requires manually copying the private key to bastion hosts.
