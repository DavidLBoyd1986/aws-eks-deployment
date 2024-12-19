<h1>Private EKS and Public Bastion Hosts</h1>
<h2>CloudFormation Deployment</h2>

Generates a VPC with Bastion Hosts (Linux and Windows), and a VPC running a Private EKS Cluster with the WebGoat Application to pentest against.

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

Troubleshooting:
- Cluster Nodes aren't connecting to Cluster - FML
    - Before I open up the SGs, I moved the VPC Peering connection before cluster deployment
    - This should allow me to troubleshoot, and get the peering connection working

    SOLUTION:
     - The AMI I was using didn't support the bootstrap.sh, which is dumb, as all the docs say to us it.
     - Switched the AMI to one that supported the bootstrap script. Using the nodeadm did not work.

- Cluster KeyPair:
    - I don't want to add the Bastion Host KeyPair to the Cluster.
    - So, I'm adding a EKSKeyPair manually to test with, and will remove it when done testing.
    - Long term, need to add a User to the EKS Nodes that I can ssh in as.

    SOLUTION:
    - Added the public key for an EKS Key pair. On user to manually copy the private key to the bastion host to connect

- Configuring EKS Deployments and Services:
    - The final, and most difficult, problem.
    - My PC launching the script can't configure kubernetes as it can't connect to the cluster, only the bastion hosts can.
    - Can I have this script run a script on the bastion host?

    POSSIBLE SOLUTIONS:
    - Install kubectl on the bastion host
    - Install aws-cli on the bastion host
    - Create configure IAM Role for bastion host to connect to EKS

    - This must be manually done. Trying to automate it just isn't worth it.
    - At the end, have script ssh into bastion host, and run the commands there.
    - Or, could possibly configure bastion host infrastructure after cluster, and
        include configuration in the USER DATA.
    - Prefer having the script SSH directly to bastion host, as it is more explicit.


TODO:
- Windows Bastion Host - Fix logging in remotely as configured user
- EKS Working with full automated deployment
- VPC peering between BH VPC and EKS VPC
