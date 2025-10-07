#!/bin/bash

# Script adaptado para deploy de banco PostgreSQL no Bitbucket Pipelines
# Baseado no script original do Bamboo

set -e  # Parar execução em caso de erro

# Função para log com timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para log de erro
error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Configurar variáveis do ambiente Bitbucket
repositorio="${BITBUCKET_GIT_SSH_ORIGIN}"
banco="${DB_NAME:-buzz}"
schema="${DB_SCHEMA:-assinatura}"
host_banco="${DB_HOST}"
tag_version="${BITBUCKET_TAG:-0}"
build_user="${BITBUCKET_STEP_TRIGGERER_UUID:-system}"
branch="${BITBUCKET_BRANCH}"
build_number="${BITBUCKET_BUILD_NUMBER}"

# Log de início
log "=== DATABASE DEPLOYMENT STARTED ==="
log "Repository: $repositorio"
log "Database: $banco"
log "Schema: $schema"
log "Host: $host_banco"
log "Tag: $tag_version"
log "User: $build_user"
log "Branch: $branch"
log "Build: $build_number"

# String de inserção para log de versão
insert="
--Atualiza a versão atual do banco
INSERT INTO $schema.tb_log_versao (no_versao, ds_versao, ds_demanda, no_login)
VALUES ('$tag_version', '$BITBUCKET_REPO_SLUG (build $build_number)', '$branch', '$build_user');
"

# Verificar se tag foi informada
if [ "$tag_version" = "0" ]; then
    log "Nenhuma versão de banco informada."
    log "Para executar deploy de banco, informe uma tag na build."
    exit 0
fi

# Verificar se a tag está no formato válido
if [[ ! "$tag_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\-(alpha|beta|rc?)[0-9]+)?$ ]]; then
    error "A tag $tag_version não está no formato válido."
    error "Informe uma tag no formato 1.0.0 ou 1.0.0-alpha1."
    error "Favor verificar os padrões de versionamento."
    exit 1
fi

log "Substituição de variáveis:"
log "- banco por: $schema"
log "- repositorio por: $repositorio"

# Verificar conectividade com banco
log "Testando conectividade com banco de dados..."
if ! PGPASSWORD="$DB_PASSWORD" psql -h "$host_banco" -U "$DB_USER" -d "$banco" -c "SELECT 1;" > /dev/null 2>&1; then
    error "Erro ao conectar ao banco de dados."
    error "Verifique as credenciais e conectividade."
    exit 1
fi
log "Conectividade com banco OK."

# Verificar se a TAG de banco passada na build é igual a TAG atualmente implantada
log "Comparando versões..."
diff=$(PGPASSWORD="$DB_PASSWORD" psql --command "SELECT fn_comparar_versao('$schema','$tag_version')" --host="$host_banco" --username="$DB_USER" --dbname="$banco" --tuples-only --no-align --no-password)

if [ "$?" != "0" ]; then
    error "Erro ao executar função de comparação de versão."
    exit 1
fi

log "Resultado da comparação: $diff"

# Recupera a versão atualmente implantada no banco de dados
versao_banco=$(PGPASSWORD="$DB_PASSWORD" psql --command "select no_versao from $schema.vw_log_versao order by id_versao desc limit 1" --host="$host_banco" --username="$DB_USER" --dbname="$banco" --tuples-only --no-align)

log "Versão atual do banco: $versao_banco"
log "Versão da Build: $tag_version"

# Se a TAG da build for diferente da implantada, executa a atualização
if [ "$diff" != "0" ]; then
    log "Iniciando atualização do banco de dados..."
    
    # Clonar o repositório na versão atual do banco
    log "Clonando repositório na versão $versao_banco..."
    git clone -b "$versao_banco" "$repositorio" banco_atual
    
    # Verificar se a clonagem foi executada sem erros
    if [ "$?" == "0" ]; then
        cd banco_atual
        
        # Checkout para branch atual
        git checkout "$branch"
        
        # Gerar diff entre versões
        log "Gerando script de diferenças entre $versao_banco e $tag_version..."
        git diff "$versao_banco" "$tag_version" > ../database_changes.sql
        
        cd ..
        
        # Mostrar mudanças que serão aplicadas
        log "=== MUDANÇAS QUE SERÃO APLICADAS ==="
        cat database_changes.sql
        log "=== FIM DAS MUDANÇAS ==="
        
        # Criar arquivo temporário com script completo
        temp_script=$(mktemp)
        {
            cat database_changes.sql
            echo "$insert"
        } > "$temp_script"
        
        # Aplicar mudanças no banco
        log "Aplicando mudanças no banco de dados..."
        if PGPASSWORD="$DB_PASSWORD" psql --host="$host_banco" --username="$DB_USER" --dbname="$banco" -f "$temp_script"; then
            log "✅ Banco de dados atualizado com sucesso!"
            log "Versão aplicada: $tag_version"
        else
            error "❌ Erro ao atualizar banco de dados."
            rm -f "$temp_script"
            exit 1
        fi
        
        # Limpar arquivo temporário
        rm -f "$temp_script"
        
    else
        error "❌ Erro ao recuperar script da versão atual do banco de dados."
        exit 1
    fi
else
    log "ℹ️  Operação não realizada."
    log "A versão atualmente implantada no banco ($versao_banco)"
    log "é a mesma informada na Build ($tag_version)."
fi

log "=== DATABASE DEPLOYMENT COMPLETED ==="