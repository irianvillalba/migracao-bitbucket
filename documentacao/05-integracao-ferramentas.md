# Integração com Ferramentas Externas

## Visão Geral

A migração para Bitbucket Cloud Pipelines mantém todas as integrações existentes com ferramentas de qualidade, segurança e artefatos, adaptando-as para o novo ambiente.

## SonarQube - Análise de Qualidade de Código

### Configuração Atual vs Nova

#### Bamboo (Atual)
```
Bamboo Agent → SonarQube Scanner → SonarQube Server
```

#### Bitbucket Cloud (Novo)
```
Self-hosted Runner → SonarQube Scanner → SonarQube Server (on-premise)
```

### Configuração no Bitbucket Cloud

#### 1. Variáveis de Repository
```yaml
# No Bitbucket Cloud: Repository Settings > Pipelines > Repository variables
SONAR_HOST_URL: "https://sonar.itamaraty.local"
SONAR_TOKEN: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" # Secured
SONAR_PROJECT_KEY: "$BITBUCKET_REPO_SLUG"
```

#### 2. Template de Pipeline
```yaml
# Exemplo para .NET
- step: &sonar-scan
    name: SonarQube Analysis
    runs-on: self.hosted
    script:
      # Instalar SonarScanner
      - dotnet tool install --global dotnet-sonarscanner
      - export PATH="$PATH:/root/.dotnet/tools"
      
      # Executar análise
      - dotnet sonarscanner begin /k:"$SONAR_PROJECT_KEY" /d:sonar.host.url="$SONAR_HOST_URL" /d:sonar.login="$SONAR_TOKEN"
      - dotnet build --configuration Release
      - dotnet sonarscanner end /d:sonar.login="$SONAR_TOKEN"
```

#### 3. Configuração por Tecnologia

##### JavaScript/TypeScript (React/Angular/Node.js)
```yaml
- step: &sonar-scan-js
    name: SonarQube Analysis - JavaScript
    image: sonarsource/sonar-scanner-cli:latest
    runs-on: self.hosted
    script:
      - sonar-scanner \
          -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
          -Dsonar.sources=src \
          -Dsonar.exclusions=node_modules/**,build/**,dist/** \
          -Dsonar.host.url="$SONAR_HOST_URL" \
          -Dsonar.login="$SONAR_TOKEN" \
          -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
```

##### PHP
```yaml
- step: &sonar-scan-php
    name: SonarQube Analysis - PHP
    image: sonarsource/sonar-scanner-cli:latest
    runs-on: self.hosted
    script:
      - sonar-scanner \
          -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
          -Dsonar.sources=. \
          -Dsonar.exclusions=vendor/**,tests/** \
          -Dsonar.host.url="$SONAR_HOST_URL" \
          -Dsonar.login="$SONAR_TOKEN" \
          -Dsonar.php.coverage.reportPaths=coverage.xml
```

### Quality Gates Integration
```yaml
- step: &sonar-quality-gate
    name: SonarQube Quality Gate
    runs-on: self.hosted
    script:
      # Aguardar processamento
      - sleep 30
      
      # Verificar Quality Gate
      - |
        STATUS=$(curl -s -u "$SONAR_TOKEN:" \
          "$SONAR_HOST_URL/api/qualitygates/project_status?projectKey=$SONAR_PROJECT_KEY" \
          | jq -r '.projectStatus.status')
        
        if [ "$STATUS" != "OK" ]; then
          echo "❌ Quality Gate failed: $STATUS"
          exit 1
        fi
        echo "✅ Quality Gate passed"
```

## Harbor Registry - Artefatos Docker/Node.js

### Configuração de Integração

#### 1. Variáveis de Registry
```yaml
# Repository variables (secured)
HARBOR_REGISTRY: "harbor.itamaraty.local"
HARBOR_PROJECT: "mre"
HARBOR_USERNAME: "bitbucket-pipelines"
HARBOR_PASSWORD: "xxxxxxxxxxxxxxxx" # Secured
```

