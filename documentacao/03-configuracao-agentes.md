# Configuração de Self-hosted Runners - Bitbucket Cloud

## Visão Geral

Os self-hosted runners permitem executar pipelines do Bitbucket Cloud em infraestrutura própria, mantendo controle total sobre o ambiente de execução e acesso a recursos internos.

## Arquitetura dos Runners

### Comunicação
```
┌─────────────────────┐    HTTPS (443)    ┌─────────────────────┐
│  Bitbucket Cloud    │◄─────────────────►│ Self-hosted Runner  │
│                     │   (Outbound only)  │   (On-premise)      │
│ • Pipeline triggers │                    │ • Executa jobs      │
│ • Job definitions   │                    │ • Reporta status    │
│ • Artifact storage  │                    │ • Upload artifacts  │
└─────────────────────┘                    └─────────────────────┘
                                                      │
                                                      ▼
                                           ┌─────────────────────┐
                                           │ Infraestrutura      │
                                           │ On-premise          │
                                           │                     │
                                           │ • SonarQube         │
                                           │ • Harbor Registry   │
                                           │ • Bancos de dados   │
                                           │ • Servidores app    │
                                           └─────────────────────┘
```

## Tipos de Runners Recomendados

### 1. Windows Runners
**Uso**: Aplicações .NET, Windows Services
```
Especificações mínimas:
- CPU: 4 cores
- RAM: 8 GB
- Disco: 100 GB SSD
- OS: Windows Server 2019/2022

Ferramentas instaladas:
- .NET SDK 6.0+
- MSBuild
- Git
- Docker Desktop
- Node.js 16+
- Visual Studio Build Tools
```

### 2. Linux Runners
**Uso**: Docker, PHP, Node.js, aplicações web
```
Especificações mínimas:
- CPU: 4 cores
- RAM: 8 GB
- Disco: 100 GB SSD
- OS: Ubuntu 20.04 LTS

Ferramentas instaladas:
- Docker
- Git
- Node.js 16+
- PHP 7.3+ e 8.0+
- Composer
- Python 3.8+
- .NET SDK (opcional)
```

### 3. Runners Especializados
**Uso**: Tarefas específicas (banco de dados, security scans)
```
Database Runner:
- PostgreSQL client
- MySQL client
- Scripts de migração
- Backup tools

Security Runner:
- SonarQube Scanner
- OWASP Dependency Check
- Trivy (container scanning)
- SAST/DAST tools
```

## Configuração Passo a Passo

### 1. Pré-requisitos

#### No Bitbucket Cloud:
1. **Criar OAuth Consumer**:
   - Acesse: `https://bitbucket.org/{workspace}/workspace/settings/api`
   - Clique em "Add consumer"
   - Nome: "Pipeline Runner"
   - Permissions: `Pipelines:Write`, `Repositories:Admin`
   - Salve `Client ID` e `Client Secret`

#### No Servidor:
1. **Recursos mínimos**: 4 CPU, 8GB RAM, 100GB disco
2. **Conectividade**: HTTPS outbound para `*.atlassian.com`
3. **Permissões**: Usuário com acesso a Docker (Linux) ou Administrador (Windows)

### 2. Instalação Automatizada

#### Linux (Ubuntu/Debian):
```bash
# Download do script de setup
curl -o setup-runner.sh https://raw.githubusercontent.com/.../setup-runner.sh
chmod +x setup-runner.sh

# Configurar variáveis
export WORKSPACE_NAME="seu-workspace"
export OAUTH_CLIENT_ID="seu-client-id"
export OAUTH_CLIENT_SECRET="seu-client-secret"
export RUNNER_NAME="$(hostname)-linux"

# Executar instalação
sudo ./setup-runner.sh
```

#### Windows (PowerShell como Administrador):
```powershell
# Download do script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/.../setup-runner.ps1" -OutFile "setup-runner.ps1"

# Configurar variáveis
$env:WORKSPACE_NAME="seu-workspace"
$env:OAUTH_CLIENT_ID="seu-client-id"
$env:OAUTH_CLIENT_SECRET="seu-client-secret"
$env:RUNNER_NAME="$env:COMPUTERNAME-windows"

# Executar instalação
.\setup-runner.ps1
```

### 3. Configuração Manual

#### Passo 1: Download do Runner
```bash
# Linux
wget https://product-downloads.atlassian.com/software/bitbucket/pipelines/atlassian-bitbucket-pipelines-runner_1.478_linux_x86_64.tar.gz
tar -xzf atlassian-bitbucket-pipelines-runner_1.478_linux_x86_64.tar.gz

# Windows
# Download do executável Windows do site oficial
```

#### Passo 2: Configurar Runner
```bash
# Obter UUIDs necessários
WORKSPACE_UUID=$(curl -s -u "$OAUTH_CLIENT_ID:$OAUTH_CLIENT_SECRET" \
  "https://api.bitbucket.org/2.0/workspaces/$WORKSPACE_NAME" | jq -r '.uuid')

# Registrar runner
./atlassian-bitbucket-pipelines-runner \
  --accountUuid "$WORKSPACE_UUID" \
  --OAuthClientId "$OAUTH_CLIENT_ID" \
  --OAuthClientSecret "$OAUTH_CLIENT_SECRET" \
  --workingDirectory "/opt/runner/work"
```

### 4. Configuração como Serviço

