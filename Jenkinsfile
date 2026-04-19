// =============================================================================
// Jenkinsfile — Secure DevOps Automation Platform
// Declarative pipeline with parallel Security Gate, SCA, IaC, Blue-Green Deploy
// =============================================================================

pipeline {
    agent {
        docker {
            image 'build-agent:hardened-1.2'
            args '-v /var/run/docker.sock:/var/run/docker.sock --user 1001:1001'
        }
    }

    environment {
        // SonarQube
        SONAR_HOST_URL          = 'http://sonarqube:9000'
        SONAR_PROJECT_KEY       = 'secure-devops-platform'

        // Container registry
        IMAGE_REGISTRY          = 'localhost:5000'
        IMAGE_NAME              = 'secure-app'
        IMAGE_TAG               = "${BUILD_NUMBER}"

        // Kubernetes
        KUBE_NAMESPACE          = 'secure-app'

        // Trivy
        TRIVY_SEVERITY          = 'CRITICAL,HIGH'
        TRIVY_EXIT_CODE         = '1'

        // Slack
        SLACK_CHANNEL           = '#devsecops-alerts'
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))
        ansiColor('xterm')
    }

    stages {
        // =====================================================================
        // STAGE 1: Checkout
        // =====================================================================
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.GIT_AUTHOR = sh(
                        script: 'git log -1 --format="%an"',
                        returnStdout: true
                    ).trim()
                    echo "Building commit ${env.GIT_COMMIT_SHORT} by ${env.GIT_AUTHOR}"
                }
            }
        }

        // =====================================================================
        // STAGE 2: Security Gate (Parallel: SAST+Lint, Secret Scan)
        // =====================================================================
        stage('Security Gate') {
            parallel {
                // ----- SAST + Lint -----
                stage('SAST + Lint') {
                    steps {
                        // Step 1: Language linters (warnings only, not blockers)
                        echo '=== Running Language Linters ==='

                        // Checkstyle for Java
                        sh '''
                            cd app && mvn checkstyle:checkstyle \
                                -Dcheckstyle.consoleOutput=true \
                                -Dcheckstyle.failsOnError=false \
                                -B -q || true
                        '''

                        // Step 2: Build with tests + JaCoCo coverage
                        echo '=== Building with Tests and Coverage ==='
                        sh '''
                            cd app && mvn clean verify \
                                -Djacoco.destFile=target/jacoco.exec \
                                -B
                        '''

                        // Step 3: SonarQube SAST analysis
                        echo '=== Running SonarQube SAST Analysis ==='
                        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                            sh '''
                                cd app && mvn sonar:sonar \
                                    -Dsonar.host.url=${SONAR_HOST_URL} \
                                    -Dsonar.token=${SONAR_TOKEN} \
                                    -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                    -Dsonar.qualitygate.wait=true \
                                    -Dsonar.coverage.jacoco.xmlReportPaths=*/target/site/jacoco/jacoco.xml \
                                    -B
                            '''
                        }

                        // Step 4: Poll SonarQube Quality Gate API
                        echo '=== Polling SonarQube Quality Gate ==='
                        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                            script {
                                def maxAttempts = 30
                                def attempt = 0
                                def qualityGateStatus = 'NONE'

                                while (attempt < maxAttempts && qualityGateStatus == 'NONE') {
                                    attempt++
                                    sleep(time: 10, unit: 'SECONDS')

                                    def response = sh(
                                        script: """
                                            curl -s -u ${SONAR_TOKEN}: \
                                                '${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}'
                                        """,
                                        returnStdout: true
                                    ).trim()

                                    def jsonResponse = readJSON(text: response)
                                    qualityGateStatus = jsonResponse.projectStatus?.status ?: 'NONE'
                                    echo "Quality Gate attempt ${attempt}: ${qualityGateStatus}"
                                }

                                if (qualityGateStatus == 'ERROR') {
                                    // Fetch detailed issues report
                                    def issuesResponse = sh(
                                        script: """
                                            curl -s -u ${SONAR_TOKEN}: \
                                                '${SONAR_HOST_URL}/api/issues/search?projectKeys=${SONAR_PROJECT_KEY}&severities=BLOCKER,CRITICAL&statuses=OPEN&ps=100'
                                        """,
                                        returnStdout: true
                                    ).trim()

                                    writeFile(file: 'sast-report.json', text: issuesResponse)
                                    archiveArtifacts artifacts: 'sast-report.json', fingerprint: true

                                    error("SonarQube Quality Gate FAILED — see sast-report.json for details")
                                } else if (qualityGateStatus == 'NONE') {
                                    error("SonarQube Quality Gate status could not be determined after ${maxAttempts} attempts")
                                }

                                echo "SonarQube Quality Gate PASSED: ${qualityGateStatus}"
                            }
                        }
                    }
                }

                // ----- Secret Scan -----
                stage('Secret Scan') {
                    steps {
                        echo '=== Running Gitleaks Secret Detection ==='

                        script {
                            def gitleaksExitCode = sh(
                                script: '''
                                    gitleaks detect \
                                        --source . \
                                        --config .gitleaks.toml \
                                        --report-format json \
                                        --report-path gitleaks-report.json \
                                        --verbose \
                                        --log-level info
                                ''',
                                returnStatus: true
                            )

                            if (gitleaksExitCode != 0) {
                                // Archive the secrets report
                                archiveArtifacts artifacts: 'gitleaks-report.json', fingerprint: true

                                // Parse and display findings
                                if (fileExists('gitleaks-report.json')) {
                                    def reportContent = readFile('gitleaks-report.json')
                                    def findings = readJSON(text: reportContent)

                                    echo "========================================================="
                                    echo "  SECRETS DETECTED — PIPELINE ABORT"
                                    echo "========================================================="
                                    findings.each { finding ->
                                        echo "  File:   ${finding.File ?: 'unknown'}"
                                        echo "  Commit: ${finding.Commit ?: 'unknown'}"
                                        echo "  Rule:   ${finding.RuleID ?: 'unknown'}"
                                        echo "  Line:   ${finding.StartLine ?: 'unknown'}"
                                        echo "  ---"
                                    }
                                    echo "========================================================="
                                }

                                // CRITICAL ALERT — Secrets found overrides ALL other stages
                                currentBuild.result = 'FAILURE'
                                error("CRITICAL: Secrets detected in repository! Pipeline aborted immediately. See gitleaks-report.json")
                            }

                            echo "Gitleaks scan PASSED — no secrets detected"
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SECURITY GATE DECISION (Early Exit)
        // =====================================================================
        stage('Security Gate Decision') {
            steps {
                script {
                    // This stage implements the exact early-exit logic:
                    // if secrets_found > 0: ABORT (already handled in parallel stage)
                    // if sast_quality_gate == FAILED: FAIL (already handled in SAST stage)
                    // Both run in parallel, but Secret Scan failure causes immediate abort

                    echo "Security Gate PASSED — proceeding to Container Build"
                }
            }
        }

        // =====================================================================
        // STAGE 3: Docker Build + SCA (Container Vulnerability Scanning)
        // =====================================================================
        stage('Docker Build + SCA') {
            steps {
                // Step 1: Hadolint Dockerfile linting
                echo '=== Running Hadolint Dockerfile Linting ==='
                sh '''
                    hadolint --config .hadolint.yaml Dockerfile \
                        --format json > hadolint-report.json || {
                            echo "Hadolint found FATAL violations — build blocked"
                            cat hadolint-report.json
                            exit 1
                        }
                    echo "Hadolint check PASSED"
                '''

                // Step 2: Docker build
                echo '=== Building Docker Image ==='
                sh """
                    docker build \
                        -t ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${IMAGE_REGISTRY}/${IMAGE_NAME}:latest \
                        --label "build.number=${BUILD_NUMBER}" \
                        --label "git.commit=${GIT_COMMIT_SHORT}" \
                        --label "build.timestamp=\$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                        --no-cache \
                        .
                """

                // Step 3: Trivy SCA scan
                echo '=== Running Trivy Container Vulnerability Scan ==='
                sh """
                    trivy image \
                        --severity CRITICAL,HIGH \
                        --ignore-unfixed \
                        --ignorefile .trivyignore \
                        --format json \
                        --output trivy-report.json \
                        ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                """

                // Step 4: Parse Trivy results and enforce thresholds
                script {
                    def trivyReport = readJSON(file: 'trivy-report.json')
                    def criticalCount = 0
                    def highCount = 0

                    trivyReport.Results?.each { result ->
                        result.Vulnerabilities?.each { vuln ->
                            if (vuln.Severity == 'CRITICAL') criticalCount++
                            if (vuln.Severity == 'HIGH') highCount++
                        }
                    }

                    echo "Trivy Results: ${criticalCount} CRITICAL, ${highCount} HIGH vulnerabilities"

                    // BLOCKING: 0 CRITICAL CVEs, max 3 HIGH CVEs with available fixes
                    if (criticalCount > 0) {
                        archiveArtifacts artifacts: 'trivy-report.json', fingerprint: true
                        error("Container SCA FAILED: ${criticalCount} CRITICAL CVEs found (threshold: 0)")
                    }

                    if (highCount > 3) {
                        archiveArtifacts artifacts: 'trivy-report.json', fingerprint: true
                        error("Container SCA FAILED: ${highCount} HIGH CVEs found (threshold: 3)")
                    }

                    echo "Container SCA PASSED: ${criticalCount} CRITICAL, ${highCount} HIGH"
                }

                // Also produce human-readable table output
                sh """
                    trivy image \
                        --severity CRITICAL,HIGH \
                        --ignore-unfixed \
                        --format table \
                        ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true
                """

                // Archive reports
                archiveArtifacts artifacts: 'trivy-report.json,hadolint-report.json', fingerprint: true
            }
        }

        // =====================================================================
        // STAGE 4: Push Container Image
        // =====================================================================
        stage('Push Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'container-registry-creds',
                    usernameVariable: 'REGISTRY_USER',
                    passwordVariable: 'REGISTRY_PASS'
                )]) {
                    sh """
                        echo \${REGISTRY_PASS} | docker login ${IMAGE_REGISTRY} \
                            -u \${REGISTRY_USER} --password-stdin
                        docker push ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_REGISTRY}/${IMAGE_NAME}:latest
                        docker logout ${IMAGE_REGISTRY}
                    """
                }
            }
        }

        // =====================================================================
        // STAGE 5: IaC Security + Provision
        // =====================================================================
        stage('IaC Security + Provision') {
            steps {
                // Step 1: tfsec scan
                echo '=== Running tfsec IaC Security Scan ==='
                script {
                    def tfsecExitCode = sh(
                        script: '''
                            tfsec ./terraform \
                                --format json \
                                --out tfsec-report.json \
                                --minimum-severity HIGH
                        ''',
                        returnStatus: true
                    )

                    if (tfsecExitCode != 0) {
                        archiveArtifacts artifacts: 'tfsec-report.json', fingerprint: true
                        error("tfsec found CRITICAL/HIGH findings in Terraform — pipeline blocked")
                    }
                    echo "tfsec scan PASSED"
                }

                // Step 2: Terraform plan
                echo '=== Running Terraform Plan ==='
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        cd terraform
                        terraform init -input=false
                        terraform plan \
                            -out=tfplan \
                            -input=false \
                            -detailed-exitcode || {
                                PLAN_EXIT=$?
                                if [ $PLAN_EXIT -eq 1 ]; then
                                    echo "Terraform plan FAILED"
                                    exit 1
                                fi
                                echo "Terraform plan detected changes (exit code: $PLAN_EXIT)"
                            }
                    '''
                }

                // Archive terraform plan as build artefact (audit trail)
                archiveArtifacts artifacts: 'terraform/tfplan', fingerprint: true

                // Step 3: Terraform apply
                echo '=== Running Terraform Apply ==='
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        cd terraform
                        terraform apply -auto-approve -input=false tfplan
                    '''
                }

                // Step 4: Generate dynamic Ansible inventory from Terraform output
                sh '''
                    cd terraform
                    terraform output -raw ansible_inventory > ../ansible/dynamic-inventory
                '''

                // Step 5: Ansible dry-run (idempotency validation)
                echo '=== Running Ansible Dry Run ==='
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        cd ansible
                        ansible-playbook \
                            --check \
                            --diff \
                            -i dynamic-inventory \
                            playbooks/site.yml
                    '''
                }

                // Step 6: Ansible live execution
                echo '=== Running Ansible Playbook ==='
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        cd ansible
                        ansible-playbook \
                            -i dynamic-inventory \
                            playbooks/site.yml
                    '''
                }
            }
        }

        // =====================================================================
        // STAGE 6: Blue-Green Deploy + Health Check
        // =====================================================================
        stage('Blue-Green Deploy + Health Check') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        chmod +x scripts/blue-green-deploy.sh
                        export IMAGE_REGISTRY=${IMAGE_REGISTRY}
                        export IMAGE_NAME=${IMAGE_NAME}
                        export NAMESPACE=${KUBE_NAMESPACE}
                        export SLACK_WEBHOOK_URL=\${SLACK_WEBHOOK_URL:-}
                        scripts/blue-green-deploy.sh ${BUILD_NUMBER}
                    """
                }
            }
        }
    }

    post {
        always {
            // Archive all reports
            archiveArtifacts artifacts: '**/trivy-report.json,**/hadolint-report.json,**/gitleaks-report.json,**/sast-report.json,**/tfsec-report.json,**/tfplan', allowEmptyArchive: true, fingerprint: true

            // Clean up Docker images to save disk space
            sh """
                docker rmi ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true
                docker rmi ${IMAGE_REGISTRY}/${IMAGE_NAME}:latest || true
            """

            // Clean workspace
            cleanWs()
        }

        failure {
            script {
                def failedStage = env.STAGE_NAME ?: 'Unknown'
                def failureMessage = """
                    :red_circle: *Pipeline FAILED*
                    *Job:* ${env.JOB_NAME}
                    *Build:* #${env.BUILD_NUMBER}
                    *Stage:* ${failedStage}
                    *Commit:* ${env.GIT_COMMIT_SHORT ?: 'unknown'}
                    *Author:* ${env.GIT_AUTHOR ?: 'unknown'}
                    *Console:* ${env.BUILD_URL}console
                """.stripIndent()

                // Slack notification
                withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK_URL')]) {
                    sh """
                        curl -s -X POST \${SLACK_WEBHOOK_URL} \
                            -H 'Content-Type: application/json' \
                            -d '{
                                "channel": "${SLACK_CHANNEL}",
                                "attachments": [{
                                    "color": "danger",
                                    "title": "Pipeline Failed — Build #${BUILD_NUMBER}",
                                    "text": "${failureMessage.replaceAll('\n', '\\\\n').replaceAll('"', '\\\\"')}",
                                    "footer": "Secure DevOps Platform"
                                }]
                            }' || true
                    """
                }

                // Email notification
                emailext(
                    subject: "FAILED: Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Pipeline Failed</h2>
                        <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                        <p><strong>Build:</strong> #${env.BUILD_NUMBER}</p>
                        <p><strong>Failed Stage:</strong> ${failedStage}</p>
                        <p><strong>Commit:</strong> ${env.GIT_COMMIT_SHORT ?: 'unknown'}</p>
                        <p><strong>Author:</strong> ${env.GIT_AUTHOR ?: 'unknown'}</p>
                        <p><a href="${env.BUILD_URL}console">View Console Output</a></p>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
            }
        }

        success {
            script {
                def successMessage = """
                    :white_check_mark: *Pipeline PASSED*
                    *Job:* ${env.JOB_NAME}
                    *Build:* #${env.BUILD_NUMBER}
                    *Commit:* ${env.GIT_COMMIT_SHORT ?: 'unknown'}
                    *Author:* ${env.GIT_AUTHOR ?: 'unknown'}
                    *Image:* ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                """.stripIndent()

                withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK_URL')]) {
                    sh """
                        curl -s -X POST \${SLACK_WEBHOOK_URL} \
                            -H 'Content-Type: application/json' \
                            -d '{
                                "channel": "${SLACK_CHANNEL}",
                                "attachments": [{
                                    "color": "good",
                                    "title": "Pipeline Passed — Build #${BUILD_NUMBER}",
                                    "text": "${successMessage.replaceAll('\n', '\\\\n').replaceAll('"', '\\\\"')}",
                                    "footer": "Secure DevOps Platform"
                                }]
                            }' || true
                    """
                }

                emailext(
                    subject: "SUCCESS: Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Pipeline Succeeded</h2>
                        <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                        <p><strong>Build:</strong> #${env.BUILD_NUMBER}</p>
                        <p><strong>Image:</strong> ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}</p>
                        <p><strong>Commit:</strong> ${env.GIT_COMMIT_SHORT ?: 'unknown'}</p>
                        <p><a href="${env.BUILD_URL}">View Build</a></p>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
            }
        }
    }
}