#### 2. Docker Images
```yaml
- step: &push-harbor-docker
    name: Push Docker Image to Harbor
    runs-on: self.hosted
    services:
      - docker
    script:
      # Login no Harbor
      - echo $HARBOR_PASSWORD | docker login $HARBOR_REGISTRY -u $HARBOR_USERNAME --password-stdin
      
      # Build e tag da imagem
      - export IMAGE_NAME="$HARBOR_REGISTRY/$HARBOR_PROJECT/$BITBUCKET_REPO_SLUG"
      - export IMAGE_TAG="${BITBUCKET_TAG:-${BITBUCKET_COMMIT:0:7}}"
      - docker build -t $IMAGE_NAME:$IMAGE_TAG .
      - docker tag $IMAGE_NAME:$IMAGE_TAG $IMAGE_NAME:latest
      
      # Push para Harbor
      - docker push $IMAGE_NAME:$IMAGE_TAG
      - docker push $IMAGE_NAME:latest
      
      # Scan de segurança (opcional)
      - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
          aquasec/trivy:latest image --exit-code 0 --severity HIGH,CRITICAL \
          $IMAGE_NAME:$IMAGE_TAG
```

#### 3. Node.js Packages
```yaml
- step: &publish-harbor-nodejs
    name: Publish Node.js Package to Harbor
    runs-on: self.hosted
    script:
      # Criar tarball do package
      - npm pack
      - export PACKAGE_FILE=$(ls *.tgz)
      - export PACKAGE_VERSION="${BITBUCKET_TAG:-${BITBUCKET_COMMIT:0:7}}"
      
      # Upload para Harbor usando API
      - curl -X POST \
          -H "Authorization: Basic $(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)" \
          -F "file=@$PACKAGE_FILE" \
          "$HARBOR_REGISTRY/api/v2.0/projects/$HARBOR_PROJECT/repositories/$BITBUCKET_REPO_SLUG/artifacts"
```

### Automatização de Cleanup
```yaml
- step: &harbor-cleanup
    name: Harbor Registry Cleanup
    runs-on: self.hosted
    trigger: manual
    script:
      # Manter apenas últimas 10 versões
      - |
        REPO_URL="$HARBOR_REGISTRY/api/v2.0/projects/$HARBOR_PROJECT/repositories/$BITBUCKET_REPO_SLUG/artifacts"
        
        # Obter lista de artefatos
        ARTIFACTS=$(curl -s -u "$HARBOR_USERNAME:$HARBOR_PASSWORD" "$REPO_URL?page_size=100" | jq -r '.[] | select(.tags != null) | .digest')
        
        # Manter apenas os 10 mais recentes
        echo "$ARTIFACTS" | tail -n +11 | while read digest; do
          curl -X DELETE -u "$HARBOR_USERNAME:$HARBOR_PASSWORD" "$REPO_URL/$digest"
        done
```

## Satis Composer - Packages PHP

### Configuração do Satis

#### 1. Variáveis do Satis
```yaml
# Repository variables
SATIS_REGISTRY_URL: "https://satis.itamaraty.local"
SATIS_UPLOAD_URL: "https://satis.itamaraty.local/api/upload"
SATIS_BUILD_URL: "https://satis.itamaraty.local/api/build"
SATIS_TOKEN: "xxxxxxxxxxxxxxxx" # Secured
```

