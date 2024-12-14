<h1>EKS Hacking Cloudformation Deployment</h1>

Generates a VPC with a Bastion Host, and a VPC running an EKS Cluster with the WebGoat Application to pentest against.

The Bastion Host VPC will have a full VPC Peering connection with the EKS Cluster's VPC.

IMPORTANT - I didn't add the Kali instance yet, and never will.
            The end goal is to put a small ec2-instance instead of the bastion hosts.
            This instance will route traffic from your on-prem kali to the private EKS Cluster
            that is in a private subnet in it's own VPC.
            That way you can hack away privately without exposing the vulnerable web application publicly.

<h3>Prerequisites</h3>

1. The aws-cli is installed and configured 
    a. Install aws-cli
    b. Configure aws-cli with access key or IAM Role

2. Create an ssh-keypair
    a. ssh-keygen
    b. Look in '~/.ssh/' and copy the contents of 'id_rsa.pub' 
    c. Paste this in '/IaC_Templates/bastion_host_infrastructure_deployment.yml' under parameter
    - NOTE - You can also create the SSH Key yourself, and supply the public key


3. Required Parameters need added in parameters.json:
    - personalPublicIP
    - userName
    - userPass
    - bastionHostPublicKey

TODO:
- EKS Working with full automated deployment
- VPC peering between BH VPC and EKS VPC
