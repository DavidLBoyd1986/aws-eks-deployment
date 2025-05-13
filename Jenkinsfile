pipeline {
    
    agent any

    environment {
        REGION = "us-east-1"
        CLUSTER_NAME = "EKSPublicCluster"
        // PUBLIC_IP = credentials('2ef53f51-8a81-400a-be7f-538cdddad37b')
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

                        // Replace the variables in the parameters.json file with the actual values:
                        sh """
                            sed -i 's|\\\$PUBLIC_IP_RANGE|${PUBLIC_IP_RANGE}|g' parameters.json
                            sed -i 's|\\\$BASTION_USERNAME|${BASTION_USERNAME}|g' parameters.json
                            sed -i 's|\\\$BASTION_PASSWORD|${BASTION_PASSWORD}|g' parameters.json
                        """

                        // Replace the variables ($CLUSTER_NAME) in other files with the actual values:
                        sh """
                            sed -i 's|\\\$CLUSTER_NAME|${CLUSTER_NAME}|g' ./IaC/eks_infrastructure_deployment.yml
                        """

                        // Test the variables were replaced successfully
                        sh "cat parameters.json"

                        // ---------------------------------------------
                        // DEPLOY THE AWS RESOURCES USING CLOUDFORMATION
                        //----------------------------------------------

                        // Deploys the Bastion Host Networking Stack
                        echo "Deploy the BH Networking stack"
                        sh 'aws cloudformation deploy \
                            --stack-name bh-vpc-stack \
                            --template-file ./IaC/bastion_host_vpc_deployment.yml \
                            --region $REGION'

                        // Deploys the EKS Networking Stack
                        echo "Deploy the EKS Networking stack"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-vpc-stack \
                            --template-file ./IaC/eks_vpc_deployment.yml \
                            --region $REGION'

                        // Deploys the BH and EKS IAM Stacks
                        echo "Deploy the BH IAM stack"
                        sh 'aws cloudformation deploy \
                            --stack-name bh-iam-stack \
                            --template-file ./IaC/bastion_host_iam_deployment.yml \
                            --capabilities CAPABILITY_IAM \
                            --region $REGION'

                        echo "Deploy the EKS IAM stack"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-iam-stack \
                            --template-file ./IaC/eks_iam_deployment.yml \
                            --capabilities CAPABILITY_NAMED_IAM \
                            --region $REGION'

                        // Deploys the VPC Peering Connection Stack
                        echo "Deploy VPC Peering Connection so Bastion Hosts can connect to EKS Cluster"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-bh-vpc-peering-stack \
                            --template-file ./IaC/eks_bh_vpc_peering_deployment.yml \
                            --region $REGION'

                        // Deploys the EKS Infrastructure Stack, if it doesn't already exist 
                        def eksStackExists = sh (
                            script: "aws cloudformation describe-stacks --region $REGION --stack-name eks-infrastructure-stack > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0
                        if (!eksStackExists) {
                            echo "Deploy the EKS Infrastructure Stack"
                            sh 'aws cloudformation create-stack \
                                --stack-name eks-infrastructure-stack \
                                --template-body file://./IaC/eks_infrastructure_deployment.yml \
                                --parameters file://./parameters.json \
                                --capabilities CAPABILITY_NAMED_IAM \
                                --region $REGION'
                        } else {
                            echo "EKS Infrastructure Stack already exists, skipping deployment..."
                        }

                        // Deploys the BH Infrastructure Stack, if it doesn't already exist 
                        def bhStackExists = sh (
                            script: "aws cloudformation describe-stacks --region $REGION --stack-name bh-infrastructure-stack > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0
                        if (!bhStackExists) {
                            echo "Deploy the BH Infrastructure Stack"
                            sh 'aws cloudformation create-stack \
                                --stack-name bh-infrastructure-stack \
                                --template-body file://./IaC/bastion_host_infrastructure_deployment.yml \
                                --parameters file://./parameters.json \
                                --capabilities CAPABILITY_NAMED_IAM \
                                --region $REGION'
                        } else {
                            echo "BH Infrastructure Stack already exists, skipping deployment..."
                        }

                        // --------------------------------
                        // Initial Kubernetes Configuration 
                        //---------------------------------

                        // Configure kubectl to connect to eks cluster.
                        echo "Configure kubectl to connect to cluster."
                        sh 'kubectl version --client'
                        sh 'aws sts get-caller-identity'
                        sh "aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"

                        // Get the ARN of the BastionHostRole so it can be given access to the EKS Cluster
                        def bhRoleArn = sh(
                            script: """
                                    aws cloudformation describe-stacks \
                                    --stack-name bh-iam-stack \
                                    --region $REGION \
                                    --query "Stacks[0].Outputs[?OutputKey=='BastionHostRoleArn'].OutputValue" \
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()
                        echo "BastionHostRoleArn: ${bhRoleArn}"
                        def BASTION_HOST_ROLE_ARN = "${bhRoleArn}"

                        // Add Bastion Host Role to aws-auth so it can access the Cluster:
                        sh """
                            eksctl create iamidentitymapping \
                            --cluster $CLUSTER_NAME \
                            --region $REGION \
                            --arn $BASTION_HOST_ROLE_ARN \
                            --username system:node:{{EC2PrivateDNSName}} \
                            --group system:masters
                        """

                        // ------------------------------------------
                        // CONFIGURE THE AWS LOAD BALANCER CONTROLLER
                        //-------------------------------------------

                        // Detect if the AWSLoadBalancerControllerIAMPolicy exists
                        def awsLoadBalancerControllerPolicyExists = sh (
                            script: "aws iam list-policies --scope Local --query 'Policies[].PolicyName' --output text | grep 'AWSLoadBalancerControllerIAMPolicy' > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0

                        // If AWSLoadBalancerControllerIAMPolicy does NOT exist, create it
                        if (!awsLoadBalancerControllerPolicyExists) {
                            sh 'curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.12.0/docs/install/iam_policy.json'
                            sh 'aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json'
                        } else {
                            echo "The AWSLoadBalancerControllerIAMPolicy already exists. Skipping this step....."
                        }

                        // Get AWSAccountId
                        def AWSAccountId = sh (
                            script: "aws sts get-caller-identity --query Account --output text",
                            returnStdout: true
                        ).trim()
                        echo "AWS Account ID is ${AWSAccountId}"

                        // TODO: The below seems to work, but shows: "Error from server (notFound): serviceaccounts "aws-load-balancer-controller" not found"
                        // Detect if the "aws-load-balancer-controller" (Kubernetes Service Account) exists
                        def awsLoadBalancerControllerExists = sh (
                            script: "kubectl get serviceaccount aws-load-balancer-controller -n kube-system > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0

                        // Must associate an OIDC (OpenID Connect) provider with the cluster
                        if (!awsLoadBalancerControllerExists) {
                            sh """
                                eksctl utils associate-iam-oidc-provider \
                                    --region $REGION \
                                    --cluster $CLUSTER_NAME \
                                    --approve
                            """
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
                            sh """
                                eksctl create iamserviceaccount \
                                    --cluster=$CLUSTER_NAME \
                                    --namespace=kube-system \
                                    --name=aws-load-balancer-controller \
                                    --role-name=AWSLoadBalancerControllerRole \
                                    --attach-policy-arn=arn:aws:iam::${AWSAccountId}:policy/AWSLoadBalancerControllerIAMPolicy \
                                    --override-existing-serviceaccounts \
                                    --region $REGION \
                                    --approve
                            """
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
                            sh 'helm repo add eks https://aws.github.io/eks-charts'
                            sh 'helm repo update eks'
                            sh """
                                helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                                -n kube-system \
                                --set clusterName=$CLUSTER_NAME \
                                --set serviceAccount.create=false \
                                --set serviceAccount.name=aws-load-balancer-controller
                            """
                        } else {
                            echo "aws-load-balancer-deployment already exists, running upgrade..."
                            // Might add an 'helm update' command here, but right now don't see a reason to.
                        }
                        echo 'Sleeping for 20 seconds...'
                        sleep time: 20, unit: 'SECONDS'

                        // Need to wait for these pods to be deployed and running
                        // TODO - Having issues with calls, this only worked if the deployment was done, added sleep before this to help.
                        timeout(time: 5, unit: 'MINUTES') {
                            waitUntil {
                                def albControllerOutput = sh (
                                    script: "kubectl get deployment -n kube-system aws-load-balancer-controller -o jsonpath='{.status.availableReplicas}' || echo 0",
                                    returnStdout: true
                                ).trim()

                                // if output is a #, set it, if not set it to 0.
                                // def availableReplicas = output.isInteger() ? output.toInteger : 0
                                echo "Available Replicas: ${albControllerOutput}"

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
                            script: "kubectl get namespace web-app > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0
                        if (!namespaceExists) {
                            sh 'kubectl create namespace web-app'
                        } else {
                            echo "Kubernetes namespace already exists. Skipping this step...."
                        }
                        sh 'kubectl apply -f ./kubernetes/web-app-deployment.yml'

                        // Run some test commands
                        sh 'kubectl get all -n web-app'
                        sh 'kubectl get pods -n web-app'

                        // Create the Kubernetes Service for the web-app-nlb
                        sh 'kubectl apply -f ./kubernetes/web-app-nlb.yml'
                        sh 'kubectl -n web-app describe service web-app-nlb'

                        // Tests and outputs
                        sh 'kubectl get all -n web-app'
                        echo "web-app-nlb loadbalancer public address:"

                        echo 'Sleeping for 20 seconds...'
                        sleep time: 20, unit: 'SECONDS'

                        // Creates an NLB, and Kubernetes service for NLB to access Application Pods
                        sh "kubectl get service web-app-nlb --namespace web-app \
                            --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'"

                        // Below is for creating an ALB instead of an NLB.
                            // To use an ALB:
                            //   Comment out above 'sh' command.
                            //   Uncomment below two commands.

                        // Create the Kubernetes Service for the web-app, allows ALB to access Application Pods
                        //sh 'kubectl apply -f ./kubernetes/web-app-service.yml'

                        // Create the Kubernetes Ingress for the web-app, creates the ALB and allows external access through it.
                        //sh 'kubectl apply -f ./kubernetes/web-app-ingress.yml'

                        // Verify created Load Balancer resources:
                        sh 'kubectl describe service web-app-nlb -n web-app'
                        //sh 'kubectl describe service web-app-service -n web-app'
                        //sh 'kubectl describe ingress web-app-ingress -n web-app'
                        
                        // TODO - Add some tests to verify the external connections are working.
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