#### 2. Publicação Automática
```yaml
- step: &publish-satis
    name: Publish PHP Package to Satis
    runs-on: self.hosted
    script:
      # Verificar se é um pacote Composer válido
      - |
        if [ ! -f "composer.json" ]; then
          echo "❌ composer.json não encontrado. Pulando publicação no Satis."
          exit 0
        fi
      
      # Extrair informações do package
      - export PACKAGE_NAME=$(php -r "echo json_decode(file_get_contents('composer.json'))->name;")
      - export PACKAGE_VERSION="${BITBUCKET_TAG:-dev-${BITBUCKET_COMMIT:0:7}}"
      
      # Criar ZIP do pacote
      - export ZIP_NAME="${PACKAGE_NAME}-${PACKAGE_VERSION}.zip"
      - zip -r $ZIP_NAME . -x "*.git*" "tests/*" "*.zip" "node_modules/*"
      
      # Upload para Satis
      - |
        UPLOAD_RESPONSE=$(curl -s -X POST \
          -F "package=@${ZIP_NAME}" \
          -H "Authorization: Bearer $SATIS_TOKEN" \
          "$SATIS_UPLOAD_URL")
        
        if [ $? -eq 0 ]; then
          echo "✅ Package uploaded to Satis: $PACKAGE_NAME:$PACKAGE_VERSION"
          
          # Regenerar repositório Satis
          curl -X POST \
            -H "Authorization: Bearer $SATIS_TOKEN" \
            "$SATIS_BUILD_URL"
          
          echo "✅ Satis repository regenerated"
        else
          echo "❌ Failed to upload package to Satis"
          exit 1
        fi
```

#### 3. Validação de Dependências
```yaml
- step: &validate-composer
    name: Validate Composer Dependencies
    runs-on: self.hosted
    script:
      # Validar composer.json
      - composer validate --strict
      
      # Verificar se todas as dependências estão disponíveis
      - composer install --dry-run
      
      # Security check (se disponível)
      - composer audit || echo "Composer audit completed with warnings"
```

## OWASP Dependency Check - Segurança

### Configuração Universal

#### 1. Variáveis de Configuração
```yaml
# Repository variables
NVD_API_KEY: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # Opcional, melhora performance
DEPENDENCY_CHECK_VERSION: "8.4.0"
FAIL_ON_CVSS: "7" # Falhar se CVSS >= 7
```

#### 2. Script Integrado
```yaml
- step: &dependency-check
    name: OWASP Dependency Check
    runs-on: self.hosted
    script:
      # Usar script customizado
      - chmod +x ./scripts/dependency-check.sh
      - ./scripts/dependency-check.sh
    artifacts:
      - dependency-check-report/**
```

#### 3. Integração com SonarQube
```yaml
# Enviar resultados para SonarQube
- step: &dependency-check-sonar
    name: Send Dependency Check to SonarQube
    runs-on: self.hosted
    script:
      # SonarQube pode importar relatórios do Dependency Check
      - sonar-scanner \
          -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
          -Dsonar.host.url="$SONAR_HOST_URL" \
          -Dsonar.login="$SONAR_TOKEN" \
          -Dsonar.dependencyCheck.reportPath=dependency-check-report/dependency-check-report.xml
```

## Notificações e Alertas

### Slack Integration
```yaml
- step: &notify-slack
    name: Notify Slack
    runs-on: self.hosted
    script:
      # Notificar resultado do pipeline
      - |
        if [ "$BITBUCKET_EXIT_CODE" = "0" ]; then
          MESSAGE="✅ Build SUCCESS: $BITBUCKET_REPO_SLUG ($BITBUCKET_BRANCH)"
          COLOR="good"
        else
          MESSAGE="❌ Build FAILED: $BITBUCKET_REPO_SLUG ($BITBUCKET_BRANCH)"
          COLOR="danger"
        fi
        
        curl -X POST -H 'Content-type: application/json' \
          --data "{\"text\":\"$MESSAGE\", \"color\":\"$COLOR\"}" \
          "$SLACK_WEBHOOK_URL"
```

### Email Notifications
```yaml
- step: &notify-email
    name: Email Notification
    runs-on: self.hosted
    script:
      # Enviar email via API ou SMTP
      - |
        curl -X POST \
          -H "Content-Type: application/json" \
          -d "{
            \"to\": [\"team@itamaraty.gov.br\"],
            \"subject\": \"Pipeline $BITBUCKET_REPO_SLUG - $BITBUCKET_BRANCH\",
            \"body\": \"Build completed with status: $BITBUCKET_EXIT_CODE\"
          }" \
          "$EMAIL_API_URL"
```

