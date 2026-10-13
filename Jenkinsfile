
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
                        sh '''
                            terraform plan \
                              -input=false \
                              -var="allowed_ssh_cidr=103.226.200.68/32"
                        '''
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

                        export AWS_DEFAULT_REGION=ap-south-1
                        export ANSIBLE_ROLES_PATH="$WORKSPACE/ansible/roles"
                        export ANSIBLE_HOST_KEY_CHECKING=False

                        echo "===== Checking AWS Credentials ====="
                        aws sts get-caller-identity

                        echo "===== Discovering EC2 Instances ====="
                        ansible-inventory \
                          -i ansible/inventory/aws_ec2.yml \
                          --graph

                        echo "===== Discovering Bastion IP ====="
                        BASTION_IP=$(aws ec2 describe-instances \
                          --region "$AWS_DEFAULT_REGION" \
                          --filters \
                            "Name=tag:Name,Values=sonarqube-bastion" \
                            "Name=instance-state-name,Values=running" \
                          --query 'Reservations[0].Instances[0].PublicIpAddress' \
                          --output text)

                        if [ -z "$BASTION_IP" ] || [ "$BASTION_IP" = "None" ]; then
                            echo "ERROR: Running Bastion instance not found"
                            exit 1
                        fi

                        echo "Bastion IP discovered successfully."

                        echo "===== Testing Bastion SSH ====="
                        ssh \
                          -i "$SSH_KEY" \
                          -o IdentitiesOnly=yes \
                          -o BatchMode=yes \
                          -o ConnectTimeout=10 \
                          -o StrictHostKeyChecking=accept-new \
                          "${SSH_USER}@$BASTION_IP" \
                          "echo Bastion SSH successful"

                        
                        echo "===== Testing SonarQube SSH via Bastion ====="

                        ansible \
                            -i ansible/inventory/aws_ec2.yml \
                            role_sonarqube_server \
                            -m ping \
                            --user "$SSH_USER" \
                            --private-key "$SSH_KEY" \
                            --ssh-common-args="-o ProxyJump=${SSH_USER}@${BASTION_IP}"

                        echo "===== Running SonarQube Playbook ====="

                        ansible-playbook \
                            -i ansible/inventory/aws_ec2.yml \
                            ansible/playbooks/sonarqube.yml \
                            --user "$SSH_USER" \
                            --private-key "$SSH_KEY" \
                            --ssh-common-args="-o ProxyJump=${SSH_USER}@${BASTION_IP}"

                        echo "===== SonarQube Ansible Configuration Completed ====="
                    '''
                }
            }
        }

        // Keep Terraform Apply disabled until explicitly required.
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

    }
}
