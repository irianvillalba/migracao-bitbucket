# Promoção de Artefatos Entre Ambientes

## Visão Geral

A estratégia de promoção de artefatos permite usar a **mesma build validada** em múltiplos ambientes, garantindo que o que foi testado em desenvolvimento/homologação seja exatamente o que vai para produção.

## Conceito de Promoção

### Build uma vez, Deploy múltiplas vezes
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Source    │───▶│    Build    │───▶│  Artefato   │───▶│  Promoção   │
│             │    │   (0.0.1)   │    │   (0.0.1)   │    │ Dev→Homolog │
│ • Git Push  │    │ • Compile   │    │ • Harbor    │    │ Homolog→Prod│
│ • Branch    │    │ • Test      │    │ • Satis     │    │ • Same SHA  │
│             │    │ • Package   │    │ • Package   │    │ • Same Tag  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Vantagens
- ✅ **Garantia**: O que é testado é o que vai para produção
- ✅ **Velocidade**: Deploy mais rápido (sem recompilação)
- ✅ **Confiabilidade**: Reduz riscos de diferenças entre ambientes
- ✅ **Rastreabilidade**: Mesma versão em todos os ambientes
- ✅ **Rollback**: Fácil retorno à versão anterior

## Implementação por Tecnologia

### 1. Aplicações Docker

#### Template com Promoção
```yaml
# templates/docker-promotion.yml
image: docker:20.10.16

definitions:
  steps:
    - step: &build-once
        name: Build and Push Docker Image
        runs-on: self.hosted
        services:
          - docker
        script:
          # Build apenas uma vez
          - export IMAGE_NAME="$HARBOR_REGISTRY/$HARBOR_PROJECT/$BITBUCKET_REPO_SLUG"
          - export IMAGE_TAG="${BITBUCKET_TAG:-${BITBUCKET_COMMIT:0:7}}"
          - export FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"
          
          # Build e push para registry
          - docker build -t $FULL_IMAGE_NAME .
          - docker tag $FULL_IMAGE_NAME $IMAGE_NAME:latest
          - echo $HARBOR_PASSWORD | docker login $HARBOR_REGISTRY -u $HARBOR_USERNAME --password-stdin
          - docker push $FULL_IMAGE_NAME
          - docker push $IMAGE_NAME:latest
          
          # Salvar informações da imagem
          - echo "IMAGE_TAG=$IMAGE_TAG" > image.env
        artifacts:
          - image.env

    - step: &promote-to-dev
        name: Deploy to Development (Promote)
        runs-on: self.hosted
        script:
          # Usar imagem já buildada
          - source image.env
          - export IMAGE_NAME="$HARBOR_REGISTRY/$HARBOR_PROJECT/$BITBUCKET_REPO_SLUG"
          - export FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"
          
          # Deploy usando imagem existente
          - ssh $DEV_SERVER_USER@$DEV_SERVER_HOST "
              docker login $HARBOR_REGISTRY -u $HARBOR_USERNAME -p $HARBOR_PASSWORD &&
              docker pull $FULL_IMAGE_NAME &&
              docker stop $APP_CONTAINER_NAME || true &&
              docker rm $APP_CONTAINER_NAME || true &&
              docker run -d --name $APP_CONTAINER_NAME -p $DEV_APP_PORT:$APP_INTERNAL_PORT $FULL_IMAGE_NAME
            "

    - step: &promote-to-homolog
        name: Deploy to Homologation (Promote)
        runs-on: self.hosted
        trigger: manual
        script:
          # Promover mesma imagem para homologação
          - source image.env
          - export IMAGE_NAME="$HARBOR_REGISTRY/$HARBOR_PROJECT/$BITBUCKET_REPO_SLUG"
          - export FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"
          
          # Validar que imagem existe
          - docker login $HARBOR_REGISTRY -u $HARBOR_USERNAME --password-stdin
          - docker pull $FULL_IMAGE_NAME
          
          # Deploy para homologação
          - ssh $HOMOLOG_SERVER_USER@$HOMOLOG_SERVER_HOST "
              docker login $HARBOR_REGISTRY -u $HARBOR_USERNAME -p $HARBOR_PASSWORD &&
              docker pull $FULL_IMAGE_NAME &&
              docker stop $APP_CONTAINER_NAME || true &&
              docker rm $APP_CONTAINER_NAME || true &&
              docker run -d --name $APP_CONTAINER_NAME -p $HOMOLOG_APP_PORT:$APP_INTERNAL_PORT $FULL_IMAGE_NAME
            "

    - step: &promote-to-prod
        name: Deploy to Production (Promote)
        runs-on: self.hosted
        trigger: manual
        script:
          # Promover mesma imagem para produção
          - source image.env
          - export IMAGE_NAME="$HARBOR_REGISTRY/$HARBOR_PROJECT/$BITBUCKET_REPO_SLUG"
          - export FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"
          
          # Validação extra para produção
          - echo "Promovendo versão: $IMAGE_TAG"
          - echo "Imagem: $FULL_IMAGE_NAME"
          - docker login $HARBOR_REGISTRY -u $HARBOR_USERNAME --password-stdin
          - docker pull $FULL_IMAGE_NAME
          
          # Deploy para produção
          - ssh $PROD_SERVER_USER@$PROD_SERVER_HOST "
              docker tag \$(docker inspect --format='{{.Image}}' $APP_CONTAINER_NAME) $IMAGE_NAME:backup-\$(date +%Y%m%d_%H%M%S) || true &&
              docker login $HARBOR_REGISTRY -u $HARBOR_USERNAME -p $HARBOR_PASSWORD &&
              docker pull $FULL_IMAGE_NAME &&
              docker stop $APP_CONTAINER_NAME || true &&
              docker rm $APP_CONTAINER_NAME || true &&
              docker run -d --name $APP_CONTAINER_NAME -p $PROD_APP_PORT:$APP_INTERNAL_PORT $FULL_IMAGE_NAME
            "

pipelines:
  branches:
    develop:
      - step: *build-once
      - step: *promote-to-dev

    homolog:
      - step: *promote-to-homolog

    master:
      - step: *promote-to-prod

  # Pipeline para promoção manual por tag
  tags:
    'v*':
      - step: *promote-to-prod
```

