pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                echo 'Source code checked out by Jenkins SCM'
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform'
                ]]) {
                    dir('terraform') {
                        sh 'terraform init -input=false'
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform'
                ]]) {
                    dir('terraform') {
                        sh 'terraform validate'
                    }
                }
            }
        }

        stage('Inspect Terraform State') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform'
                ]]) {
                    dir('terraform') {
                        sh 'terraform workspace show'
                        sh 'terraform state list'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform'
                ]]) {
                    dir('terraform') {
                        sh 'terraform plan -input=false -var="allowed_ssh_cidr=103.226.200.68/32"'
                    }
                }
            }
        }

        stage('Ansible Configure SonarQube') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'vm2-ssh-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    ),
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-terraform'
                    ]
                ]) {
                    sh '''
                        set -eu

                        export ANSIBLE_ROLES_PATH="$WORKSPACE/ansible/roles"
                        export ANSIBLE_HOST_KEY_CHECKING=False

                        echo "Checking AWS credentials..."
                        aws sts get-caller-identity

                        echo "Discovering EC2 instances..."
                        ansible-inventory \
                          -i ansible/inventory/aws_ec2.yml \
                          --graph

                        echo "Testing SonarQube SSH connectivity..."
                        ansible \
                          -i ansible/inventory/aws_ec2.yml \
                          role_sonarqube_server \
                          -m ping

                        echo "Running SonarQube configuration playbook..."
                        ansible-playbook \
                          -i ansible/inventory/aws_ec2.yml \
                          ansible/playbooks/sonarqube.yml
                    '''
                }
            }
        }

        // stage('Terraform Apply') {
        //     steps {
        //         withCredentials([[
        //             $class: 'AmazonWebServicesCredentialsBinding',
        //             credentialsId: 'aws-terraform'
        //         ]]) {
        //             dir('terraform') {
        //                 sh 'terraform apply -auto-approve'
        //             }
        //         }
        //     }
        // }

        // stage('SonarQube URL') {
        //     steps {
        //         withCredentials([[
        //             $class: 'AmazonWebServicesCredentialsBinding',
        //             credentialsId: 'aws-terraform'
        //         ]]) {
        //             script {
        //                 def publicIp = sh(
        //                     script: 'cd terraform && terraform output -raw sonarqube_public_ip',
        //                     returnStdout: true
        //                 ).trim()

        //                 echo "SonarQube URL: http://${publicIp}:9000"
        //             }
        //         }
        //     }
        // }



    }
}