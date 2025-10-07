# Plano Detalhado de Migração - Bamboo para Bitbucket Cloud

## Visão Geral da Migração

### Objetivos
- **Migração completa** do Bamboo on-premise para Bitbucket Cloud Pipelines
- **Zero downtime** para aplicações em produção
- **Manutenção da funcionalidade** de todas as pipelines existentes
- **Melhoria da eficiência** e padronização de processos

### Escopo
- **40+ projetos** ativos no Bamboo (CORRIGIDO)
- **~200 plans** ativos que serão migrados (CORRIGIDO)
- **~72 plans** "Never built" que serão descartados (CORRIGIDO)
- **Total: ~272 plans** identificados na interface
- **6 ambientes** (3 por aplicação: dev, homolog, prod)
- **8 tecnologias** diferentes (.NET, Docker, PHP, Node.js, React, Angular, DB, Services)

## Fases da Migração

### Fase 1: Preparação e Setup Inicial
**Duração**: 2 semanas  
**Responsável**: Equipe DevOps  

#### Semana 1: Infraestrutura
- [ ] **Configurar Workspace no Bitbucket Cloud**
  - Criar workspace organizacional
  - Configurar permissões e grupos
  - Definir políticas de segurança

- [ ] **Preparar Self-hosted Runners**
  - Provisionar servidores (2 Windows, 2 Linux)
  - Instalar e configurar runners
  - Testar conectividade

- [ ] **Configurar Integrações**
  - SonarQube: configurar webhooks e tokens
  - Harbor: verificar conectividade e credenciais
  - Satis: preparar integração para PHP

#### Semana 2: Templates e Documentação
- [ ] **Finalizar Templates de Pipeline**
  - Validar templates para cada tecnologia
  - Testar em ambiente isolado
  - Documentar personalizações necessárias

- [ ] **Preparar Repositórios de Código**
  - Migrar repositórios do Bitbucket Server (se aplicável)
  - Configurar branches conforme nova estratégia
  - Aplicar proteções de branch

### Fase 2: Projeto Piloto
**Duração**: 1 semana  
**Responsável**: Equipe DevOps + 1 desenvolvedor por projeto  

#### Critérios de Seleção do Piloto
- Projeto pequeno/médio (< 50 commits/mês)
- Tecnologia conhecida (.NET ou Node.js)
- Ambiente não crítico
- Equipe colaborativa

#### Atividades do Piloto
- [ ] **Configurar Pipeline do Projeto Piloto**
  - Aplicar template apropriado
  - Configurar variáveis de ambiente
  - Adaptar scripts específicos

- [ ] **Testes Completos**
  - Build automático
  - Testes e análise de qualidade
  - Deploy para todos os ambientes
  - Rollback de teste

- [ ] **Documentar Lições Aprendidas**
  - Problemas encontrados
  - Adaptações necessárias
  - Melhorias nos templates

### Fase 3: Migração em Lotes
**Duração**: 6 semanas  
**Responsável**: Equipe DevOps + Equipes de desenvolvimento  

#### Lote 1: Projetos .NET (Semana 1)
**Projetos**: 6 aplicações .NET principais
- [ ] MRE Core API
- [ ] Hefesto Base
- [ ] RH System
- [ ] Corporate Portal
- [ ] Authentication Service
- [ ] Reporting Engine

#### Lote 2: Aplicações Web (Semana 2)
**Projetos**: 4 aplicações React/Angular
- [ ] Portal Público
- [ ] Dashboard Administrativo
- [ ] Intranet
- [ ] Help Desk

#### Lote 3: Aplicações PHP Legadas (Semana 3)
**Projetos**: 3 sistemas PHP
- [ ] Sistema Legado Principal
- [ ] Website Institucional
- [ ] CMS Interno

#### Lote 4: Aplicações Node.js (Semana 4)
**Projetos**: 2 aplicações Node.js
- [ ] API Gateway
- [ ] Microservice Principal

#### Lote 5: Aplicações Docker (Semana 5)
**Projetos**: 2 aplicações containerizadas
- [ ] Container App Principal
- [ ] Monitoring Stack