#### Linux (systemd):
```ini
# /etc/systemd/system/bitbucket-runner.service
[Unit]
Description=Bitbucket Pipelines Runner
After=network.target

[Service]
Type=simple
User=bbrunner
WorkingDirectory=/opt/atlassian-bitbucket-pipelines-runner
ExecStart=/opt/atlassian-bitbucket-pipelines-runner/atlassian-bitbucket-pipelines-runner
Restart=always
RestartSec=10
Environment=RUNNER_WORK_DIR=/opt/runner/work

[Install]
WantedBy=multi-user.target
```

```bash
# Habilitar e iniciar
sudo systemctl enable bitbucket-runner
sudo systemctl start bitbucket-runner
sudo systemctl status bitbucket-runner
```

#### Windows (Serviço):
```cmd
# Registrar como serviço
sc create "BitbucketRunner" binPath= "C:\BitbucketRunner\atlassian-bitbucket-pipelines-runner.exe" start= auto

# Iniciar serviço
sc start "BitbucketRunner"

# Verificar status
sc query "BitbucketRunner"
```

## Configuração de Rede e Segurança

### Conectividade Necessária
```
Outbound HTTPS (443):
- api.bitbucket.org
- bitbucket.org
- *.atlassian.com
- docker.io (para pulls de imagens)
- github.com (para downloads)

Interno (conforme necessário):
- SonarQube server
- Harbor registry
- Database servers
- Application servers
```

### Firewall Rules
```bash
# Linux (iptables)
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

# Windows (netsh)
netsh advfirewall firewall add rule name="Bitbucket Runner HTTPS" dir=out action=allow protocol=TCP localport=443
```

## Gerenciamento de Runners

### Monitoramento
```bash
# Verificar status do runner
systemctl status bitbucket-runner

# Ver logs em tempo real
journalctl -u bitbucket-runner -f

# Verificar uso de recursos
htop
df -h
```

### Manutenção
```bash
# Reiniciar runner
sudo systemctl restart bitbucket-runner

# Atualizar runner
# 1. Parar serviço
sudo systemctl stop bitbucket-runner

# 2. Backup de configuração
cp -r /opt/atlassian-bitbucket-pipelines-runner /opt/backup/

# 3. Download nova versão
wget https://product-downloads.atlassian.com/software/bitbucket/pipelines/atlassian-bitbucket-pipelines-runner_1.XXX_linux_x86_64.tar.gz

# 4. Atualizar e reiniciar
tar -xzf atlassian-bitbucket-pipelines-runner_1.XXX_linux_x86_64.tar.gz
sudo systemctl start bitbucket-runner
```

## Configuração de Multiple Runners

### Estratégia por Tipo de Workload
```yaml
# Pipeline com seleção de runner
pipelines:
  branches:
    master:
      - step:
          name: Build .NET
          runs-on: 
            - 'self.hosted'
            - 'windows'
            - 'msbuild'
          script:
            - dotnet build
      
      - step:
          name: Docker Build
          runs-on:
            - 'self.hosted' 
            - 'linux'
            - 'docker'
          script:
            - docker build .
```

### Labels de Runners
```bash
# Configurar labels durante setup
./atlassian-bitbucket-pipelines-runner \
  --labels "windows,msbuild,dotnet" \
  --name "windows-runner-01"

./atlassian-bitbucket-pipelines-runner \
  --labels "linux,docker,nodejs" \
  --name "linux-runner-01"
```

## Troubleshooting

### Problemas Comuns

#### 1. Runner não conecta
```bash
# Verificar conectividade
curl -I https://api.bitbucket.org
curl -I https://bitbucket.org

# Verificar credenciais OAuth
curl -u "$CLIENT_ID:$CLIENT_SECRET" \
  https://api.bitbucket.org/2.0/workspaces/$WORKSPACE
```

#### 2. Jobs ficam pendentes
```bash
# Verificar se runner está ativo
curl -u "$CLIENT_ID:$CLIENT_SECRET" \
  https://api.bitbucket.org/2.0/workspaces/$WORKSPACE/runners

# Verificar logs do runner
journalctl -u bitbucket-runner -n 100
```

#### 3. Problemas de performance
```bash
# Monitorar recursos
top
iostat 1
df -h

# Limpar workspace antigo
find /opt/runner/work -type d -mtime +7 -exec rm -rf {} \;
```

### Logs e Debugging
```bash
# Habilitar debug logging
export RUNNER_DEBUG=true

# Logs detalhados
journalctl -u bitbucket-runner -f --output=short-iso

# Verificar arquivos de configuração
ls -la /opt/atlassian-bitbucket-pipelines-runner/
cat /opt/atlassian-bitbucket-pipelines-runner/runner.cfg
```

## Backup e Disaster Recovery

### Backup de Configuração
```bash
# Backup completo
tar -czf bitbucket-runner-backup-$(date +%Y%m%d).tar.gz \
  /opt/atlassian-bitbucket-pipelines-runner \
  /etc/systemd/system/bitbucket-runner.service

# Backup apenas configuração
cp /opt/atlassian-bitbucket-pipelines-runner/runner.cfg \
   /backup/runner-config-$(date +%Y%m%d).cfg
```

### Restore
```bash
# Restaurar configuração
sudo systemctl stop bitbucket-runner
tar -xzf bitbucket-runner-backup-20241006.tar.gz -C /
sudo systemctl start bitbucket-runner
```

## Próximos Passos

1. **Configurar primeiro runner** seguindo o guia passo a passo
2. **Testar com pipeline simples** para validar conectividade
3. **Implementar runners especializados** conforme necessário
4. **Configurar monitoramento** e alertas
5. **Documentar procedimentos** específicos da organização