### 2. Aplicações .NET

#### Template com Promoção
```yaml
# templates/dotnet-promotion.yml
image: mcr.microsoft.com/dotnet/sdk:6.0

definitions:
  steps:
    - step: &build-package
        name: Build and Package .NET Application
        runs-on: self.hosted
        caches:
          - dotnetcore
        script:
          # Build e empacotamento
          - dotnet restore
          - dotnet build --configuration Release --no-restore
          - dotnet test --configuration Release --no-build
          - dotnet publish --configuration Release --no-build --output ./publish
          
          # Criar pacote versionado
          - export PACKAGE_VERSION="${BITBUCKET_TAG:-${BITBUCKET_COMMIT:0:7}}"
          - tar -czf "${BITBUCKET_REPO_SLUG}-${PACKAGE_VERSION}.tar.gz" -C publish .
          
          # Upload para Harbor (como artefato)
          - curl -X POST \
              -H "Authorization: Basic $(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)" \
              -F "file=@${BITBUCKET_REPO_SLUG}-${PACKAGE_VERSION}.tar.gz" \
              "$HARBOR_REGISTRY/api/v2.0/projects/$HARBOR_PROJECT/repositories/$BITBUCKET_REPO_SLUG/artifacts"
          
          # Salvar informações do pacote
          - echo "PACKAGE_VERSION=$PACKAGE_VERSION" > package.env
        artifacts:
          - package.env
          - "*.tar.gz"

    - step: &promote-dotnet-dev
        name: Deploy .NET to Development (Promote)
        runs-on: self.hosted
        script:
          # Download do pacote específico
          - source package.env
          - export PACKAGE_FILE="${BITBUCKET_REPO_SLUG}-${PACKAGE_VERSION}.tar.gz"
          
          # Download do Harbor (ou usar artefato local)
          - curl -u "$HARBOR_USERNAME:$HARBOR_PASSWORD" \
              -o "$PACKAGE_FILE" \
              "$HARBOR_REGISTRY/api/v2.0/projects/$HARBOR_PROJECT/repositories/$BITBUCKET_REPO_SLUG/artifacts/$PACKAGE_VERSION/download"
          
          # Deploy
          - tar -xzf "$PACKAGE_FILE" -C ./deploy/
          - rsync -avz --delete ./deploy/ $DEV_SERVER_USER@$DEV_SERVER_HOST:$DEV_APP_PATH/
          - ssh $DEV_SERVER_USER@$DEV_SERVER_HOST "sudo systemctl restart $APP_SERVICE_NAME"

    - step: &promote-dotnet-homolog
        name: Deploy .NET to Homologation (Promote)
        runs-on: self.hosted
        trigger: manual
        script:
          # Promover mesmo pacote
          - source package.env
          - export PACKAGE_FILE="${BITBUCKET_REPO_SLUG}-${PACKAGE_VERSION}.tar.gz"
          
          # Download e deploy
          - curl -u "$HARBOR_USERNAME:$HARBOR_PASSWORD" \
              -o "$PACKAGE_FILE" \
              "$HARBOR_REGISTRY/api/v2.0/projects/$HARBOR_PROJECT/repositories/$BITBUCKET_REPO_SLUG/artifacts/$PACKAGE_VERSION/download"
          - tar -xzf "$PACKAGE_FILE" -C ./deploy/
          - rsync -avz --delete ./deploy/ $HOMOLOG_SERVER_USER@$HOMOLOG_SERVER_HOST:$HOMOLOG_APP_PATH/
          - ssh $HOMOLOG_SERVER_USER@$HOMOLOG_SERVER_HOST "sudo systemctl restart $APP_SERVICE_NAME"

pipelines:
  branches:
    develop:
      - step: *build-package
      - step: *promote-dotnet-dev

    homolog:
      - step: *promote-dotnet-homolog

    master:
      - step:
          <<: *promote-dotnet-prod
          trigger: manual
```

