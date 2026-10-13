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

                        echo "===== Checking AWS Credentials ====="
                        aws sts get-caller-identity

                        echo "===== Discovering EC2 Instances ====="
                        ansible-inventory \
                          -i ansible/inventory/aws_ec2.yml \
                          --graph

                        echo "===== Discovering Bastion Public IP ====="
                        
                        BASTION_IP=$(aws ec2 describe-instances \
                        --region ap-south-1 \
                        --filters "Name=tag:Name,Values=sonarqube-bastion" \
                                    "Name=instance-state-name,Values=running" \
                        --query 'Reservations[0].Instances[0].PublicIpAddress' \
                        --output text)


                        if [ -z "$BASTION_IP" ] || [ "$BASTION_IP" = "None" ]; then
                            echo "ERROR: Running Bastion instance not found"
                            exit 1
                        fi

                        echo "Bastion IP discovered dynamically: $BASTION_IP"

                        echo "===== Testing Bastion SSH ====="
                        ssh -vv \
                          -i "$SSH_KEY" \
                          -o BatchMode=yes \
                          -o ConnectTimeout=10 \
                          -o StrictHostKeyChecking=accept-new \
                          "${SSH_USER}@$BASTION_IP" \
                          "echo Bastion SSH successful"

                        echo "===== Ansible SSH Configuration ====="
                            ansible-inventory \
                            -i ansible/inventory/aws_ec2.yml \
                            --host i-01b3438d0b59c7bc4

                        echo "===== Testing SonarQube SSH via Bastion ====="
                        ansible \
                          -i ansible/inventory/aws_ec2.yml \
                          role_sonarqube_server \
                          -m ping

                        echo "===== Running SonarQube Ansible Playbook ====="
                        ansible-playbook \
                          -i ansible/inventory/aws_ec2.yml \
                          ansible/playbooks/sonarqube.yml

                        echo "===== SonarQube Ansible Configuration Completed ====="
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