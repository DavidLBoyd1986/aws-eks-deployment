pipeline {
    
    agent any

    environment {
        REGION = "us-east-1"
        PUBLIC_IP = credentials('2ef53f51-8a81-400a-be7f-538cdddad37b')
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

                        // All These Worked. I'm not sure why the PUBLIC_IP one is not working
                        def TEST_VAR = "${REGION}/32"
                        echo "$TEST_VAR"

                        def TEST_USER = "${BASTION_USERNAME}_TEST"
                        echo "$TEST_USER"

                        def TEST_ADD = "$BASTION_USERNAME" + "_TEST"
                        echo "$TEST_ADD"

                        // Replace the variables in the paramters.json file with the actual values:
                        sh """
                            sed -i 's|\\\$PUBLIC_IP_RANGE|${PUBLIC_IP_RANGE}|g' parameters.json
                            sed -i 's|\\\$BASTION_USERNAME|${BASTION_USERNAME}|g' parameters.json
                            sed -i 's|\\\$BASTION_PASSWORD|${BASTION_PASSWORD}|g' parameters.json
                        """

                        // Test the variables were replaced successfully
                        sh "cat parameters.json"

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

                        // Deploys the EKS Infrastructure Stack
                        echo "Deploy the EKS Infrastructure Stack"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-infrastructure-stack \
                            --template-file ./IaC/eks_infrastructure_deployment.yml \
                            --region $REGION'

                        // TODO - update parameters.json with your public IP. It is currently wide open!!
                        def stackExists = sh (
                            script: "aws cloudformation describe-stacks --region $REGION --stack-name bh-infrastructure-stack > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0
                        // above defines a variable, script runs the command and hides the output
                        // returnStatus: true - indicates that script should return the status of the command.
                        // '== 0' returns true if the command returned '0' (succeeded) or false if it's anything else (failed)
                        if (!stackExists) {
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

                        // Configure kubectl to connect to eks cluster.
                        echo "Configure kubectl to connect to cluster."
                        sh 'kubectl version --client'
                        sh 'aws sts get-caller-identity'
                        sh 'aws eks update-kubeconfig --region $REGION --name EKSPublicCluster'
                        // TODO - Make Cluster Name a parameter

                        // Configure the AWS Load Balancer Controller

                        // Detect if the AWSLoadBalancerControllerIAMPolicy exists
                        def awsLoadBalancerControllerPolicyExists = sh (
                            script: "aws iam list-policies --scope Local --query 'Policies[].PolicyName' --output text | grep 'AWSLoadBalancerControllerIAMPolicy' > /dev/null 2>&1",
                            returnStatus: true
                        ) == 0

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
                                    --cluster EKSPublicCluster \
                                    --approve
                            """
                        }

                        // Get the OIDC_ID of the OIDC Provider
                        def OIDC_ID = sh (
                            script: "aws eks describe-cluster --name EKSPublicCluster -- region $REGION \
                                     --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5",
                            returnStdout: true
                        ).trim()
                        echo "OIDC_ID = ${OIDC_ID}"
                        // Create the ServiceAccount
                        // - A Role is created, the previous policy is attached, granting the service account AWS permissions
                        if (!awsLoadBalancerControllerExists) {
                            sh """
                                eksctl create iamserviceaccount \
                                    --cluster=EKSPublicCluster \
                                    --namespace=kube-system \
                                    --name=aws-load-balancer-controller \
                                    --role-name=AWSLoadBalancerControllerRole
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

                        def awsLoadBalancerControllerDeployed = sh (
                            script: "kubectl get deployment -n kube-system aws-load-balancer-controller -o jsonpath='{.status.availableReplicas}'",
                            returnStatus: true
                        ) == 0

                        // Install or Update the deployment if it is already installed
                        if (!awsLoadBalancerControllerDeployed) {
                            // Install the AWS Load Balancer Controller using Helm
                            sh 'helm repo add eks https://aws.github.io/eks-charts'
                            sh 'helm repo update eks'
                            sh 'helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                                -n kube-system \
                                --set clusterName=EKSPublicCluster \
                                --set serviceAccount.create=false \
                                --set serviceAccount.name=aws-load-balancer-controller'
                        } else {
                            echo "aws-load-balancer-deployment already exists, running upgrade..."
                            // Might add an 'helm update' command here, but right now don't see a reason to.
                        }

                        // Need to wait for these pods to be deployed and running
                        // TODO - Should add api calls and logic check until they are ready.
                        timeout(time: 5, unit: 'MINUTES') {
                            waitUntil {
                                def output = sh (
                                    script: "kubectl get deployment -n kube-system aws-load-balancer-controller -o jsonpath='{.status.availableReplicas}' || echo 0",
                                    returnStdout: true
                                ).trim()

                                // if output is a #, set it, if not set it to 0.
                                // def availableReplicas = output.isInteger() ? output.toInteger : 0
                                echo "Available Replicas: ${output}"

                                if (output == 0) {
                                    echo "Waiting for loadbalance to be deployed..."
                                    sleep 10 // wait 10 seconds before next check
                                    return false
                                }
                                return true
                            }
                        }

                        // Test if the AWS Load Balancer Controller is (finally) installed
                        sh "kubectl get all -n kube-system --selector app.kubernetes.io/name=aws-load-balancer-controller"

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
                        sh "kubectl get service web-app-nlb --namespace web-app \
                            --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'"

                        // Create the Kubernetes Service for the web-app
                        //sh 'kubectl apply -f ./kubernetes/web-app-service.yml'
                        //sh 'kubectl -n web-app describe service web-app-service'

                        // Create the Kubernetes Ingress for the web-app
                        //sh 'kubectl apply -f ./kubernetes/web-app-ingress.yml'
                        //sh 'kubectl -n web-app describe ingress web-app-ingress'

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