pipeline {
    agent any

    environment {
        TF_VAR_key_name = 'devmart-key'
    }

    stages {
        stage('Init') {
            steps {
                bat 'terraform init -migrate-state -force-copy'
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
                        error("Branch no soportada: ${env.BRANCH_NAME}")
                    }
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
                branch 'main'
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
            script {
                def ambiente = env.BRANCH_NAME == 'main' ? 'PROD' : 'QA'
                echo "Infraestructura desplegada en ${ambiente}"
            }
        }
        failure {
            echo 'Fallo el pipeline de terraform'
        }
    }
}