## Monitoramento e Métricas

### Pipeline Analytics
```yaml
- step: &metrics-collection
    name: Collect Pipeline Metrics
    runs-on: self.hosted
    script:
      # Coletar métricas do pipeline
      - |
        METRICS="{
          \"repo\": \"$BITBUCKET_REPO_SLUG\",
          \"branch\": \"$BITBUCKET_BRANCH\",
          \"build_number\": \"$BITBUCKET_BUILD_NUMBER\",
          \"duration\": \"$PIPELINE_DURATION\",
          \"status\": \"$BITBUCKET_EXIT_CODE\",
          \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }"
        
        # Enviar para sistema de métricas
        curl -X POST \
          -H "Content-Type: application/json" \
          -d "$METRICS" \
          "$METRICS_ENDPOINT"
```

### Health Checks
```yaml
- step: &health-check
    name: Post-Deploy Health Check
    runs-on: self.hosted
    script:
      # Verificar saúde da aplicação após deploy
      - sleep 30 # Aguardar inicialização
      
      # Health check HTTP
      - |
        for i in {1..5}; do
          if curl -f "$APP_HEALTH_URL"; then
            echo "✅ Health check passed"
            exit 0
          fi
          echo "⏳ Attempt $i failed, retrying..."
          sleep 10
        done
        
        echo "❌ Health check failed after 5 attempts"
        exit 1
```

## Configuração de Secrets e Variáveis

### Hierarchy de Variáveis
```
1. Pipeline Variables (mais específico)
2. Repository Variables  
3. Workspace Variables (menos específico)
```

### Melhores Práticas
```yaml
# Workspace level (para todas as aplicações)
SONAR_HOST_URL: "https://sonar.itamaraty.local"
HARBOR_REGISTRY: "harbor.itamaraty.local"
SATIS_REGISTRY_URL: "https://satis.itamaraty.local"

# Repository level (por aplicação)
SONAR_PROJECT_KEY: "mre-core-api"
HARBOR_PROJECT: "mre"
APP_NAME: "core-api"

# Pipeline level (por ambiente)
DB_HOST: "prod-db.itamaraty.local"
SERVER_HOST: "prod-app.itamaraty.local"
```

### Secured Variables
```
✅ Marcar como "Secured":
- SONAR_TOKEN
- HARBOR_PASSWORD
- SATIS_TOKEN
- DB_PASSWORD
- SSH_PRIVATE_KEY
- API_KEYS

❌ Não marcar como "Secured":
- HOST_URLS
- PROJECT_NAMES
- PUBLIC_SETTINGS
```

## Troubleshooting

### Problemas Comuns

#### SonarQube Connection Issues
```bash
# Verificar conectividade
curl -I https://sonar.itamaraty.local

# Testar token
curl -u "$SONAR_TOKEN:" https://sonar.itamaraty.local/api/authentication/validate
```

#### Harbor Registry Issues
```bash
# Testar login
echo "$HARBOR_PASSWORD" | docker login $HARBOR_REGISTRY -u $HARBOR_USERNAME --password-stdin

# Verificar projeto
curl -s -u "$HARBOR_USERNAME:$HARBOR_PASSWORD" "$HARBOR_REGISTRY/api/v2.0/projects"
```

#### Dependency Check Timeout
```bash
# Aumentar timeout
export DEPENDENCY_CHECK_TIMEOUT=30

# Usar cache local
export DEPENDENCY_CHECK_DATA_DIR="/cache/dependency-check-data"
```

## Próximos Passos

1. **Configurar integrações** em ambiente de teste
2. **Validar conectividade** com todas as ferramentas
3. **Testar pipelines** com projeto piloto
4. **Documentar troubleshooting** específico
5. **Treinar equipes** nos novos fluxos