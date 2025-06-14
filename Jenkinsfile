pipeline {
    
    agent any

    environment {
        REGION = "us-east-1"
        CLUSTER_NAME = "EKSPublicCluster"
        KUBE_VERSION = "1.32"
        KUBE_NAMESPACE = "web-app"
        KUBE_LOAD_BALANCER_TYPE = "NLB" // Must be NLB or ALB
        APPLICATION_NAME = "webgoat"
        IMAGE_REPOSITORY = "webgoat"
        IMAGE_TAG = "latest"
        APP_PORT = 8080
        // Public Image Variables - This pipeline is pulling a public image to deploy
        PUBLIC_REGISTRY = "docker.io"
        PUBLIC_IMAGE = "webgoat/webgoat"
        PUBLIC_IMAGE_TAG = "latest"
        //ECR_REGISTRY and IMAGE_REGISTRY are set in the script
        // Too lazy to set them as Jenkins Secrets (contains my aws account id)
    }

    stages {
        stage('build') {
            steps {
                sh 'echo "Placeholder for build jobs....."'
                }
            }
        stage('test') {
            steps {
                sh 'echo "Placeholder for test jobs"'
                    }
                }
        stage('deploy') {
            steps {
		        script {
                    withCredentials([aws(accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'e3cfebfb-f2b8-4d9d-b9fc-2d1b594b264d', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'),
                                     usernamePassword(credentialsId: 'a797bda4-6f58-4006-8434-106015bbde1a', passwordVariable: 'BASTION_PASSWORD', usernameVariable: 'BASTION_USERNAME'),
                                     string(credentialsId: '2ef53f51-8a81-400a-be7f-538cdddad37b', variable: 'PUBLIC_IP_RANGE')]) {

                        // --------------------------------------
                        // CONFIGURE ALL THE VARIABLES TO BE USED
                        //---------------------------------------

                        // TODO - Clean up """, they were required because of using cut -d '"'
                        def HELM_VERSION = sh (
                            script: """
                                curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f 4
                                """,
                            returnStdout: true
                        ).trim()

                        // Get AMI ID for the aws-eks-optimized AMIs for the region and specific kubernetes version
                        def AMI_ID = sh (
                            script: "aws ssm get-parameter \
                                     --name /aws/service/eks/optimized-ami/${KUBE_VERSION}/amazon-linux-2/recommended/image_id \
                                     --region ${REGION} --query 'Parameter.Value' --output text",
                            returnStdout: true
                        ).trim()

                        def AWS_ACCOUNT_ID = sh (
                            script: "aws sts get-caller-identity --query Account --output text",
                            returnStdout: true
                        ).trim()
                        echo "AWS Account ID is ${AWS_ACCOUNT_ID}"

                        // Normally set as CICD Variables, but I hate using Jenkins Secrets (kludge)
                        def ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
                        def IMAGE_REGISTRY = "${ECR_REGISTRY}"

                        // Replace the variables in the parameters.json file with the actual values:
                        sh """
                            sed -i 's|\\\$PUBLIC_IP_RANGE|${PUBLIC_IP_RANGE}|g' ./parameters/eks_vpc_parameters.json
                            sed -i 's|\\\$PUBLIC_IP_RANGE|${PUBLIC_IP_RANGE}|g' ./parameters/bh_infrastructure_parameters.json
                            sed -i 's|\\\$BASTION_USERNAME|${BASTION_USERNAME}|g' ./parameters/bh_infrastructure_parameters.json
                            sed -i 's|\\\$BASTION_PASSWORD|${BASTION_PASSWORD}|g' ./parameters/bh_infrastructure_parameters.json
                            sed -i 's|\\\$CLUSTER_NAME|${CLUSTER_NAME}|g' ./parameters/bh_infrastructure_parameters.json
                            sed -i 's|\\\$KUBE_VERSION|${KUBE_VERSION}|g' ./parameters/bh_infrastructure_parameters.json
                            sed -i 's|\\\$HELM_VERSION|${HELM_VERSION}|g' ./parameters/bh_infrastructure_parameters.json
                        """

                        // Replace ${KUBE_NAMESPACE} in kubernetes files:
                        sh """
                            sed -i 's|\\\${KUBE_NAMESPACE}|${KUBE_NAMESPACE}|g' ./kubernetes/web-app-deployment.yml
                            sed -i 's|\\\${KUBE_NAMESPACE}|${KUBE_NAMESPACE}|g' ./kubernetes/web-app-nlb.yml
                            sed -i 's|\\\${KUBE_NAMESPACE}|${KUBE_NAMESPACE}|g' ./kubernetes/web-app-service.yml
                            sed -i 's|\\\${KUBE_NAMESPACE}|${KUBE_NAMESPACE}|g' ./kubernetes/web-app-ingress.yml
                            sed -i "s|\\\${IMAGE_REGISTRY}|${IMAGE_REGISTRY}|g" ./kubernetes/web-app-deployment.yml
                            sed -i "s|\\\${IMAGE_REPOSITORY}|${IMAGE_REPOSITORY}|g" ./kubernetes/web-app-deployment.yml
                            sed -i "s|\\\${IMAGE_TAG}|${IMAGE_TAG}|g" ./kubernetes/web-app-deployment.yml
                            sed -i "s|\\\${APPLICATION_NAME}|${APPLICATION_NAME}|g" ./kubernetes/web-app-deployment.yml
                            sed -i "s|\\\${APPLICATION_NAME}|${APPLICATION_NAME}|g" ./kubernetes/web-app-nlb.yml
                            sed -i "s|\\\${APPLICATION_NAME}|${APPLICATION_NAME}|g" ./kubernetes/web-app-service.yml
                            sed -i "s|\\\${APPLICATION_NAME}|${APPLICATION_NAME}|g" ./kubernetes/web-app-ingress.yml
                            sed -i "s|\\\${APP_PORT}|${APP_PORT}|g" ./kubernetes/web-app-deployment.yml
                            sed -i "s|\\\${APP_PORT}|${APP_PORT}|g" ./kubernetes/web-app-nlb.yml
                            sed -i "s|\\\${APP_PORT}|${APP_PORT}|g" ./kubernetes/web-app-service.yml
                            sed -i "s|\\\${APP_PORT}|${APP_PORT}|g" ./kubernetes/web-app-ingress.yml
                        """

                        // Replace the variables ($CLUSTER_NAME) in other files with the actual values:
                        sh """
                            sed -i 's|\\\$CLUSTER_NAME|${CLUSTER_NAME}|g' ./IaC/eks_infrastructure_deployment.yml
                            sed -i 's|\\\$AMI_ID|${AMI_ID}|g' ./IaC/eks_infrastructure_deployment.yml
                            sed -i "s|\\\${IMAGE_REPOSITORY}|${IMAGE_REPOSITORY}|g" ./IaC/repo_app_deployment.yml
                        """

                        // Test the variables were replaced successfully
                        sh "cat ./parameters/bh_infrastructure_parameters.json"
                        sh "cat ./parameters/eks_vpc_parameters.json"

                        //----------------------
                        // Deploy ECR Repository
                        //----------------------

                        echo 'Deploying Elastic Container Repository....'

                        // Check if the repositories already exist
                        def ECR_REPOS = sh (
                            script: "aws ecr describe-repositories \
                                        --query 'repositories[*].repositoryName' --output text",
                            returnStdout: true
                        ).trim()
                        def REPO_EXISTS = ECR_REPOS.contains(${IMAGE_REPOSITORY})

                        // Create the repository for your Application Image
                        if (REPO_EXISTS) {
                            echo "The Repository: ${IMAGE_REPOSITORY} already exists. Skipping deployment...."
                        } else {
                            sh "aws cloudformation deploy \
                                --template-file ./IaC/repo_app_deployment.yml \
                                --stack-name ${IMAGE_REPOSITORY}-repository-stack"
                            echo "The ${IMAGE_REPOSITORY} repository was successfully deployed."
                        }

                        //------------
                        // Build Image
                        //------------

                        // This pipeline doesn't build the image, so I just pull/push a test image
                        sh "aws ecr get-login-password --region ${REGION} | docker login \
                            --username AWS --password-stdin ${ECR_REGISTRY}"
                        // Below is where you would build the Image. I pull/push a test image instead
                        sh "docker pull ${PUBLIC_REGISTRY}/${PUBLIC_IMAGE}:${PUBLIC_IMAGE_TAG}"

                        sh "docker tag ${PUBLIC_REGISTRY}/${PUBLIC_IMAGE}:${PUBLIC_IMAGE_TAG} \
                            ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"

                        sh "docker push ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"

                        // ---------------------------------------------
                        // DEPLOY THE AWS RESOURCES USING CLOUDFORMATION
                        //----------------------------------------------

                        // Deploys the Bastion Host Networking Stack
                        echo "Deploy the BH Networking stack"
                        sh "aws cloudformation deploy \
                            --stack-name bh-vpc-stack \
                            --template-file ./IaC/bastion_host_vpc_deployment.yml \
                            --region $REGION"

                        // Deploys the EKS Networking Stack
                        def eksStackExists = sh (
                            script: "aws cloudformation describe-stacks --region $REGION \
                                     --stack-name eks-vpc-stack > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0
                        if (!eksStackExists) {
                            echo "Deploy the EKS Networking Stack"
                            sh "aws cloudformation create-stack \
                                --stack-name eks-vpc-stack \
                                --template-body file://./IaC/eks_vpc_deployment.yml \
                                --parameters file://./parameters/eks_vpc_parameters.json \
                                --capabilities CAPABILITY_NAMED_IAM \
                                --region $REGION"
                        } else {
                            echo "EKS Networking Stack already exists, skipping deployment..."
                        }

                        // Deploys the BH and EKS IAM Stacks
                        echo "Deploy the BH IAM stack"
                        sh "aws cloudformation deploy \
                            --stack-name bh-iam-stack \
                            --template-file ./IaC/bastion_host_iam_deployment.yml \
                            --capabilities CAPABILITY_IAM \
                            --region $REGION"

                        echo "Deploy the EKS IAM stack"
                        sh "aws cloudformation deploy \
                            --stack-name eks-iam-stack \
                            --template-file ./IaC/eks_iam_deployment.yml \
                            --capabilities CAPABILITY_NAMED_IAM \
                            --region $REGION"

                        // Deploys the VPC Peering Connection Stack
                        echo "Deploy VPC Peering Connection so Bastion Hosts can connect to EKS Cluster"
                        sh "aws cloudformation deploy \
                            --stack-name eks-bh-vpc-peering-stack \
                            --template-file ./IaC/eks_bh_vpc_peering_deployment.yml \
                            --region $REGION"

                        // Deploys the EKS Infrastructure Stack, if it doesn't already exist 
                        echo "Deploy the EKS Infrastructure Stack"
                        sh "aws cloudformation deploy \
                            --stack-name eks-infrastructure-stack \
                            --template-file ./IaC/eks_infrastructure_deployment.yml \
                            --capabilities CAPABILITY_NAMED_IAM \
                            --region $REGION"

                        // Deploys the BH Infrastructure Stack, if it doesn't already exist 
                        def bhStackExists = sh (
                            script: "aws cloudformation describe-stacks --region $REGION --stack-name bh-infrastructure-stack > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0
                        if (!bhStackExists) {
                            echo "Deploy the BH Infrastructure Stack"
                            sh "aws cloudformation create-stack \
                                --stack-name bh-infrastructure-stack \
                                --template-body file://./IaC/bastion_host_infrastructure_deployment.yml \
                                --parameters file://./parameters/bh_infrastructure_parameters.json \
                                --capabilities CAPABILITY_NAMED_IAM \
                                --region $REGION"
                        } else {
                            echo "BH Infrastructure Stack already exists, skipping deployment..."
                        }

                        // --------------------------------
                        // Initial Kubernetes Configuration 
                        //---------------------------------

                        // Configure kubectl to connect to eks cluster.
                        echo "Configure kubectl to connect to cluster."
                        sh "kubectl version --client"
                        sh "aws sts get-caller-identity"
                        sh "aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"

                        // Get the ARN of the BastionHostRole so it can be given access to the EKS Cluster
                        def bhRoleArn = sh(
                            script: 'aws cloudformation describe-stacks ' +
                                    '--stack-name bh-iam-stack --region $REGION ' +
                                    '--query "Stacks[0].Outputs[?OutputKey==\'BastionHostRoleArn\'].OutputValue" ' +
                                    '--output text',
                            returnStdout: true
                        ).trim()

                        // TODO - Test if this can be deleted. Had issue with brackets, that is why this exists
                        def BASTION_HOST_ROLE_ARN = "${bhRoleArn}"

                        // Add Bastion Host Role to aws-auth so it can access the Cluster:
                        sh "eksctl create iamidentitymapping \
                            --cluster $CLUSTER_NAME --region $REGION \
                            --arn $BASTION_HOST_ROLE_ARN \
                            --username system:node:{{EC2PrivateDNSName}} \
                            --group system:masters"

                        // ------------------------------------------
                        // CONFIGURE THE AWS LOAD BALANCER CONTROLLER
                        //-------------------------------------------

                        // Detect if the AWSLoadBalancerControllerIAMPolicy exists
                        def awsLoadBalancerControllerPolicyExists = sh (
                            script: "aws iam list-policies --scope Local \
                                     --query 'Policies[].PolicyName' \
                                     --output text | grep 'AWSLoadBalancerControllerIAMPolicy' > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0

                        // If AWSLoadBalancerControllerIAMPolicy does NOT exist, create it
                        if (!awsLoadBalancerControllerPolicyExists) {
                            sh "curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.12.0/docs/install/iam_policy.json"
                            sh "aws iam create-policy \
                                --policy-name AWSLoadBalancerControllerIAMPolicy \
                                --policy-document file://iam_policy.json"
                        } else {
                            echo "The AWSLoadBalancerControllerIAMPolicy already exists. Skipping this step....."
                        }


                        // TODO: The below seems to work, but shows: "Error from server (notFound): serviceaccounts "aws-load-balancer-controller" not found"
                        // Detect if the "aws-load-balancer-controller" (Kubernetes Service Account) exists
                        def awsLoadBalancerControllerExists = sh (
                            script: "kubectl get serviceaccount aws-load-balancer-controller \
                                     -n kube-system > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0

                        // Must associate an OIDC (OpenID Connect) provider with the cluster
                        if (!awsLoadBalancerControllerExists) {
                            sh "eksctl utils associate-iam-oidc-provider \
                                --region $REGION --cluster $CLUSTER_NAME --approve"
                        }

                        // Get the OIDC_ID of the OIDC Provider
                        def OIDC_ID = sh (
                            script: "aws eks describe-cluster --name $CLUSTER_NAME --region $REGION \
                                     --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5",
                            returnStdout: true
                        ).trim()
                        echo "OIDC_ID = ${OIDC_ID}"

                        // Create the ServiceAccount
                        // - A Role is created, the previous policy is attached, granting the service account AWS permissions
                        if (!awsLoadBalancerControllerExists) {
                            sh "eksctl create iamserviceaccount --cluster=$CLUSTER_NAME \
                                --namespace=kube-system --name=aws-load-balancer-controller \
                                --role-name=AWSLoadBalancerControllerRole \
                                --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
                                --override-existing-serviceaccounts --region $REGION --approve"
                        }

                        // Test the Role was created
                        sh "aws iam get-role --role-name AWSLoadBalancerControllerRole"

                        // Test the service accout was create
                        sh "kubectl get serviceaccount aws-load-balancer-controller \
                            --namespace kube-system --output yaml"

                        // Detect if the "aws-load-balancer-controller" was Deployed
                        def awsLoadBalancerControllerDeployed = sh (
                            script: "kubectl get deployment -n kube-system aws-load-balancer-controller -o jsonpath='{.status.availableReplicas}'",
                            returnStatus: true
                        ) == 0

                        // Install or Update the deployment if it is already installed
                        if (!awsLoadBalancerControllerDeployed) {
                            // Install the AWS Load Balancer Controller using Helm
                            sh "helm repo add eks https://aws.github.io/eks-charts"
                            sh "helm repo update eks"
                            sh "helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                                -n kube-system --set clusterName=$CLUSTER_NAME \
                                --set serviceAccount.create=false \
                                --set serviceAccount.name=aws-load-balancer-controller"
                        } else {
                            echo "aws-load-balancer-deployment already exists, running upgrade..."
                            // Might add an 'helm update' command here, but right now don't see a reason to.
                        }
                        echo "Sleeping for 10 seconds..."
                        sleep time: 10, unit: 'SECONDS'

                        // Need to wait for these pods to be deployed and running
                        // TODO - Having issues with calls, this only worked if the deployment was done, added sleep before this to help.
                        timeout(time: 5, unit: 'MINUTES') {
                            waitUntil {
                                def albControllerOutput = sh (
                                    script: "kubectl get deployment aws-load-balancer-controller \
                                            -n kube-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo '0'",
                                    returnStdout: true
                                ).trim()

                                echo "Available Replicas: ${albControllerOutput}"
                                // if output is a #, set it, if not set it to 0.
                                def availableReplicas = (albControllerOutput.isInteger()) ? albControllerOutput.toInteger() : 0

                                if (albControllerOutput == 0) {
                                    echo "Waiting for loadbalance to be deployed..."
                                    sleep 10 // wait 10 seconds before next check
                                    return false
                                }
                                return true
                            }
                        }

                        // Test if the AWS Load Balancer Controller is (finally) installed
                        sh "kubectl get all -n kube-system --selector app.kubernetes.io/name=aws-load-balancer-controller"

                        // ------------------------------
                        // DEPLOY THE APPLICATION TO EKS:
                        //-------------------------------

                        // Configure Kubernetes with namespace and deploy the app:
                        def namespaceExists = sh (
                            script: "kubectl get namespace ${KUBE_NAMESPACE} > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0
                        if (!namespaceExists) {
                            sh "kubectl create namespace ${KUBE_NAMESPACE}"
                        } else {
                            echo "Kubernetes namespace already exists. Skipping this step...."
                        }
                        sh "kubectl apply -f ./kubernetes/web-app-deployment.yml"

                        // Run some test commands
                        sh "kubectl get all -n ${KUBE_NAMESPACE}"
                        sh "kubectl get pods -n ${KUBE_NAMESPACE}"

                        // --------------------------
                        // DEPLOY THE LOAD BALANCERS:
                        //---------------------------

                        // Create the Kubernetes resources to create the KUBE_LOAD_BALANCER_TYPE
                        if (KUBE_LOAD_BALANCER_TYPE == "NLB") {
                            // Creates an NLB, and Kubernetes service for NLB to access Application Pods
                            sh "kubectl apply -f ./kubernetes/web-app-nlb.yml"

                            // Sleep to wait for deployment - Pipeline will fail if you don't wait
                            echo "Sleeping for 180 seconds..."
                            sleep time: 180, unit: 'SECONDS'
                            // Loop to wait for deployment
                            timeout(time: 5, unit: 'MINUTES') {
                                waitUntil {
                                    def hostname = sh(
                                        script: "kubectl get svc ${KUBE_NAMESPACE}-nlb-service -n ${KUBE_NAMESPACE} \
                                                -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                                        returnStdout: true
                                    ).trim()
                                    return hostname != ''
                                }
                            }

                            def nlb_dns = sh(
                                script: "kubectl get svc ${KUBE_NAMESPACE}-nlb-service -n ${KUBE_NAMESPACE} \
                                        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                                returnStdout: true
                            ).trim()
                            // Output information about the service
                            sh "kubectl -n ${KUBE_NAMESPACE} describe service ${KUBE_NAMESPACE}-nlb"
                            echo "Load Balancer DNS: ${nlb_dns}"

                            // Optional sleep to ensure DNS is resolvable
                            sh "sleep 10"

                            // Test the loadbalancer call
                            sh "curl -v http://${nlb_dns}:${APP_PORT}/WebGoat" // /WebGoat required for test image
                        } else if (KUBE_LOAD_BALANCER_TYPE == "ALB"){
                            // Create the Kubernetes Service that allows ALB to access Application Pods
                            sh "kubectl apply -f ./kubernetes/web-app-service.yml"

                            // Create the Kubernetes Ingress that creates the ALB and allows external access through it.
                            sh "kubectl apply -f ./kubernetes/web-app-ingress.yml"

                            // Sleep to wait for deployment - Pipeline will fail if you don't wait
                            echo "Sleeping for 180 seconds..."
                            sleep time: 180, unit: 'SECONDS'
                            // Loop to wait for deployment
                            timeout(time: 5, unit: 'MINUTES') {
                                waitUntil {
                                    def hostname = sh(
                                        script: "kubectl get ingress ${KUBE_NAMESPACE}-ingress -n ${KUBE_NAMESPACE} \
                                                -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                                        returnStdout: true
                                    ).trim()
                                    return hostname != ''
                                }
                            }

                            def alb_dns = sh(
                                script: "kubectl get svc ${KUBE_NAMESPACE}-ingress -n ${KUBE_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                                returnStdout: true
                            ).trim()
                            // Output information about the service
                            sh "kubectl -n ${KUBE_NAMESPACE} describe service ${KUBE_NAMESPACE}-nlb"
                            echo "Load Balancer DNS: ${alb_dns}"

                            // Optional sleep to ensure DNS is resolvable
                            sh "sleep 10"

                            // Test the loadbalancer call
                            // TODO - Change Image from WebGoat to one that used port 80 and returns 200 for '/'
                            sh "curl -v http://${alb_dns}:${APP_PORT}/WebGoat" // /WebGoat required for test image
                        } else {
                            echo "ERROR - Invalid KUBE_LOAD_BALANCER_TYPE selected. \
                                    It must be: ('NLB' || 'ALB')"
                        }

                        // ---------------
                        // END OF PIPELINE
                        //----------------

                        echo "Pipeline finished - Application deployed successfully"
                    }
                }
            }
        }
    }

    post {
        always {
            // Archive the artifacts (files or directories)
            archiveArtifacts artifacts: 'test-artifact.txt', allowEmptyArchive: true
            cleanWs() // Clean up the workspace after the build
        }
    }
}