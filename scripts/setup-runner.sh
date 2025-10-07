#!/bin/bash

# Script para configuração de Self-hosted Runner do Bitbucket
# Suporte para Windows e Linux

set -e

# Função para log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Detectar sistema operacional
detect_os() {
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OS" == "Windows_NT" ]]; then
        echo "windows"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Configurar variáveis
OS_TYPE=$(detect_os)
RUNNER_DIR="${RUNNER_DIR:-/opt/atlassian-bitbucket-pipelines-runner}"
RUNNER_USER="${RUNNER_USER:-bbrunner}"
WORKSPACE_NAME="${WORKSPACE_NAME}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
OAUTH_CLIENT_ID="${OAUTH_CLIENT_ID}"
OAUTH_CLIENT_SECRET="${OAUTH_CLIENT_SECRET}"

log "=== BITBUCKET RUNNER SETUP STARTED ==="
log "OS Type: $OS_TYPE"
log "Runner Directory: $RUNNER_DIR"
log "Runner Name: $RUNNER_NAME"
log "Workspace: $WORKSPACE_NAME"

# Verificar variáveis obrigatórias
check_required_vars() {
    if [ -z "$WORKSPACE_NAME" ]; then
        log "❌ WORKSPACE_NAME é obrigatório"
        exit 1
    fi
    
    if [ -z "$OAUTH_CLIENT_ID" ] || [ -z "$OAUTH_CLIENT_SECRET" ]; then
        log "❌ OAUTH_CLIENT_ID e OAUTH_CLIENT_SECRET são obrigatórios"
        log "Configure em: https://bitbucket.org/$WORKSPACE_NAME/workspace/settings/api"
        exit 1
    fi
}

# Instalar dependências no Linux
install_linux_dependencies() {
    log "Instalando dependências para Linux..."
    
    # Atualizar sistema
    apt-get update
    
    # Dependências básicas
    apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        docker.io \
        python3 \
        python3-pip \
        nodejs \
        npm \
        default-jre \
        build-essential
    
    # Adicionar usuário para runner
    if ! id "$RUNNER_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$RUNNER_USER"
        usermod -aG docker "$RUNNER_USER"
    fi
    
    # .NET SDK
    wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    apt-get update
    apt-get install -y dotnet-sdk-6.0
    
    # PHP
    apt-get install -y php php-cli php-mbstring php-xml composer
    
    log "✅ Dependências Linux instaladas"
}

# Instalar dependências no Windows
install_windows_dependencies() {
    log "Configurando dependências para Windows..."
    
    # Verificar se Chocolatey está instalado
    if ! command -v choco &> /dev/null; then
        log "Instalando Chocolatey..."
        powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    fi
    
    # Instalar ferramentas
    choco install -y git
    choco install -y nodejs
    choco install -y python3
    choco install -y dotnet-sdk
    choco install -y php
    choco install -y composer
    choco install -y docker-desktop
    
    log "✅ Dependências Windows instaladas"
}

# Download e setup do runner
setup_runner() {
    log "Configurando Bitbucket Runner..."
    
    # Criar diretório do runner
    mkdir -p "$RUNNER_DIR"
    cd "$RUNNER_DIR"
    
    # Download do runner baseado no OS
    case $OS_TYPE in
        "linux")
            RUNNER_URL="https://product-downloads.atlassian.com/software/bitbucket/pipelines/atlassian-bitbucket-pipelines-runner_1.478_linux_x86_64.tar.gz"
            wget "$RUNNER_URL" -O runner.tar.gz
            tar -xzf runner.tar.gz
            chmod +x atlassian-bitbucket-pipelines-runner
            ;;
        "windows")
            RUNNER_URL="https://product-downloads.atlassian.com/software/bitbucket/pipelines/atlassian-bitbucket-pipelines-runner_1.478_windows_x86_64.zip"
            curl -L "$RUNNER_URL" -o runner.zip
            unzip runner.zip
            ;;
        *)
            log "❌ OS não suportado: $OS_TYPE"
            exit 1
            ;;
    esac
    
    log "✅ Runner baixado e configurado"
}

