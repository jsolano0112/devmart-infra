pipeline {

    agent any

    parameters {
        booleanParam(name: 'autoApprove', defaultValue: false)
    }

    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }

    stages {

        stage('Plan') {
            steps {
                dir('.') {
                    bat 'terraform init'
                    bat 'terraform plan -out=tfplan'
                    bat 'terraform show -no-color tfplan > tfplan.txt'
                }
            }
        }

        stage('Approval') {
            when {
                not {
                    equals expected: true, actual: params.autoApprove
                }
            }

            steps {
                script {
                    def plan = readFile 'terraform/tfplan.txt'
                    input message: "Approve apply?",
                        parameters: [
                            text(name: 'Plan', defaultValue: plan)
                        ]
                }
            }
        }

        stage('Apply') {
            steps {
                dir('.') {
                    bat 'terraform apply -input=false tfplan'
                }
            }
        }
    }
}