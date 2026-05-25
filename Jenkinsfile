def resolveDeployTarget() {
    def explicit = env.DEPLOY_ENV?.trim()?.toLowerCase()
    if (explicit in ['qa', 'prod']) {
        return explicit
    }

    def branch = env.BRANCH_NAME?.trim()
    if (!branch && env.GIT_BRANCH) {
        branch = env.GIT_BRANCH.replaceFirst(/^origin\//, '').trim()
    }

    if (branch == 'main') {
        return 'prod'
    }
    if (branch in ['qa', 'develop']) {
        return 'qa'
    }

    def job = env.JOB_NAME?.toLowerCase() ?: ''
    if (job.contains('prod')) {
        return 'prod'
    }
    if (job.contains('qa')) {
        return 'qa'
    }

    error("No se pudo determinar qa/prod. DEPLOY_ENV=${env.DEPLOY_ENV}, BRANCH_NAME=${env.BRANCH_NAME}, GIT_BRANCH=${env.GIT_BRANCH}, JOB_NAME=${env.JOB_NAME}")
}

def fixSshKeyPermissions(String keyPath) {
    bat """
        icacls "${keyPath}" /inheritance:r
        icacls "${keyPath}" /remove "BUILTIN\\Usuarios" 2>nul
        icacls "${keyPath}" /remove "BUILTIN\\Users" 2>nul
        icacls "${keyPath}" /grant:r "%USERNAME%:R"
    """
}

def getTerraformOutput(String name) {
    return bat(returnStdout: true, script: "@echo off\r\nterraform output -raw ${name}").trim()
}

pipeline {
    agent any

    environment {
        TF_VAR_key_name               = 'devmart-key'
        TF_VAR_write_private_key_file = 'false'
    }

    options {
        timeout(time: 90, unit: 'MINUTES')
    }

    stages {
        stage('Setup') {
            steps {
                script {
                    env.DEPLOY_TARGET = resolveDeployTarget()
                    env.INFRA_BRANCH = env.DEPLOY_TARGET == 'prod' ? 'main' : 'develop'
                    env.SSH_CREDENTIAL = env.DEPLOY_TARGET == 'prod' ? 'devmart-ssh-key-prod' : 'devmart-ssh-key-qa'
                    echo "Entorno: ${env.DEPLOY_TARGET} | Infra branch: ${env.INFRA_BRANCH}"
                    echo "SSH Jenkins: ${env.SSH_CREDENTIAL}"
                }
            }
        }

        stage('Init') {
            steps {
                bat 'terraform init -migrate-state -force-copy'
            }
        }

        stage('Workspace') {
            steps {
                script {
                    def workspace = env.DEPLOY_TARGET == 'prod' ? 'prod' : 'qa'
                    bat "terraform workspace select -or-create ${workspace}"
                }
            }
        }

        stage('Migrar State') {
            steps {
                bat '''
                    @echo off
                    terraform state rm local_file.private_key 2>nul
                    terraform state rm "local_file.private_key[0]" 2>nul
                    exit /b 0
                '''
            }
        }

        stage('Validate') {
            steps {
                bat 'terraform validate'
            }
        }

        stage('Plan') {
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'TF_VAR_aws_access_key'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'TF_VAR_aws_secret_key')
                ]) {
                    bat 'terraform refresh -input=false'
                    bat 'terraform plan -out=tfplan'
                    bat 'terraform show -no-color tfplan > tfplan.txt'
                }
            }
        }

        stage('Aprobacion PROD') {
            when {
                expression { env.DEPLOY_TARGET == 'prod' }
            }
            steps {
                script {
                    def plan = readFile 'tfplan.txt'
                    input message: 'Aprobar apply en PROD?',
                        parameters: [text(name: 'Plan', defaultValue: plan)]
                }
            }
        }

        stage('Apply') {
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'TF_VAR_aws_access_key'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'TF_VAR_aws_secret_key')
                ]) {
                    bat 'terraform apply -input=false tfplan'
                }
            }
        }

        stage('Outputs') {
            steps {
                script {
                    env.EC2_PUBLIC_IP = getTerraformOutput('ec2_public_ip')
                    echo "EC2 IP: ${env.EC2_PUBLIC_IP}"
                }
            }
        }

        stage('Deploy Stack') {
            steps {
                script {
                    def ec2Ip = env.EC2_PUBLIC_IP ?: getTerraformOutput('ec2_public_ip')

                    withCredentials([
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'jwt-refresh-secret', variable: 'JWT_REFRESH_SECRET'),
                        string(credentialsId: 'mongo-db-username', variable: 'DB_USERNAME'),
                        string(credentialsId: 'mongo-db-password', variable: 'DB_PASSWORD'),

                        string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                        string(credentialsId: 'aws-s3-bucket', variable: 'AWS_S3_BUCKET'),

                        sshUserPrivateKey(
                            credentialsId: env.SSH_CREDENTIAL,
                            keyFileVariable: 'SSH_KEY'
                        )
                    ]) {
                        writeFile file: 'stack.env', text: """ENVIRONMENT=${env.DEPLOY_TARGET}
                        JWT_SECRET=${JWT_SECRET}
                        JWT_EXPIRE_IN=15m
                        JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
                        JWT_REFRESH_EXPIRE_IN=20m
                        DB_USERNAME=${DB_USERNAME}
                        DB_PASSWORD=${DB_PASSWORD}

                        SOCKET_SERVER_URL=http://websocket-1:5000

                        AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        AWS_REGION=${AWS_REGION}
                        AWS_S3_BUCKET=${AWS_S3_BUCKET}
                        """

                        fixSshKeyPermissions(env.SSH_KEY)

                        bat """
                            scp -o StrictHostKeyChecking=no -i "%SSH_KEY%" stack.env ubuntu@${ec2Ip}:/tmp/stack.env
                            scp -o StrictHostKeyChecking=no -i "%SSH_KEY%" docker-compose.yml ubuntu@${ec2Ip}:/tmp/docker-compose.yml
                            scp -o StrictHostKeyChecking=no -i "%SSH_KEY%" nginx.conf ubuntu@${ec2Ip}:/tmp/nginx.conf
                            scp -o StrictHostKeyChecking=no -i "%SSH_KEY%" scripts/remote-deploy.sh ubuntu@${ec2Ip}:/tmp/remote-deploy.sh
                        """

                        bat """
                            ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" ubuntu@${ec2Ip} "sed -i 's/\\r\$//' /tmp/remote-deploy.sh && chmod +x /tmp/remote-deploy.sh && bash /tmp/remote-deploy.sh ${env.INFRA_BRANCH}"
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            bat '''
                @echo off
                if exist stack.env del /f /q stack.env 2>nul
                exit /b 0
            '''
        }
        success {
            script {
                def appUrl = getTerraformOutput('app_url')
                echo '=========================================='
                echo " OK - ${env.DEPLOY_TARGET == 'prod' ? 'PROD' : 'QA'}"
                echo " URL: ${appUrl}"
                echo '=========================================='
            }
        }
        failure {
            echo 'Fallo el pipeline de devmart-infra.'
        }
    }
}
