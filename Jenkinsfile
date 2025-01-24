pipeline {
    
    agent any

    environment {
        TEST="TEST"
        //SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
    }

    stages {
        stage('build') {
            steps {
                sh 'echo "Placeholder for pre-deploy jobs....."'
                }
            }
        stage('test') {
            steps {
		        script {
                    withCredentials([usernamePassword(credentialsId: '22d66568-f63d-492d-8ef0-f13d3accdf68', usernameVariable: 'LINUX_USERNAME', passwordVariable: 'LINUX_PASSWORD')]) {
                        echo "Can't ssh because ssh doesn't allow passing the password with the command"
                    }
                }
            }
        }
        stage('deploy') {
            steps {
                sh 'echo "Placeholder for post-deploy jobs....."'
                // Deploys the Bastion Host VPC and Infrastructure Stacks
                sh 'echo "Deploy the BH Networking stack"'
                sh 'aws cloudformation deploy \
                    --stack-name eks-hacking-bh-vpc-stack \
                    --template-file ./IaC/bastion_host_vpc_deployment.yml'

                sh 'echo "Deploy the BH IAM stack"'
                sh 'aws cloudformation deploy \
                    --stack-name eks-hacking-bh-iam-stack \
                    --template-file ./IaC/bastion_host_iam_deployment.yml \
                    --capabilities CAPABILITY_IAM'

                sh 'echo "Deploy the BH Infrastructure stack"'
                sh 'aws cloudformation create-stack \
                    --stack-name eks-hacking-bh-infrastructure-stack \
                    --template-body file://./IaC/bastion_host_infrastructure_deployment.yml \
                    --parameters file://./parameters.json \
                    --capabilities CAPABILITY_NAMED_IAM'

                // Deploys the EKS VPC and Infrastructure Stacks
                sh 'echo "Deploy the EKS Networking stack"'
                sh 'aws cloudformation deploy \
                    --stack-name eks-hacking-eks-vpc-stack \
                    --template-file ./IaC/eks_vpc_deployment.yml'

                sh 'echo "Deploy the EKS IAM stack"'
                sh 'aws cloudformation deploy \
                    --stack-name eks-hacking-eks-iam-stack \
                    --template-file ./IaC/eks_iam_deployment.yml \
                    --capabilities CAPABILITY_NAMED_IAM'

                // Deploys the VPC Peering Connection Stack
                sh 'echo "Deploy VPC Peering Connection so Bastion Hosts can connect to EKS Cluster"'
                sh 'aws cloudformation deploy \
                    --stack-name eks-hacking-eks-bh-vpc-peering-stack \
                    --template-file ./IaC/eks_bh_vpc_peering_deployment.yml'

                sh 'echo "Deploy the EKS Infrastructure Stack"'
                sh 'aws cloudformation deploy \
                    --stack-name eks-hacking-eks-infrastructure-stack \
                    --template-file ./IaC/eks_infrastructure_deployment.yml'
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