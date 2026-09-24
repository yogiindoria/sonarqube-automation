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
                        sh 'terraform init -migrate-state -input=false'
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

        stage('Terraform Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform'
                ]]) {
                    dir('terraform') {
                        sh 'terraform plan'
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform'
                ]]) {
                    dir('terraform') {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        stage('SonarQube URL') {
            steps {
                script {
                    def publicIp = sh(
                        script: 'cd terraform && terraform output -raw sonarqube_public_ip',
                        returnStdout: true
                    ).trim()

                    echo "SonarQube URL: http://${publicIp}:9000"
                }
            }
        }
    }
}