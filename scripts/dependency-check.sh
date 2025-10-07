#!/bin/bash

# Script para OWASP Dependency Check no Bitbucket Pipelines
# Verifica vulnerabilidades conhecidas em dependências

set -e

# Função para log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Configurar variáveis
PROJECT_NAME="${BITBUCKET_REPO_SLUG}"
DEPENDENCY_CHECK_VERSION="${DEPENDENCY_CHECK_VERSION:-8.4.0}"
REPORT_DIR="dependency-check-report"
NVD_API_KEY="${NVD_API_KEY:-}"
FAIL_ON_CVSS="${FAIL_ON_CVSS:-7}"

log "=== DEPENDENCY CHECK STARTED ==="
log "Project: $PROJECT_NAME"
log "Version: $DEPENDENCY_CHECK_VERSION"
log "Fail on CVSS: $FAIL_ON_CVSS"

# Instalar dependências do sistema
install_dependencies() {
    log "Instalando dependências do sistema..."
    apt-get update && apt-get install -y wget unzip default-jre curl
}

# Download e setup do OWASP Dependency Check
setup_dependency_check() {
    if [ ! -d "dependency-check" ]; then
        log "Baixando OWASP Dependency Check v$DEPENDENCY_CHECK_VERSION..."
        wget -q "https://github.com/jeremylong/DependencyCheck/releases/download/v$DEPENDENCY_CHECK_VERSION/dependency-check-$DEPENDENCY_CHECK_VERSION-release.zip"
        unzip -q "dependency-check-$DEPENDENCY_CHECK_VERSION-release.zip"
        chmod +x dependency-check/bin/dependency-check.sh
    fi
}

# Detectar tipo de projeto para configurar scan adequado
detect_project_type() {
    if [ -f "package.json" ]; then
        echo "nodejs"
    elif [ -f "composer.json" ]; then
        echo "php"
    elif [ -f "*.csproj" ] || [ -f "*.sln" ]; then
        echo "dotnet"
    elif [ -f "pom.xml" ]; then
        echo "java"
    elif [ -f "requirements.txt" ] || [ -f "Pipfile" ] || [ -f "pyproject.toml" ]; then
        echo "python"
    else
        echo "generic"
    fi
}

# Executar análise específica por linguagem
run_language_specific_checks() {
    local project_type=$(detect_project_type)
    log "Tipo de projeto detectado: $project_type"
    
    case $project_type in
        "nodejs")
            log "Executando npm audit..."
            if [ -f "package.json" ]; then
                npm audit --audit-level moderate --json > npm-audit.json || log "NPM audit completado com avisos"
                
                # Converter resultado para formato legível
                if [ -f "npm-audit.json" ]; then
                    npm audit --audit-level moderate || echo "NPM audit encontrou vulnerabilidades"
                fi
            fi
            ;;
        "php")
            log "Verificando dependências PHP..."
            if [ -f "composer.lock" ]; then
                # Security Checker para Composer (se disponível)
                if command -v local-php-security-checker >/dev/null 2>&1; then
                    local-php-security-checker || log "PHP security check completado com avisos"
                fi
            fi
            ;;
        "python")
            log "Executando safety check para Python..."
            if command -v safety >/dev/null 2>&1; then
                safety check --json > safety-report.json || log "Safety check completado com avisos"
            fi
            ;;
        "java")
            log "Projeto Java detectado - dependências serão verificadas pelo OWASP Dependency Check"
            ;;
        "dotnet")
            log "Projeto .NET detectado - dependências serão verificadas pelo OWASP Dependency Check"
            ;;
    esac
}

# Configurar argumentos do Dependency Check
setup_dependency_check_args() {
    local args="--project '$PROJECT_NAME' \
               --scan . \
               --format XML \
               --format HTML \
               --format JSON \
               --out $REPORT_DIR \
               --failOnCVSS $FAIL_ON_CVSS"
    
    # Adicionar chave NVD se disponível
    if [ -n "$NVD_API_KEY" ]; then
        args="$args --nvdApiKey $NVD_API_KEY"
    fi
    
    # Exclusões comuns
    args="$args --exclude '**/node_modules/**' \
                --exclude '**/vendor/**' \
                --exclude '**/target/**' \
                --exclude '**/bin/**' \
                --exclude '**/obj/**' \
                --exclude '**/.git/**'"
    
    echo "$args"
}

# Executar OWASP Dependency Check
run_dependency_check() {
    local args=$(setup_dependency_check_args)
    log "Executando OWASP Dependency Check..."
    
    # Criar diretório de relatórios
    mkdir -p "$REPORT_DIR"
    
    # Executar dependency check
    eval "./dependency-check/bin/dependency-check.sh $args" || {
        log "❌ Dependency Check falhou ou encontrou vulnerabilidades críticas"
        return 1
    }
}

# Processar e analisar resultados
process_results() {
    log "Processando resultados..."
    
    if [ -f "$REPORT_DIR/dependency-check-report.json" ]; then
        # Extrair estatísticas do relatório JSON
        TOTAL_DEPS=$(jq '.dependencies | length' "$REPORT_DIR/dependency-check-report.json")
        VULNS=$(jq '[.dependencies[].vulnerabilities // []] | flatten | length' "$REPORT_DIR/dependency-check-report.json")
        
        log "Dependências analisadas: $TOTAL_DEPS"
        log "Vulnerabilidades encontradas: $VULNS"
        
        if [ "$VULNS" -gt 0 ]; then
            log "⚠️  Vulnerabilidades encontradas!"
            
            # Mostrar resumo das vulnerabilidades críticas
            jq -r '.dependencies[].vulnerabilities[]? | select(.cvssv3?.baseScore >= 7) | "CRÍTICA: \(.name) - CVSS: \(.cvssv3.baseScore) - \(.description)"' "$REPORT_DIR/dependency-check-report.json" | head -10
        else
            log "✅ Nenhuma vulnerabilidade encontrada!"
        fi
    fi
    
    # Mostrar localização dos relatórios
    log "Relatórios gerados em: $REPORT_DIR/"
    ls -la "$REPORT_DIR/"
}

# Enviar resultados para ferramentas de análise (opcional)
send_to_sonar() {
    if [ -n "$SONAR_HOST_URL" ] && [ -n "$SONAR_TOKEN" ] && [ -f "$REPORT_DIR/dependency-check-report.xml" ]; then
        log "Enviando resultados para SonarQube..."
        
        # O SonarQube pode importar relatórios do Dependency Check
        # Configurar no sonar-project.properties:
        # sonar.dependencyCheck.reportPath=dependency-check-report/dependency-check-report.xml
    fi
}

# Função principal
main() {
    install_dependencies
    setup_dependency_check
    run_language_specific_checks
    
    if run_dependency_check; then
        log "✅ Dependency Check executado com sucesso"
        process_results
        send_to_sonar
    else
        log "❌ Dependency Check falhou"
        process_results
        exit 1
    fi
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

log "=== DEPENDENCY CHECK COMPLETED ==="