#### Lote 6: Bancos de Dados e Utilitários (Semana 6)
**Projetos**: 1 projeto especial
- [ ] Database Migrations

### Fase 4: Validação e Estabilização
**Duração**: 1 semana  
**Responsável**: Todas as equipes  

- [ ] **Testes de Integração Completos**
  - Validar todos os deployments
  - Verificar integrações entre sistemas
  - Testar cenários de rollback

- [ ] **Otimização de Performance**
  - Analisar tempos de build
  - Otimizar uso de runners
  - Ajustar paralelização

- [ ] **Treinamento Final**
  - Sessões com todas as equipes
  - Documentação de troubleshooting
  - Procedimentos de emergência

### Fase 5: Descomissionamento
**Duração**: 1 semana  
**Responsável**: Equipe DevOps  

- [ ] **Backup Final do Bamboo**
  - Exportar histórico de builds
  - Backup de configurações
  - Arquivar logs importantes

- [ ] **Desativar Bamboo**
  - Parar serviços
  - Redirecionar URLs
  - Comunicar mudança

## Cronograma Detalhado

### Timeline Geral
```
Semana 1  │████████████████████│ Prep: Infraestrutura
Semana 2  │████████████████████│ Prep: Templates
Semana 3  │████████████████████│ Piloto
Semana 4  │████████████████████│ Lote 1: .NET
Semana 5  │████████████████████│ Lote 2: Web Apps
Semana 6  │████████████████████│ Lote 3: PHP
Semana 7  │████████████████████│ Lote 4: Node.js
Semana 8  │████████████████████│ Lote 5: Docker
Semana 9  │████████████████████│ Lote 6: DB/Utils
Semana 10 │████████████████████│ Validação
Semana 11 │████████████████████│ Descomissionar
```

### Cronograma por Projeto
| Projeto | Tecnologia | Lote | Semana | Responsável | Status |
|---------|------------|------|--------|-------------|--------|
| MRE Core API | .NET | 1 | 4 | Equipe Core | ⏳ |
| Portal Público | React | 2 | 5 | Equipe Frontend | ⏳ |
| Sistema Legado A | PHP | 3 | 6 | Equipe Legacy | ⏳ |
| API Gateway | Node.js | 4 | 7 | Equipe API | ⏳ |
| Container App A | Docker | 5 | 8 | Equipe DevOps | ⏳ |
| DB Migrations | SQL | 6 | 9 | Equipe DBA | ⏳ |

## Estratégia de Rollback

### Cenários de Rollback

#### 1. Rollback Individual (Por Projeto)
**Situação**: Problema específico em um projeto
```
1. Pausar pipeline no Bitbucket
2. Reativar plan correspondente no Bamboo
3. Investigar e corrigir problema
4. Tentar migração novamente
```

#### 2. Rollback de Lote
**Situação**: Múltiplos projetos com problemas
```
1. Pausar todos os pipelines do lote
2. Reativar plans do Bamboo para o lote
3. Análise de causa raiz
4. Ajustar templates e tentar novamente
```

#### 3. Rollback Completo
**Situação**: Problema sistêmico grave
```
1. Comunicação imediata para todas as equipes
2. Reativação completa do Bamboo
3. Pausar todos os pipelines do Bitbucket
4. Análise completa e replanning
```

### Critérios para Rollback
- **Falha em > 50%** dos deploys de um lote
- **Indisponibilidade** de ambiente crítico > 30 min
- **Perda de funcionalidade** crítica
- **Problemas de segurança** identificados

## Checklist de Validação

### Por Projeto Migrado
- [ ] **Build funcionando**
  - Compilação sem erros
  - Testes passando
  - Análise de qualidade OK

- [ ] **Deploy funcionando**
  - Deploy para desenvolvimento OK
  - Deploy para homologação OK
  - Deploy para produção OK (quando aplicável)

- [ ] **Integrações funcionando**
  - SonarQube recebendo dados
  - Artefatos sendo publicados
  - Banco de dados sendo atualizado

- [ ] **Monitoramento ativo**
  - Logs sendo coletados
  - Métricas sendo enviadas
  - Alertas configurados