### 3. Aplicações PHP

#### Template com Promoção via Satis
```yaml
# templates/php-promotion.yml
image: php:7.3-cli

definitions:
  steps:
    - step: &build-php-package
        name: Build PHP Package
        runs-on: self.hosted
        script:
          # Build e validação
          - composer install --no-dev --optimize-autoloader
          - find . -name "*.php" -exec php -l {} \;
          
          # Criar pacote versionado
          - export PACKAGE_VERSION="${BITBUCKET_TAG:-${BITBUCKET_COMMIT:0:7}}"
          - export PACKAGE_NAME=$(php -r "echo json_decode(file_get_contents('composer.json'))->name;")
          - export ZIP_NAME="${PACKAGE_NAME}-${PACKAGE_VERSION}.zip"
          
          # Empacotar
          - zip -r $ZIP_NAME . -x "*.git*" "tests/*" "*.zip"
          
          # Upload para Satis
          - curl -X POST \
              -F "package=@${ZIP_NAME}" \
              -H "Authorization: Bearer $SATIS_TOKEN" \
              "$SATIS_UPLOAD_URL"
          
          # Salvar informações
          - echo "PACKAGE_VERSION=$PACKAGE_VERSION" > package.env
          - echo "PACKAGE_NAME=$PACKAGE_NAME" >> package.env
        artifacts:
          - package.env

    - step: &promote-php-dev
        name: Deploy PHP to Development (Promote)
        runs-on: self.hosted
        script:
          # Usar pacote específico do Satis
          - source package.env
          - export COMPOSER_JSON="{\"require\":{\"$PACKAGE_NAME\":\"$PACKAGE_VERSION\"}}"
          
          # Deploy usando Composer
          - ssh $DEV_SERVER_USER@$DEV_SERVER_HOST "
              cd $DEV_APP_PATH &&
              echo '$COMPOSER_JSON' > composer.json &&
              composer install --no-dev &&
              sudo chown -R www-data:www-data $DEV_APP_PATH
            "

pipelines:
  branches:
    develop:
      - step: *build-php-package
      - step: *promote-php-dev
```

## Promoção Manual via Bitbucket UI

### 1. Configurar Pipeline de Promoção
```yaml
# Pipeline especial para promoção manual
pipelines:
  custom:
    promote-to-homolog:
      - variables:
          - name: SOURCE_VERSION
            default: "latest"
      - step:
          name: Promote to Homologation
          runs-on: self.hosted
          script:
            # Promover versão específica
            - export VERSION="${SOURCE_VERSION}"
            - echo "Promovendo versão: $VERSION"
            # ... lógica de promoção

    promote-to-prod:
      - variables:
          - name: SOURCE_VERSION
            default: "latest"
      - step:
          name: Promote to Production
          runs-on: self.hosted
          trigger: manual
          script:
            # Promover para produção
            - export VERSION="${SOURCE_VERSION}"
            - echo "Promovendo versão: $VERSION para PRODUÇÃO"
            # ... lógica de promoção
```

