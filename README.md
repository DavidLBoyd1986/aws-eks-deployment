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

TODO:
- Windows Bastion Host - Fix logging in remotely as configured user
- EKS Working with full automated deployment
- VPC peering between BH VPC and EKS VPC
