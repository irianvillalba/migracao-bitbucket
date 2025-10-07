# Estratégia de Branches e Deploy Automático

## Visão Geral

A nova estratégia de branches foi desenhada para automatizar completamente o processo de deploy baseado na branch de destino, eliminando a necessidade de configuração manual para cada ambiente.

## Estrutura de Branches

### Branch Flow
```
┌─────────────────┐
│     develop     │ ──────────────┐
│                 │               │
│ • Desenvolvimento│               │
│ • Features      │               │
│ • Bugfixes      │               │
└─────────────────┘               │
                                  │
                                  ▼
                         ┌─────────────────┐
                         │     homolog     │ ──────────────┐
                         │                 │               │
                         │ • Homologação   │               │
                         │ • Testes UAT    │               │
                         │ • Validação     │               │
                         └─────────────────┘               │
                                                           │
                                                           ▼
                                                  ┌─────────────────┐
                                                  │     master      │
                                                  │                 │
                                                  │ • Produção      │
                                                  │ • Releases      │
                                                  │ • Hotfixes      │
                                                  └─────────────────┘
```

## Estratégia de Promoção de Artefatos

### Build uma vez, Deploy múltiplas vezes
```
develop (build) ──▶ Artefato 0.0.1 ──▶ Deploy Dev (automático)
                         │
homolog (promote) ──────┘ ├─────────▶ Deploy Homolog (manual)
                               │
master (promote) ─────────────┘ └─▶ Deploy Prod (manual)
```

### Vantagens da Promoção
- ✅ **Mesmo artefato** em todos os ambientes
- ✅ **Deploy mais rápido** (sem recompilação)
- ✅ **Reduz riscos** de diferenças entre ambientes
- ✅ **Rastreabilidade** completa da versão

### Mapeamento Branch → Ação

| Branch | Ação | Artefato | Descrição |
|--------|------|----------|-----------|
| `develop` | **Build + Deploy** | Cria 0.0.1 | Build único + deploy dev |
| `homolog` | **Promote** | Usa 0.0.1 | Promove artefato existente |
| `master` | **Promote** | Usa 0.0.1 | Promove para produção |

## Mapeamento Branch → Ambiente

| Branch | Ambiente | Deploy | Trigger | Aprovação |
|--------|----------|--------|---------|-----------|
| `develop` | Desenvolvimento | Automático | Push | Não |
| `homolog` | Homologação | Automático | Push | Não |
| `master` | Produção | **MANUAL** | **Manual** | **OBRIGATÓRIA** |

## Fluxo de Trabalho Detalhado

### 1. Branch `develop` → Ambiente de Desenvolvimento

#### Características:
- **Deploy**: Automático a cada push
- **Finalidade**: Desenvolvimento contínuo e testes iniciais
- **Aprovação**: Não requerida
- **Rollback**: Automático (próximo push)

#### Pipeline:
```yaml
develop:
  - step: Build
  - parallel:
    - step: Tests
    - step: SonarQube
    - step: Security Scan
  - step: Deploy to Development (automatic)
```

#### Casos de Uso:
- Desenvolvimento de features
- Correção de bugs
- Testes de integração
- Validação de builds

### 2. Branch `homolog` → Ambiente de Homologação

#### Características:
- **Deploy**: Automático a cada push
- **Finalidade**: Testes de aceitação e validação de negócio
- **Aprovação**: Não requerida (ambiente protegido)
- **Rollback**: Manual ou novo push

#### Pipeline:
```yaml
homolog:
  - step: Build
  - parallel:
    - step: Tests
    - step: SonarQube
    - step: Security Scan
    - step: Dependency Check  # OWASP Security
  - step: Deploy to Homologation (automatic)
  - step: Lighthouse Audit  # Para aplicações frontend
```

#### Casos de Uso:
- Testes de aceitação do usuário (UAT)
- Validação de requisitos de negócio
- Testes de performance
- Demonstrações para stakeholders

### 3. Branch `master` → Ambiente de Produção

#### Características:
- **Deploy**: **MANUAL com aprovação obrigatória**
- **Finalidade**: Ambiente de produção
- **Aprovação**: **Obrigatória por pessoa responsável**
- **Rollback**: Processo controlado com aprovação
- **Segurança**: Máximo nível de proteção

#### Pipeline:
```yaml
master:
  - step: Build
  - parallel:
    - step: Tests
    - step: SonarQube
    - step: Security Scan
    - step: Dependency Check  # OWASP Security Check
  - step: 
      <<: Deploy to Production
      trigger: manual  # ⚠️ SEMPRE MANUAL
      # Requer aprovação manual antes de executar
```

#### Casos de Uso:
- Releases de produção
- Hotfixes críticos
- Deployments programados

## Estratégia de Versionamento

### Semantic Versioning
```
v<MAJOR>.<MINOR>.<PATCH>[-<PRE-RELEASE>]

Exemplos:
- v1.0.0        (Release de produção)
- v1.0.1        (Patch/hotfix)
- v1.1.0        (Nova feature)
- v2.0.0        (Breaking change)
- v1.1.0-alpha1 (Pre-release)
- v1.1.0-beta1  (Beta release)
- v1.1.0-rc1    (Release candidate)
```

### Tags e Releases
- **Tags**: Criadas automaticamente no merge para master
- **Pre-releases**: Para branches homolog (opcionais)
- **Releases**: Apenas para deployments de produção

