# Migração Bamboo para Bitbucket Cloud Pipelines

## Visão Geral

Este projeto documenta a migração completa do sistema de CI/CD do Bamboo on-premise para o Bitbucket Cloud Pipelines, mantendo toda a infraestrutura de agentes on-premise.

## Objetivos

- **Modernização**: Migrar de Bamboo on-premise para Bitbucket Cloud Pipelines
- **Padronização**: Criar templates reutilizáveis para diferentes tecnologias
- **Estratégia de Branches**: Implementar deploy automático baseado em branches
- **Integração**: Manter integração com ferramentas existentes (SonarQube, Harbor, Satis)

## Estrutura do Projeto

```
migracao-bitbucket-cloud/
├── README.md                           # Este arquivo
├── documentacao/                       # Documentação completa
│   ├── 01-arquitetura-geral.md        # Arquitetura atual vs nova
│   ├── 02-estrategia-branches.md      # Estratégia de branches e deploy
│   ├── 03-configuracao-agentes.md     # Setup de runners on-premise
│   ├── 04-plano-migracao.md           # Plano detalhado de migração
│   ├── 05-integracao-ferramentas.md   # Integração com SonarQube, etc.
│   └── 06-promocao-artefatos.md       # Promoção entre ambientes
├── templates/                          # Templates de pipeline
│   ├── dotnet-msbuild.yml             # Template para .NET/MSBuild
│   ├── docker.yml                     # Template para aplicações Docker
│   ├── php-legacy.yml                 # Template para PHP 7.3/5.4
│   ├── nodejs.yml                     # Template para Node.js 12/16
│   ├── react.yml                      # Template para React
│   ├── angular.yml                    # Template para Angular
│   └── database-postgresql.yml        # Template para deploy de banco
└── scripts/                           # Scripts de apoio
    ├── deploy-database.sh              # Script adaptado para deploy de BD
    ├── sonar-integration.sh            # Integração com SonarQube
    ├── dependency-check.sh             # OWASP Dependency Check
    └── setup-runner.sh                 # Setup de runner on-premise
```

## Tecnologias Suportadas

### Build
- **MsBuildv14** (.NET Framework/Core)
- **Docker** (Aplicações containerizadas)
- **PHP 7.3 e 5.4** (Sistemas legados)
- **PostgreSQL** (Deploy de banco de dados)
- **Node.js 12 e 16**
- **React**
- **Angular**

### Publicação de Artefatos
- **Harbor** (Imagens Docker, aplicações Node.js)
- **Satis Composer** (Aplicações PHP)

### Deploy
- **VM** (Máquinas virtuais)
- **Cluster** (Kubernetes/Docker Swarm)

## Estratégia de Branches

| Branch | Ambiente | Descrição |
|--------|----------|-----------|
| `develop` | Desenvolvimento | Deploy automático para ambiente de desenvolvimento |
| `homolog` | Homologação | Deploy automático para ambiente de homologação |
| `master` | Produção | **Deploy MANUAL com aprovação obrigatória** |

> ⚠️ **IMPORTANTE**: Deploy para produção é SEMPRE manual e requer aprovação explícita de pessoa responsável.

## Fases da Migração

1. **Preparação** - Setup inicial e configuração de agentes
2. **Migração por Projeto** - Migração gradual projeto por projeto
3. **Testes** - Validação completa em todos os ambientes
4. **Desativação** - Descomissionamento do Bamboo

## Próximos Passos

1. Revisar documentação na pasta `documentacao/`
2. Analisar templates na pasta `templates/`
3. Executar plano de migração detalhado
4. Configurar runners on-premise
5. Testar pipelines em projeto piloto

## Suporte

Para dúvidas ou problemas durante a migração, consulte:
- Documentação detalhada na pasta `documentacao/`
- Templates de exemplo na pasta `templates/`
- Scripts de apoio na pasta `scripts/`