### 2. Como Usar no Bitbucket UI
```
1. Acesse Bitbucket → Repository → Pipelines
2. Clique em "Run pipeline"
3. Selecione "Custom pipeline"
4. Escolha "promote-to-homolog" ou "promote-to-prod"
5. Informe a versão (ex: 0.0.1)
6. Execute
```

## Rastreabilidade de Promoção

### Logging de Promoção
```bash
# Script para log de promoção
log_promotion() {
    local env=$1
    local version=$2
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Log estruturado
    echo "{
        \"action\": \"promotion\",
        \"environment\": \"$env\",
        \"version\": \"$version\",
        \"repository\": \"$BITBUCKET_REPO_SLUG\",
        \"user\": \"$BITBUCKET_STEP_TRIGGERER_UUID\",
        \"timestamp\": \"$timestamp\",
        \"build_number\": \"$BITBUCKET_BUILD_NUMBER\"
    }" | curl -X POST -H "Content-Type: application/json" \
           -d @- "$PROMOTION_LOG_ENDPOINT"
}

# Usar no script
log_promotion "production" "$PACKAGE_VERSION"
```

### Base de Dados de Promoção
```sql
-- Tabela para rastrear promoções
CREATE TABLE deployment_promotions (
    id SERIAL PRIMARY KEY,
    repository VARCHAR(100) NOT NULL,
    version VARCHAR(50) NOT NULL,
    source_env VARCHAR(20),
    target_env VARCHAR(20) NOT NULL,
    promoted_by VARCHAR(100),
    promoted_at TIMESTAMP DEFAULT NOW(),
    build_number INTEGER,
    status VARCHAR(20) DEFAULT 'success'
);

-- Inserir promoção
INSERT INTO deployment_promotions 
(repository, version, source_env, target_env, promoted_by, build_number)
VALUES ('mre-core-api', '0.0.1', 'homolog', 'production', 'user@itamaraty.gov.br', 123);
```

## Comandos CLI para Promoção

### Script de Promoção Manual
```bash
#!/bin/bash
# promote.sh - Script para promoção manual

promote() {
    local repo=$1
    local version=$2
    local from_env=$3
    local to_env=$4
    
    echo "🚀 Promovendo $repo:$version de $from_env para $to_env"
    
    # Validar que versão existe
    if ! check_version_exists "$repo" "$version"; then
        echo "❌ Versão $version não encontrada"
        exit 1
    fi
    
    # Executar promoção
    case $to_env in
        "homolog")
            promote_to_homolog "$repo" "$version"
            ;;
        "production")
            promote_to_production "$repo" "$version"
            ;;
        *)
            echo "❌ Ambiente $to_env não suportado"
            exit 1
            ;;
    esac
    
    echo "✅ Promoção concluída!"
}

# Usar: ./promote.sh mre-core-api 0.0.1 homolog production
promote "$@"
```

## Melhores Práticas

### 1. Versionamento Semântico
```
v1.0.0     - Release de produção
v1.0.1     - Patch/hotfix
v1.1.0     - Nova feature
v2.0.0     - Breaking change
v1.1.0-rc1 - Release candidate
```

### 2. Estratégia de Tags
```bash
# Tag após validação em homologação
git tag -a v1.0.0 -m "Release 1.0.0 - validated in staging"
git push origin v1.0.0

# Promover para produção usando a tag
# Pipeline automático baseado na tag
```

### 3. Validação de Promoção
```yaml
- step: &validate-promotion
    name: Validate Promotion Prerequisites
    script:
      # Verificar que versão passou em todos os testes
      - check_test_results "$PACKAGE_VERSION"
      - check_security_scan "$PACKAGE_VERSION"
      - check_quality_gate "$PACKAGE_VERSION"
      
      # Verificar aprovações necessárias
      - check_change_approval "$PACKAGE_VERSION"
      
      # Verificar janela de deployment
      - check_deployment_window
```

## Próximos Passos

1. **Escolher estratégia** baseada na tecnologia do projeto
2. **Implementar templates** de promoção
3. **Configurar registry/artefatos** para armazenamento
4. **Testar fluxo completo** com projeto piloto
5. **Documentar processo** específico da organização
6. **Treinar equipes** no novo fluxo de promoção