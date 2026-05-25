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

pipeline {
    agent any

    environment {
        TF_VAR_key_name = 'devmart-key'
    }

    stages {
        stage('Setup') {
            steps {
                script {
                    env.DEPLOY_TARGET = resolveDeployTarget()
                    echo "Entorno detectado: ${env.DEPLOY_TARGET}"
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

        stage('Validate') {
            steps {
                bat 'terraform validate'
            }
        }

        stage('Plan') {
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'TF_VAR_aws_access_key'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'TF_VAR_aws_secret_key'),
                    string(credentialsId: 'jwt-secret',            variable: 'TF_VAR_jwt_secret'),
                    string(credentialsId: 'jwt-refresh-secret',    variable: 'TF_VAR_jwt_refresh_secret'),
                    string(credentialsId: 'mongo-db-username',     variable: 'TF_VAR_db_username'),
                    string(credentialsId: 'mongo-db-password',     variable: 'TF_VAR_db_password')
                ]) {
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
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'TF_VAR_aws_secret_key'),
                    string(credentialsId: 'jwt-secret',            variable: 'TF_VAR_jwt_secret'),
                    string(credentialsId: 'jwt-refresh-secret',    variable: 'TF_VAR_jwt_refresh_secret'),
                    string(credentialsId: 'mongo-db-username',     variable: 'TF_VAR_db_username'),
                    string(credentialsId: 'mongo-db-password',     variable: 'TF_VAR_db_password')
                ]) {
                    bat 'terraform apply -input=false tfplan'
                }
            }
        }

        stage('Outputs') {
            steps {
                bat 'terraform output ec2_public_ip'
            }
        }
    }

    post {
        success {
            echo "Infraestructura desplegada en ${env.DEPLOY_TARGET == 'prod' ? 'PROD' : 'QA'}"
        }
        failure {
            echo 'Fallo el pipeline de terraform'
        }
    }
}