## Controles de Segurança para Produção

### Deploy Manual Obrigatório
- **Nenhum deploy automático** para produção
- **Sempre requer intervenção humana**
- **Aprovação explícita** antes da execução
- **Validação de pré-requisitos** antes do deploy

### Processo de Aprovação
```
1. Pipeline executa build + testes + análises
2. Pipeline pausa aguardando aprovação manual
3. Responsável valida:
   ✅ Testes passaram
   ✅ Quality Gate OK
   ✅ Security Scan limpo
   ✅ Change Request aprovado
   ✅ Janela de deploy apropriada
4. Aprovação manual para continuar
5. Deploy executado com monitoramento
6. Validação pós-deploy obrigatória
```

### Responsáveis por Aprovação
- **Tech Lead** do projeto
- **DevOps Lead** 
- **Gestor do sistema** (para mudanças críticas)

## Proteção de Branches

### Regras de Proteção

#### Branch `master`:
- Requer pull request
- Requer revisão de código (mínimo 2 aprovações)
- Requer status checks (CI/CD passou)
- Requer branches atualizadas
- Administradores não podem fazer bypass

#### Branch `homolog`:
- Requer pull request
- Requer revisão de código (mínimo 1 aprovação)
- Requer status checks (CI/CD passou)
- Permite force push por administradores

#### Branch `develop`:
- Permite push direto
- Requer status checks (CI/CD passou)
- Permite force push

## Configuração no Bitbucket Cloud

### 1. Repository Settings
```yaml
# bitbucket-pipelines.yml
pipelines:
  branches:
    develop:
      - step: *build
      - parallel:
        - step: *test
        - step: *security-scan
      - step: *deploy-dev

    homolog:
      - step: *build
      - parallel:
        - step: *test
        - step: *security-scan
        - step: *performance-test
      - step: *deploy-homolog

    master:
      - step: *build
      - parallel:
        - step: *test
        - step: *security-scan
        - step: *compliance-check
      - step:
          <<: *deploy-prod
          trigger: manual  # ⚠️ OBRIGATÓRIO: Deploy manual para produção
          # Pessoa responsável deve aprovar manualmente
```

### 2. Branch Permissions
```json
{
  "master": {
    "merge_checks": {
      "require_approvals": 2,
      "require_all_checks": true,
      "require_up_to_date": true
    },
    "restrictions": {
      "push": ["admins"],
      "merge": ["developers", "admins"]
    }
  },
  "homolog": {
    "merge_checks": {
      "require_approvals": 1,
      "require_all_checks": true
    },
    "restrictions": {
      "push": ["developers", "admins"],
      "merge": ["developers", "admins"]
    }
  }
}
```

## Deployment Environments

### Configuração de Ambientes

#### Development Environment
```yaml
deployment: development
variables:
  - name: SERVER_HOST
    value: "dev.itamaraty.local"
  - name: DB_HOST
    value: "dev-db.itamaraty.local"
  - name: APP_ENV
    value: "development"
```

#### Staging Environment
```yaml
deployment: staging
variables:
  - name: SERVER_HOST
    value: "homolog.itamaraty.local"
  - name: DB_HOST
    value: "homolog-db.itamaraty.local"
  - name: APP_ENV
    value: "staging"
```

#### Production Environment
```yaml
deployment: production
variables:
  - name: SERVER_HOST
    value: "prod.itamaraty.local"
  - name: DB_HOST
    value: "prod-db.itamaraty.local"
  - name: APP_ENV
    value: "production"
trigger: manual
```

## Estratégias de Rollback

### 1. Rollback Automático (Development)
- Novo push com correção
- Deploy automático da correção

### 2. Rollback Manual (Homologation/Production)
```bash
# Revert commit e novo deploy
git revert <commit-hash>
git push origin master

# Ou deploy de versão anterior
git checkout v1.0.0
# Pipeline manual para deploy
```

### 3. Rollback de Banco de Dados
```bash
# Restore do backup automático
psql -h $DB_HOST -U $DB_USER -d $DB_NAME < backup_20241006_120000.sql

# Ou migration para versão anterior
git checkout v1.0.0
# Execute database deployment pipeline
```

## Monitoramento e Alertas

### Health Checks
- Verificação automática pós-deploy
- Endpoints de saúde em cada ambiente
- Alertas em caso de falha

### Métricas
- Tempo de deploy por ambiente
- Taxa de sucesso dos deployments
- Frequência de rollbacks

## Boas Práticas

### 1. Desenvolvimento
- Features desenvolvidas em feature branches
- Merge para develop via pull request
- Testes locais antes do push

### 2. Homologação
- Cherry-pick de commits específicos se necessário
- Testes completos antes do merge para master
- Documentação de mudanças

### 3. Produção
- Deploy apenas de código homologado
- Window de deploy programada
- Comunicação prévia para stakeholders
- Plano de rollback preparado

## Migração das Branches Existentes

### Passo a Passo
1. **Mapear branches atuais** do Bamboo para nova estrutura
2. **Criar novas branches** com convenção padronizada
3. **Configurar proteções** em cada branch
4. **Migrar configurações** de deploy por ambiente
5. **Testar fluxo completo** com projeto piloto

### Timeline Sugerida
- **Semana 1**: Configuração de branches e proteções
- **Semana 2**: Implementação de pipelines
- **Semana 3**: Testes com projeto piloto
- **Semana 4**: Migração em lote de projetos