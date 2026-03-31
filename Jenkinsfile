pipeline {
    agent any // run on any available Jenkins agent

    tools { // what tools Jenkins should make available
        nodejs 'node-24'
    }

    environment {   // global variables available to all stages
        AWS_REGION = 'ca-central-1'
        ECR_REGISTRY = '790400775070.dkr.ecr.ca-central-1.amazonaws.com'
        ECR_REPOSITORY = 'aws-node-app'
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
        EC2_INSTANCE = "ec2-user@3.96.205.178"
    }

    stages { // the actual pipeline steps
        stage('Increment Version') {
            steps {
                dir('app'){ // runs the command inside the app/ folder
                    sh 'npm version minor --no-git-tag-version' // npm version minor - bumps the middle number in package.json e.g. 1.0.0 → 1.1.0
                                                                // --no-git-tag-version — prevents npm from trying to create a git tag (Jenkins handles git itself, so this would cause a conflict)
                }
                script {
                    def version = sh(
                        script: "cd app && node -p \"require('./package.json').version\"",
                        returnStdout:true // runs the command AND captures its output as a string
                    ).trim() // removes any trailing newline from the output
                    env.IMAGE_VERSION = "$version-$BUILD_NUMBER" // stores it as a pipeline environment variable so later stages can use ${IMAGE_VERSION}
                }
            }
        }
        stage('Test') {
            steps {
                dir('app'){
                    sh 'npm install' // Installs dependencies then runs Jest tests
                    sh 'npm test'    // If npm test fails, the entire pipeline stops here — nothing gets built or pushed. This is the safety gate that ensures only working code gets deployed
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                echo 'building the docker image...'
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_VERSION} ." // Builds the Docker image using Dockerfile that is located in the project root
            }
        }
        stage('Push to ECR') {
            steps {
                script {
                    // Login to ECR
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"

                    // Push image
                    sh "docker push ${IMAGE_NAME}:${IMAGE_VERSION}"
                }
            }
        }
        stage('Depoly to EC2'){
            steps {
                script {
                    echo "deploying docker image to EC2..."

                    def shellCmd = "bash ./server-cmds.sh ${IMAGE_NAME}:${IMAGE_VERSION}"

                    sshagent(['ec2-web-server-key']) {
                        // Copy deploy script and docker-compose to EC2
                        sh "scp -o StrictHostKeyChecking=no server-cmds.sh ${EC2_INSTANCE}:/home/ec2-user"
                        sh "scp -o StrictHostKeyChecking=no docker-compose.yaml ${EC2_INSTANCE}:/home/ec2-user"
                        sh "ssh -o StrictHostKeyChecking=no ${EC2_INSTANCE} ${shellCmd}"
                    }
                }
            }
        }
        stage('Commit to Git') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-creds',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    sh 'git config --global user.email "jenkins@ci.com"' // Sets a git identity label for Jenkins (required to make commits)
                    sh 'git config --global user.name "Jenkins"'
                    sh "git remote set-url origin https://${GIT_USER}:${GIT_PASS}@github.com/KarenCattie/09-aws-exercises.git"
                    sh 'git add .'
                    sh "git commit -m \"ci: bump version to ${IMAGE_VERSION}\""
                    sh "git push origin HEAD:main" // HEAD = "my current local commit", main = "push it to the main branch on GitHub"
                }
            }
        }
    }
    post {
        success {
            echo 'Deployed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}