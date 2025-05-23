<h1>Private Cluster - Private API Endpoint</h1>

IMPORTANT:
- Only the gitlab deployment method is supported for the fully Private Cluster
- The Jenkinsfile and build_script.sh have NOT been updated for this Cluster

This branch deploys a Cluster with a private API endpoint.

Applications launched on the Cluster can be public or private, depending on the annotation used in the Kubernetes resource that signals the AWS Load Balancer Controller to create the load balancer.

The files kubernetes/web-app-ingress.yml and kubernetes/web-app-nlb.yml have the annotations that determine if the created ALB or NLB will be private or public.

<h4>Below are the annotations for the kubernetes ingress that creates an ALB:</h4>
    
- alb.ingress.kubernetes.io/scheme: internet-facing
    - Use for public access to the cluster
- alb.ingress.kubernetes.io/scheme: internal
    - Use for only allowing private access to the cluster

<h4>Below are the annotations for the kubernetes service that creates an NLB:</h4>

- service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    - Use for public access to the cluster
- service.beta.kubernetes.io/aws-load-balancer-scheme: internal
    - Use for only allowing private access to the cluster

Can, also, restrict traffic by using the Security Groups attached to the created Load Balancer. Currently it only allows traffic to the port configured in the Kubernetes Service, so update that rule to restrict the source IPs who can access the application hosted on that port.

<h2>Differences in this branch:</h2>

- Private API Endpoint

- Most of the deployment happens from the Linux Bastion Host
    - Because only IPs inside the EKS VPC can connect to the Private API Endpoint
    - This is done with the eks_deploy_script.sh

- An S3 Bucket is created to copy the eks_deploy_script.sh to/from Bastion Host

- Bastion Host VPC is connected to EKS VPC with a Transit Gateway

- Bastion Host deploys the EKS Cluster so it is given Cluster permissions since it created the Cluster