### Por Lote Completo
- [ ] **Todos os projetos validados**
- [ ] **Integração entre projetos testada**
- [ ] **Performance aceitável**
- [ ] **Equipe treinada**
- [ ] **Documentação atualizada**

## Comunicação e Treinamento

### Plano de Comunicação

#### Semana -2: Announcement
- **Público**: Todos os desenvolvedores
- **Canal**: Email + Intranet
- **Conteúdo**: Visão geral da migração, cronograma, impactos

#### Semana -1: Training
- **Público**: Equipes por tecnologia
- **Canal**: Sessões presenciais/virtuais
- **Conteúdo**: Hands-on com novos pipelines

#### Durante migração: Updates
- **Público**: Stakeholders
- **Canal**: Slack/Teams + Email semanal
- **Conteúdo**: Status, problemas, próximos passos

#### Pós-migração: Retro
- **Público**: Todas as equipes
- **Canal**: Sessão retrospectiva
- **Conteúdo**: Lições aprendidas, melhorias

### Material de Treinamento
- [ ] **Guia rápido**: Diferenças Bamboo vs Bitbucket
- [ ] **Video tutorials**: Como usar novos pipelines
- [ ] **Documentação técnica**: Templates e customizações
- [ ] **FAQ**: Perguntas frequentes e troubleshooting

## Recursos Necessários

### Equipe
- **DevOps Lead** (100% dedicação durante migração)
- **DevOps Engineers** (2 pessoas, 80% dedicação)
- **Tech Leads** (1 por tecnologia, 20% dedicação)
- **QA Engineer** (50% dedicação para validação)

### Infraestrutura
- **Runners**: 4 servidores (2 Windows, 2 Linux)
- **Armazenamento**: 500GB adicional para caches/artefatos
- **Bandwidth**: Monitorar uso para uploads/downloads
- **Licenças**: Bitbucket Cloud (se aplicável)

### Ferramentas Adicionais
- **Monitoring**: Dashboard para acompanhar migração
- **Backup**: Storage adicional para backups do Bamboo
- **Testing**: Ambiente isolado para testes

## Métricas de Sucesso

### Métricas Técnicas
- **Tempo de build**: ≤ tempo atual do Bamboo
- **Taxa de sucesso**: ≥ 95% dos builds passando
- **Tempo de deploy**: ≤ tempo atual do Bamboo
- **Uptime**: 99.9% de disponibilidade

### Métricas de Negócio
- **Zero incidentes** críticos causados pela migração
- **100% dos projetos** migrados no prazo
- **90% de satisfação** das equipes (survey pós-migração)
- **ROI positivo** em 6 meses (redução de custos operacionais)

## Contingências e Riscos

### Riscos Identificados

#### Alto Impacto
- **Indisponibilidade prolongada** de ambiente de produção
- **Perda de dados** ou configurações
- **Problemas de conectividade** runners ↔ Bitbucket Cloud

#### Médio Impacto
- **Atraso na migração** por complexidade inesperada
- **Resistência das equipes** à mudança
- **Problemas de performance** dos runners

#### Baixo Impacto
- **Ajustes menores** nos templates
- **Reconfigurações** de integrações
- **Documentação adicional** necessária

### Planos de Contingência

#### Para cada risco alto:
1. **Plano de prevenção** detalhado
2. **Detecção precoce** com alertas
3. **Resposta rápida** com equipe dedicada
4. **Comunicação** imediata aos stakeholders

## Conclusão

Este plano detalhado garante uma migração segura e controlada do Bamboo para o Bitbucket Cloud Pipelines, minimizando riscos e mantendo a continuidade dos serviços. A abordagem em fases permite validação contínua e ajustes conforme necessário.

### Próximos Passos Imediatos
1. **Aprovação do plano** pelos stakeholders
2. **Alocação de recursos** (equipe e infraestrutura)
3. **Início da Fase 1** (preparação)
4. **Setup de monitoramento** do progresso

### Critérios de Go/No-Go
- [ ] Equipe alocada e treinada
- [ ] Runners configurados e testados
- [ ] Templates validados
- [ ] Projeto piloto bem-sucedido
- [ ] Plano de rollback aprovado