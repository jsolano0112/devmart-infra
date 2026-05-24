pipeline {

    agent any

    parameters {
        booleanParam(
            name: 'autoApprove',
            defaultValue: false,
            description: 'Aplicar sin aprobación manual (solo QA)'
        )
    }

    environment {
        TF_VAR_key_name = 'devmart-key'
    }

    stages {

        stage('Init') {
            steps {
                bat 'terraform init'
            }
        }

        stage('Workspace') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'develop') {
                        bat 'terraform workspace select -or-create qa'
                    } else if (env.BRANCH_NAME == 'main') {
                        bat 'terraform workspace select -or-create prod'
                    } else {
                        error("❌ Branch no soportada: ${env.BRANCH_NAME}")
                    }
                }
            }
        }

        stage('Plan') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key',     variable: 'TF_VAR_aws_access_key'),
                    string(credentialsId: 'aws-secret-key',     variable: 'TF_VAR_aws_secret_key'),
                    string(credentialsId: 'jwt-secret',         variable: 'TF_VAR_jwt_secret'),
                    string(credentialsId: 'jwt-refresh-secret', variable: 'TF_VAR_jwt_refresh_secret'),
                    string(credentialsId: 'db-username',        variable: 'TF_VAR_db_username'),
                    string(credentialsId: 'db-password',        variable: 'TF_VAR_db_password')
                ]) {
                    bat 'terraform plan -out=tfplan'
                    bat 'terraform show -no-color tfplan > tfplan.txt'
                }
            }
        }

        stage('Aprobación') {
            when {
                not {
                    equals expected: true, actual: params.autoApprove
                }
            }
            steps {
                script {
                    def plan = readFile 'tfplan.txt'
                    input message: "¿Aprobar apply en ${env.BRANCH_NAME == 'main' ? 'PROD' : 'QA'}?",
                        parameters: [
                            text(name: 'Plan', defaultValue: plan)
                        ]
                }
            }
        }

        stage('Apply') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key',     variable: 'TF_VAR_aws_access_key'),
                    string(credentialsId: 'aws-secret-key',     variable: 'TF_VAR_aws_secret_key'),
                    string(credentialsId: 'jwt-secret',         variable: 'TF_VAR_jwt_secret'),
                    string(credentialsId: 'jwt-refresh-secret', variable: 'TF_VAR_jwt_refresh_secret'),
                    string(credentialsId: 'db-username',        variable: 'TF_VAR_db_username'),
                    string(credentialsId: 'db-password',        variable: 'TF_VAR_db_password')
                ]) {
                    bat 'terraform apply -input=false tfplan'
                }
            }
        }

        stage('Mostrar IP') {
            steps {
                bat 'terraform output ec2_public_ip'
            }
        }
    }

    post {
        success { echo "✅ Infraestructura desplegada en ${env.BRANCH_NAME == 'main' ? 'PROD' : 'QA'}" }
        failure { echo "❌ Falló el pipeline de terraform" }
    }
}