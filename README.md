<h1>EKS Hacking Cloudformation Deployment</h1>

Generates a VPC with a Bastion Host, and a VPC running an EKS Cluster with the WebGoat Application to pentest against.

The Bastion Host VPC will have a full VPC Peering connection with the EKS Cluster's VPC.

<h3>Prerequisites</h3>

1. The aws-cli is installed and configured 
    a. Install aws-cli
    b. Configure aws-cli with access key or IAM Role

2. Create an ssh-keypair
    a. ssh-keygen
    b. Look in '~/.ssh/' and copy the contents of 'id_rsa.pub' 
    c. Paste this in '/IaC_Templates/bastion_host_infrastructure_deployment.yml' under parameter
    - NOTE - You can also create the SSH Key yourself, and supply the public key


3. Required Parameters added in build-script.sh:
    - personalPublicIP
    - userName
    - userPass
    - bastionHostPublicKey

    Example:

    ```
    echo "Deploy the BH Infrastructure stack - EC2 Instance with Security Groups"
    aws cloudformation deploy --stack-name eks-hacking-bh-infrastructure-stack \
        --template-file ./IaC_Templates/bastion_host_infrastructure_deployment.yml \
        --parameters ParameterKey=personalPublicIP,ParameterValue=192.168.0.0 \
            ParameterKey=userName,ParameterValue=BastionUser \
            ParameterKey=userPass,ParameterValue=ChangeMeNow! \
            ParameterKey=bastionHostPublicKey,ParameterValue=EnterPublicKeyHere \
        --capabilities CAPABILITY_IAM

TODO:
- EKS Working with full automated deployment
- VPC peering between BH VPC and EKS VPC