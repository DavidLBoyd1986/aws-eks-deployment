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

                        // Deploys the Bastion Host VPC and Infrastructure Stacks
                        echo "Deploy the BH Networking stack"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-hacking-bh-vpc-stack \
                            --template-file ./IaC/bastion_host_vpc_deployment.yml \
                            --region $REGION'

                        echo "Deploy the BH IAM stack"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-hacking-bh-iam-stack \
                            --template-file ./IaC/bastion_host_iam_deployment.yml \
                            --capabilities CAPABILITY_IAM \
                            --region $REGION'

                        echo "Deploy the BH Infrastructure stack"
                        sh 'aws cloudformation create-stack \
                            --stack-name eks-hacking-bh-infrastructure-stack \
                            --template-body file://./IaC/bastion_host_infrastructure_deployment.yml \
                            --parameters file://./parameters.json \
                            --capabilities CAPABILITY_NAMED_IAM \
                            --region $REGION'

                        // Deploys the EKS VPC and Infrastructure Stacks
                        echo "Deploy the EKS Networking stack"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-hacking-eks-vpc-stack \
                            --template-file ./IaC/eks_vpc_deployment.yml \
                            --region $REGION'

                        echo "Deploy the EKS IAM stack"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-hacking-eks-iam-stack \
                            --template-file ./IaC/eks_iam_deployment.yml \
                            --capabilities CAPABILITY_NAMED_IAM \
                            --region $REGION'

                        // Deploys the VPC Peering Connection Stack
                        echo "Deploy VPC Peering Connection so Bastion Hosts can connect to EKS Cluster"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-hacking-eks-bh-vpc-peering-stack \
                            --template-file ./IaC/eks_bh_vpc_peering_deployment.yml \
                            --region $REGION'

                        echo "Deploy the EKS Infrastructure Stack"
                        sh 'aws cloudformation deploy \
                            --stack-name eks-hacking-eks-infrastructure-stack \
                            --template-file ./IaC/eks_infrastructure_deployment.yml \
                            --region $REGION'
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