# Configurar runner
configure_runner() {
    log "Configurando runner com workspace..."
    
    cd "$RUNNER_DIR"
    
    # Configurar runner
    case $OS_TYPE in
        "linux")
            ./atlassian-bitbucket-pipelines-runner \
                --accountUuid "{workspace-uuid}" \
                --repositoryUuid "{repository-uuid}" \
                --runnerUuid "{runner-uuid}" \
                --OAuthClientId "$OAUTH_CLIENT_ID" \
                --OAuthClientSecret "$OAUTH_CLIENT_SECRET" \
                --workingDirectory "$RUNNER_DIR/work"
            ;;
        "windows")
            ./atlassian-bitbucket-pipelines-runner.exe \
                --accountUuid "{workspace-uuid}" \
                --repositoryUuid "{repository-uuid}" \
                --runnerUuid "{runner-uuid}" \
                --OAuthClientId "$OAUTH_CLIENT_ID" \
                --OAuthClientSecret "$OAUTH_CLIENT_SECRET" \
                --workingDirectory "$RUNNER_DIR/work"
            ;;
    esac
}

# Criar serviço systemd (Linux)
create_systemd_service() {
    if [ "$OS_TYPE" != "linux" ]; then
        return 0
    fi
    
    log "Criando serviço systemd..."
    
    cat > /etc/systemd/system/bitbucket-runner.service << EOF
[Unit]
Description=Bitbucket Pipelines Runner
After=network.target

[Service]
Type=simple
User=$RUNNER_USER
WorkingDirectory=$RUNNER_DIR
ExecStart=$RUNNER_DIR/atlassian-bitbucket-pipelines-runner
Restart=always
RestartSec=10
Environment=RUNNER_WORK_DIR=$RUNNER_DIR/work

[Install]
WantedBy=multi-user.target
EOF
    
    # Habilitar e iniciar serviço
    systemctl daemon-reload
    systemctl enable bitbucket-runner
    systemctl start bitbucket-runner
    
    log "✅ Serviço systemd criado e iniciado"
}

# Configurar como serviço Windows
create_windows_service() {
    if [ "$OS_TYPE" != "windows" ]; then
        return 0
    fi
    
    log "Configurando serviço Windows..."
    
    # Usar sc.exe para criar serviço
    sc.exe create "BitbucketRunner" \
        binPath= "$RUNNER_DIR\atlassian-bitbucket-pipelines-runner.exe" \
        start= auto \
        DisplayName= "Bitbucket Pipelines Runner"
    
    # Iniciar serviço
    sc.exe start "BitbucketRunner"
    
    log "✅ Serviço Windows criado e iniciado"
}

# Verificar status do runner
check_runner_status() {
    log "Verificando status do runner..."
    
    case $OS_TYPE in
        "linux")
            systemctl status bitbucket-runner || log "Serviço não está rodando"
            ;;
        "windows")
            sc.exe query "BitbucketRunner" || log "Serviço não está rodando"
            ;;
    esac
}

# Configurar firewall (se necessário)
configure_firewall() {
    log "Configurando firewall..."
    
    case $OS_TYPE in
        "linux")
            # Permitir conexões HTTPS de saída
            if command -v ufw &> /dev/null; then
                ufw allow out 443/tcp
            fi
            ;;
        "windows")
            # Configurar Windows Firewall se necessário
            netsh advfirewall firewall add rule name="Bitbucket Runner HTTPS" dir=out action=allow protocol=TCP localport=443
            ;;
    esac
}

# Mostrar instruções finais
show_final_instructions() {
    log "=== CONFIGURAÇÃO CONCLUÍDA ==="
    log ""
    log "Próximos passos:"
    log "1. Acesse: https://bitbucket.org/$WORKSPACE_NAME/workspace/settings/runners"
    log "2. Clique em 'Add runner'"
    log "3. Copie os UUIDs e configure no runner"
    log "4. Teste com um pipeline simples"
    log ""
    log "Comandos úteis:"
    
    case $OS_TYPE in
        "linux")
            log "- Ver logs: journalctl -u bitbucket-runner -f"
            log "- Parar serviço: systemctl stop bitbucket-runner"
            log "- Iniciar serviço: systemctl start bitbucket-runner"
            log "- Reiniciar serviço: systemctl restart bitbucket-runner"
            ;;
        "windows")
            log "- Ver serviços: services.msc"
            log "- Parar serviço: sc.exe stop BitbucketRunner"
            log "- Iniciar serviço: sc.exe start BitbucketRunner"
            ;;
    esac
    
    log ""
    log "Diretório do runner: $RUNNER_DIR"
    log "Workspace: $WORKSPACE_NAME"
}

# Função principal
main() {
    check_required_vars
    
    case $OS_TYPE in
        "linux")
            install_linux_dependencies
            setup_runner
            create_systemd_service
            ;;
        "windows")
            install_windows_dependencies
            setup_runner
            create_windows_service
            ;;
        *)
            log "❌ Sistema operacional não suportado: $OS_TYPE"
            exit 1
            ;;
    esac
    
    configure_firewall
    check_runner_status
    show_final_instructions
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi