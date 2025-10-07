# Arquitetura Geral - Migração para Bitbucket Cloud

## Arquitetura Atual (Bamboo On-Premise)

### Componentes Atuais
```
┌─────────────────────────────────────────────────────────────┐
│                    BAMBOO ON-PREMISE                        │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │
│ │   Plans     │  │  Projects   │  │    Build Agents     │   │
│ │             │  │             │  │                     │   │
│ │ • .NET      │  │ • MRE Core  │  │ • Windows Agents    │   │
│ │ • Docker    │  │ • Hefesto   │  │ • Linux Agents      │   │
│ │ • PHP       │  │ • RH        │  │ • Docker Agents     │   │
│ │ • Node.js   │  │ • Corp      │  │                     │   │
│ │ • React     │  │             │  │                     │   │
│ │ • Angular   │  │             │  │                     │   │
│ └─────────────┘  └─────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                INFRAESTRUTURA ON-PREMISE                    │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │
│ │   Harbor    │  │   Satis     │  │    Ambientes        │   │
│ │ (Registry)  │  │ (Composer)  │  │                     │   │
│ │             │  │             │  │ • Desenvolvimento   │   │
│ │ • Images    │  │ • PHP Pkgs  │  │ • Homologação      │   │
│ │ • Node.js   │  │             │  │ • Produção         │   │
│ └─────────────┘  └─────────────┘  └─────────────────────┘   │
│                                                             │
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │
│ │  SonarQube  │  │ PostgreSQL  │  │    Dependency       │   │
│ │             │  │  Database   │  │     Check           │   │
│ │ • Quality   │  │             │  │                     │   │
│ │ • Security  │  │ • Buzz      │  │ • Vulnerabilities   │   │
│ │ • Coverage  │  │ • Other DBs │  │ • Licenses          │   │
│ └─────────────┘  └─────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Nova Arquitetura (Bitbucket Cloud + Runners On-Premise)

### Componentes da Nova Arquitetura
```
┌─────────────────────────────────────────────────────────────┐
│                  BITBUCKET CLOUD                            │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────┐ │
│ │              REPOSITORIES                               │ │
│ │                                                         │ │
│ │ ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │ │
│ │ │   Branch    │  │  Pipeline   │  │   Variables     │  │ │
│ │ │ Management  │  │ Templates   │  │  & Secrets      │  │ │
│ │ │             │  │             │  │                 │  │ │
│ │ │ • develop   │  │ • .NET      │  │ • DB_HOST       │  │ │
│ │ │ • homolog   │  │ • Docker    │  │ • SONAR_TOKEN   │  │ │
│ │ │ • master    │  │ • PHP       │  │ • HARBOR_CREDS  │  │ │
│ │ │             │  │ • Node.js   │  │ • DEPLOY_KEYS   │  │ │
│ │ └─────────────┘  └─────────────┘  └─────────────────┘  │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (Webhook/Trigger)
┌─────────────────────────────────────────────────────────────┐
│                SELF-HOSTED RUNNERS                          │
│                   (ON-PREMISE)                              │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │
│ │  Windows    │  │   Linux     │  │    Docker           │   │
│ │  Runners    │  │  Runners    │  │   Runners           │   │
│ │             │  │             │  │                     │   │
│ │ • .NET      │  │ • PHP       │  │ • Multi-platform    │   │
│ │ • Node.js   │  │ • Node.js   │  │ • Isolated builds   │   │
│ │ • React     │  │ • Angular   │  │ • Clean state       │   │
│ │ • MSBuild   │  │ • Docker    │  │                     │   │
│ └─────────────┘  └─────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│          INFRAESTRUTURA ON-PREMISE (Mantida)                │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │
│ │   Harbor    │  │   Satis     │  │    Ambientes        │   │
│ │ (Registry)  │  │ (Composer)  │  │                     │   │
│ │             │  │             │  │ • Desenvolvimento   │   │
│ │ • Images    │  │ • PHP Pkgs  │  │ • Homologação      │   │
│ │ • Node.js   │  │             │  │ • Produção         │   │
│ └─────────────┘  └─────────────┘  └─────────────────────┘   │
│                                                             │
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │
│ │  SonarQube  │  │ PostgreSQL  │  │    Dependency       │   │
│ │             │  │  Database   │  │     Check           │   │
│ │ • Quality   │  │             │  │                     │   │
│ │ • Security  │  │ • Buzz      │  │ • Vulnerabilities   │   │
│ │ • Coverage  │  │ • Other DBs │  │ • Licenses          │   │
│ └─────────────┘  └─────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Principais Diferenças

### Bamboo vs Bitbucket Cloud

| Aspecto | Bamboo (Atual) | Bitbucket Cloud (Novo) |
|---------|----------------|------------------------|
| **Hospedagem** | On-premise | Cloud (SaaS) |
| **Configuração** | Interface Web GUI | YAML (bitbucket-pipelines.yml) |
| **Agentes** | Bamboo Agents | Self-hosted Runners |
| **Versionamento** | Separado do código | Versionado com código |
| **Escalabilidade** | Limitada por hardware | Elástica (runners on-demand) |
| **Manutenção** | Manual/Equipe interna | Gerenciada pela Atlassian |
| **Integração Git** | Plugin/Configuração | Nativa |
| **Branches** | Configuração manual | Automática baseada em YAML |

### Vantagens da Nova Arquitetura

#### 1. **Gestão Simplificada**
- Configuração versionada junto com o código
- Menos servidores para manter
- Atualizações automáticas da plataforma

#### 2. **Maior Flexibilidade**
- Pipelines diferentes por branch
- Configuração específica por projeto
- Fácil replicação entre projetos

#### 3. **Melhor Integração**
- Integração nativa com repositórios
- Pull requests com status de build
- Webhooks automáticos

#### 4. **Escalabilidade**
- Runners on-demand
- Isolamento entre builds
- Paralelização natural

### Desafios da Migração

#### 1. **Curva de Aprendizado**
- Nova sintaxe YAML
- Conceitos diferentes (steps, pipes, etc.)
- Debugging diferente

#### 2. **Configuração Inicial**
- Setup de runners on-premise
- Migração de variáveis/secrets
- Configuração de conectividade

#### 3. **Adaptação de Scripts**
- Scripts de deploy existentes
- Variáveis de ambiente
- Paths e contextos diferentes

## Fluxo de Trabalho Proposto

### 1. Pipeline Padrão
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Source    │───▶│    Build    │───▶│    Test     │───▶│   Deploy    │
│             │    │             │    │             │    │             │
│ • Git Clone │    │ • Compile   │    │ • Unit      │    │ • Dev       │
│ • Checkout  │    │ • Package   │    │ • Integration│    │ • Homolog   │
│             │    │             │    │ • Security  │    │ • Prod      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                           │                    │
                                           ▼                    ▼
                                   ┌─────────────┐    ┌─────────────┐
                                   │  SonarQube  │    │   Harbor    │
                                   │    Scan     │    │   Satis     │
                                   └─────────────┘    └─────────────┘
```

### 2. Estratégia de Branches
```
develop ──────────────────────▶ Deploy Automático ──▶ Ambiente Desenvolvimento
   │
   └─▶ homolog ──────────────▶ Deploy Automático ──▶ Ambiente Homologação
           │
           └─▶ master ────▶ Deploy Automático ──▶ Ambiente Produção
```

## Próximos Passos

1. **Configurar Runners** - Setup inicial dos self-hosted runners
2. **Criar Templates** - Desenvolver templates YAML para cada tecnologia
3. **Migração Piloto** - Testar com projeto menor
4. **Validação** - Testes completos em todos os ambientes
5. **Rollout** - Migração gradual de todos os projetos