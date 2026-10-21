pipeline {
    agent any

    parameters {
        string(
            name: 'ALLOWED_SSH_CIDR',
            defaultValue: '',
            description: 'Optional. Public IP in CIDR format, e.g. 203.0.113.10/32. Leave blank to auto-detect the Jenkins machine public IP.'
        )
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Source code checked out by Jenkins SCM'
            }
        }

        stage('Resolve SSH CIDR') {
            steps {
                script {
                    def cidr = (params.ALLOWED_SSH_CIDR ?: '').trim()
                    if (!cidr) {
                        def ip = sh(
                            script: 'curl -4 -s --max-time 10 https://checkip.amazonaws.com',
                            returnStdout: true
                        ).trim()
                        cidr = "${ip}/32".toString()
                        echo "Auto-detected public IP: ${cidr}"
                    }
                    if (!(cidr ==~ '^\\d{1,3}(\\.\\d{1,3}){3}/32$')) {
                        error("Invalid CIDR '${cidr}'. It must look like 203.0.113.10/32")
                    }
                    env.SSH_CIDR = cidr
                }
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
                        sh 'terraform state list || true'
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
                              -var="allowed_ssh_cidr=$SSH_CIDR" \
                              -out=tfplan
                        '''
                    }
                }
            }
        }

        stage('Approval') {
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: 'Plan check kar liya? Terraform Apply karna hai?', ok: 'Apply'
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
                        sh 'terraform apply -input=false tfplan'
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
                    file(
                        credentialsId: 'ansible-vault-pass',
                        variable: 'VAULT_PASS_FILE'
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
                        export ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_PASS_FILE"

                        echo "===== Checking AWS Credentials ====="
                        aws sts get-caller-identity

                        echo "===== Discovering EC2 Instances ====="
                        ansible-inventory -i ansible/inventory/aws_ec2.yml --graph

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

                        echo "===== Starting ssh-agent ====="
                        eval "$(ssh-agent -s)"
                        trap 'ssh-agent -k >/dev/null 2>&1 || true' EXIT
                        ssh-add "$SSH_KEY"

                        SSH_ARGS="-o ProxyJump=${SSH_USER}@${BASTION_IP} -o StrictHostKeyChecking=accept-new"

                        echo "===== Testing Bastion SSH (waits for fresh instance) ====="
                        OK=0
                        for i in $(seq 1 20); do
                            if ssh -o BatchMode=yes -o ConnectTimeout=10 \
                                -o StrictHostKeyChecking=accept-new \
                                "${SSH_USER}@${BASTION_IP}" "echo Bastion SSH successful"; then
                                OK=1
                                break
                            fi
                            echo "Bastion not ready yet (attempt $i/20), retrying in 15s..."
                            sleep 15
                        done
                        [ "$OK" = "1" ] || { echo "ERROR: Bastion SSH never became reachable"; exit 1; }

                        echo "===== Testing SonarQube SSH via Bastion ====="
                        OK=0
                        for i in $(seq 1 20); do
                            if ansible \
                                -i ansible/inventory/aws_ec2.yml \
                                role_sonarqube_server \
                                -m ping \
                                --user "$SSH_USER" \
                                --ssh-common-args="$SSH_ARGS"; then
                                OK=1
                                break
                            fi
                            echo "SonarQube server not ready yet (attempt $i/20), retrying in 15s..."
                            sleep 15
                        done
                        [ "$OK" = "1" ] || { echo "ERROR: SonarQube server never became reachable"; exit 1; }

                        echo "===== Running SonarQube Playbook ====="
                        ansible-playbook \
                            -i ansible/inventory/aws_ec2.yml \
                            ansible/playbooks/sonarqube.yml \
                            --user "$SSH_USER" \
                            --ssh-common-args="$SSH_ARGS"

                        echo "===== SonarQube Ansible Configuration Completed ====="
                    '''
                }
            }
        }

        stage('SonarQube Bootstrap') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'vm2-ssh-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    ),
                    string(
                        credentialsId: 'sonar-admin-password',
                        variable: 'SONAR_NEW_PASS'
                    ),
                    usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_API_TOKEN'
                    ),
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-terraform'
                    ]
                ]) {
                    sh '''
                        set -eu
                        set +x   # never echo the generated token

                        export AWS_DEFAULT_REGION=ap-south-1
                        URL=http://localhost:19000
                        CRED_ID=sonar-token-new
                        TOKEN_NAME=jenkins-analysis

                        BASTION=$(cd terraform && terraform output -raw bastion_public_ip)
                        PRIV=$(cd terraform && terraform output -raw sonarqube_private_ip)

                        echo "===== Opening temporary SSH tunnel (19000 -> SonarQube:9000) ====="
                        ssh -N \
                            -o ExitOnForwardFailure=yes \
                            -o BatchMode=yes \
                            -o StrictHostKeyChecking=accept-new \
                            -i "$SSH_KEY" \
                            -L 19000:${PRIV}:9000 \
                            "${SSH_USER}@${BASTION}" &
                        TUN_PID=$!
                        trap 'kill $TUN_PID 2>/dev/null || true; rm -f /tmp/sonar-cred.xml' EXIT

                        echo "===== Waiting for SonarQube to be UP ====="
                        READY=0
                        for i in $(seq 1 30); do
                            if curl -fsS --max-time 5 "$URL/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
                                READY=1
                                break
                            fi
                            echo "Attempt $i/30: not ready yet"
                            sleep 5
                        done
                        [ "$READY" = "1" ] || { echo "ERROR: SonarQube not UP via tunnel (is port 19000 free?)"; exit 1; }

                        echo "===== Admin password ====="
                        if curl -sS -u "admin:${SONAR_NEW_PASS}" "$URL/api/authentication/validate" | grep -q '"valid":true'; then
                            echo "Admin password already set, skipping reset."
                        else
                            echo "Changing default admin password..."
                            curl -fsS -u admin:admin -X POST "$URL/api/users/change_password" \
                                --data-urlencode "login=admin" \
                                --data-urlencode "previousPassword=admin" \
                                --data-urlencode "password=${SONAR_NEW_PASS}"
                            echo "Admin password changed."
                        fi

                        echo "===== Generating analysis token ====="
                        curl -sS -u "admin:${SONAR_NEW_PASS}" -X POST "$URL/api/user_tokens/revoke" \
                            --data-urlencode "name=${TOKEN_NAME}" >/dev/null || true

                        TOKEN=$(curl -fsS -u "admin:${SONAR_NEW_PASS}" -X POST "$URL/api/user_tokens/generate" \
                            --data-urlencode "name=${TOKEN_NAME}" \
                            --data-urlencode "type=GLOBAL_ANALYSIS_TOKEN" \
                            | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
                        [ -n "$TOKEN" ] || { echo "ERROR: token not generated"; exit 1; }
                        echo "Token generated."

                        echo "===== Saving token in Jenkins credentials (${CRED_ID}) ====="
                        cat > /tmp/sonar-cred.xml <<EOF
<org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>${CRED_ID}</id>
  <description>SonarQube analysis token (auto-generated by infra pipeline)</description>
  <secret>${TOKEN}</secret>
</org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl>
EOF

                        JURL="${JENKINS_URL:-http://localhost:8081/}"
                        JURL="${JURL%/}"
                        BASE="$JURL/credentials/store/system/domain/_"

                        CODE=$(curl -s -o /dev/null -w '%{http_code}' \
                            -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" \
                            "$BASE/credential/${CRED_ID}/config.xml")

                        if [ "$CODE" = "200" ]; then
                            echo "Credential exists, updating..."
                            curl -fsS -X POST -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" \
                                -H "Content-Type: application/xml" \
                                --data-binary @/tmp/sonar-cred.xml \
                                "$BASE/credential/${CRED_ID}/config.xml"
                        else
                            echo "Credential not found (HTTP $CODE), creating..."
                            curl -fsS -X POST -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" \
                                -H "Content-Type: application/xml" \
                                --data-binary @/tmp/sonar-cred.xml \
                                "$BASE/createCredentials"
                        fi

                        echo "===== Done: token saved as Jenkins credential '${CRED_ID}' ====="
                    '''
                }
            }
        }

        stage('Access Info') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform'
                ]]) {
                    dir('terraform') {
                        sh '''
                            BASTION=$(terraform output -raw bastion_public_ip)
                            PRIV=$(terraform output -raw sonarqube_private_ip)
                            echo "================================================"
                            echo "SonarQube is UP. To open it from your machine run:"
                            echo "ssh -i ~/.ssh/VM2.pem -L 9000:${PRIV}:9000 ubuntu@${BASTION}"
                            echo "Then open http://localhost:9000"
                            echo "================================================"
                        '''
                    }
                }
            }
        }

    }
}