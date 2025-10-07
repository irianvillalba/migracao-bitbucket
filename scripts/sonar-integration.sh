#!/bin/bash

# Script para integração com SonarQube no Bitbucket Pipelines
# Suporte para múltiplas linguagens

set -e

# Função para log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Configurar variáveis
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-$BITBUCKET_REPO_SLUG}"
SONAR_PROJECT_NAME="${SONAR_PROJECT_NAME:-$BITBUCKET_REPO_SLUG}"
SONAR_PROJECT_VERSION="${BITBUCKET_TAG:-$BITBUCKET_COMMIT}"
SONAR_BRANCH_NAME="${BITBUCKET_BRANCH}"

log "=== SONAR INTEGRATION STARTED ==="
log "Project Key: $SONAR_PROJECT_KEY"
log "Project Name: $SONAR_PROJECT_NAME"
log "Version: $SONAR_PROJECT_VERSION"
log "Branch: $SONAR_BRANCH_NAME"
log "SonarQube Host: $SONAR_HOST_URL"

# Detectar tipo de projeto
detect_project_type() {
    if [ -f "package.json" ]; then
        echo "nodejs"
    elif [ -f "composer.json" ]; then
        echo "php"
    elif [ -f "*.csproj" ] || [ -f "*.sln" ]; then
        echo "dotnet"
    elif [ -f "pom.xml" ]; then
        echo "java"
    elif [ -f "angular.json" ]; then
        echo "angular"
    elif [ -f "package.json" ] && grep -q "react" package.json; then
        echo "react"
    else
        echo "generic"
    fi
}

PROJECT_TYPE=$(detect_project_type)
log "Detected project type: $PROJECT_TYPE"

# Configurar parâmetros específicos por tipo de projeto
setup_sonar_params() {
    local common_params="-Dsonar.projectKey=$SONAR_PROJECT_KEY \
                        -Dsonar.projectName=$SONAR_PROJECT_NAME \
                        -Dsonar.projectVersion=$SONAR_PROJECT_VERSION \
                        -Dsonar.host.url=$SONAR_HOST_URL \
                        -Dsonar.login=$SONAR_TOKEN"
    
    case $PROJECT_TYPE in
        "nodejs"|"react")
            echo "$common_params \
                  -Dsonar.sources=src \
                  -Dsonar.exclusions=node_modules/**,build/**,dist/**,coverage/** \
                  -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                  -Dsonar.testExecutionReportPaths=test-results/jest-sonar.xml"
            ;;
        "angular")
            echo "$common_params \
                  -Dsonar.sources=src \
                  -Dsonar.exclusions=node_modules/**,dist/**,coverage/**,e2e/** \
                  -Dsonar.typescript.lcov.reportPaths=coverage/lcov.info \
                  -Dsonar.testExecutionReportPaths=test-results/jest-sonar.xml"
            ;;
        "php")
            echo "$common_params \
                  -Dsonar.sources=. \
                  -Dsonar.exclusions=vendor/**,tests/**,node_modules/** \
                  -Dsonar.php.coverage.reportPaths=coverage.xml \
                  -Dsonar.php.tests.reportPath=test-results/phpunit.xml"
            ;;
        "dotnet")
            echo "$common_params \
                  -Dsonar.cs.nunit.reportsPaths=TestResults/*.xml \
                  -Dsonar.cs.opencover.reportsPaths=TestResults/coverage.opencover.xml"
            ;;
        "java")
            echo "$common_params \
                  -Dsonar.sources=src/main/java \
                  -Dsonar.tests=src/test/java \
                  -Dsonar.java.binaries=target/classes \
                  -Dsonar.junit.reportPaths=target/surefire-reports"
            ;;
        *)
            echo "$common_params \
                  -Dsonar.sources=."
            ;;
    esac
}

# Executar análise SonarQube baseada no tipo de projeto
run_sonar_analysis() {
    local sonar_params=$(setup_sonar_params)
    
    case $PROJECT_TYPE in
        "dotnet")
            log "Executando análise SonarQube para .NET..."
            # Instalar SonarScanner para .NET
            dotnet tool install --global dotnet-sonarscanner || dotnet tool update --global dotnet-sonarscanner
            export PATH="$PATH:/root/.dotnet/tools"
            
            # Iniciar análise
            dotnet sonarscanner begin $sonar_params
            
            # Build do projeto
            dotnet build --configuration Release
            
            # Finalizar análise
            dotnet sonarscanner end -Dsonar.login=$SONAR_TOKEN
            ;;
        *)
            log "Executando análise SonarQube genérica..."
            # Usar SonarScanner CLI
            sonar-scanner $sonar_params
            ;;
    esac
}

# Verificar se SonarQube está configurado
if [ -z "$SONAR_HOST_URL" ] || [ -z "$SONAR_TOKEN" ]; then
    log "❌ SonarQube não configurado. Definir SONAR_HOST_URL e SONAR_TOKEN."
    exit 1
fi

# Executar análise
log "Iniciando análise SonarQube..."
run_sonar_analysis

# Aguardar resultado da análise (opcional)
if [ "$SONAR_WAIT_FOR_QUALITY_GATE" = "true" ]; then
    log "Aguardando resultado do Quality Gate..."
    
    # Aguardar um tempo para processamento
    sleep 30
    
    # Verificar status do Quality Gate via API
    TASK_URL=$(grep "ceTaskUrl" .scannerwork/report-task.txt | cut -d'=' -f2)
    if [ -n "$TASK_URL" ]; then
        TASK_ID=$(basename "$TASK_URL")
        
        # Polling para verificar status
        for i in {1..30}; do
            STATUS=$(curl -s -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/ce/task?id=$TASK_ID" | jq -r '.task.status')
            
            if [ "$STATUS" = "SUCCESS" ]; then
                # Verificar Quality Gate
                ANALYSIS_ID=$(curl -s -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/ce/task?id=$TASK_ID" | jq -r '.task.analysisId')
                QG_STATUS=$(curl -s -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/qualitygates/project_status?analysisId=$ANALYSIS_ID" | jq -r '.projectStatus.status')
                
                if [ "$QG_STATUS" = "OK" ]; then
                    log "✅ Quality Gate PASSOU!"
                    break
                else
                    log "❌ Quality Gate FALHOU!"
                    exit 1
                fi
            elif [ "$STATUS" = "FAILED" ]; then
                log "❌ Análise SonarQube falhou!"
                exit 1
            fi
            
            log "Aguardando análise... ($i/30)"
            sleep 10
        done
    fi
fi

log "=== SONAR INTEGRATION COMPLETED ==="