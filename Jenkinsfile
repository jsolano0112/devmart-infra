def getTerraformOutput(String name) {
    return bat(returnStdout: true, script: "@echo off\r\nterraform output -raw ${name}").trim()
}

def forceEcsRedeploy(String cluster, String region, List<String> services) {
    services.each { svc ->
        bat "@echo off && aws ecs update-service --cluster ${cluster} --service ${svc} --force-new-deployment --region ${region} > nul"
        echo "Redeployado: ${svc}"
    }
}

pipeline {
    agent any

    options {
        timeout(time: 90, unit: 'MINUTES')
    }

    stages {
        stage('Init') {
            steps {
                bat 'terraform init'
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
                    string(credentialsId: 'mongo-db-password',     variable: 'TF_VAR_db_password'),
                    string(credentialsId: 'aws-s3-bucket',         variable: 'TF_VAR_aws_s3_bucket'),
                ]) {
                    bat 'terraform plan -out=tfplan'
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
                    string(credentialsId: 'mongo-db-password',     variable: 'TF_VAR_db_password'),
                    string(credentialsId: 'aws-s3-bucket',         variable: 'TF_VAR_aws_s3_bucket'),
                ]) {
                    bat 'terraform apply -input=false tfplan'
                }
            }
        }

        stage('Outputs') {
            steps {
                script {
                    env.ECS_CLUSTER = getTerraformOutput('ecs_cluster_name')
                    env.APP_URL     = getTerraformOutput('app_url')
                    echo "Cluster: ${env.ECS_CLUSTER}"
                    echo "URL: ${env.APP_URL}"
                }
            }
        }

        stage('Deploy Stack') {
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY'),
                ]) {
                    script {
                        def services = [
                            "devmart-api",
                            "users-api",
                            "devmart-ui"
                        ]
                        forceEcsRedeploy(env.ECS_CLUSTER, 'us-east-1', services)
                    }
                }
            }
        }
    }

    post {
        success {
            echo '=========================================='
            echo " OK - Despliegue completado con éxito"
            echo " URL: ${env.APP_URL}"
            echo '=========================================='
        }
        failure {
            echo 'Fallo el pipeline de devmart-infra.'
        }
    }
}