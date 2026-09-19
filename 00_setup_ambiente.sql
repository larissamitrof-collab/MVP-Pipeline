-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 00 - Preparação do ambiente
-- MAGIC
-- MAGIC **O que este notebook faz:** garante que a "estrutura de pastas" do projeto existe no Databricks
-- MAGIC (catálogo, schemas e volume) e confere se o arquivo CSV está lá.
-- MAGIC
-- MAGIC **Vocabulário rápido**
-- MAGIC - **Catálogo (catalog):** a "gaveta maior". Aqui usamos o catálogo padrão chamado `workspace`.
-- MAGIC - **Schema:** uma "pasta" dentro do catálogo. Vamos usar 3, uma para cada camada da Arquitetura Medalhão: `bronze`, `silver` e `gold`.
-- MAGIC - **Volume:** um "HD na nuvem" para guardar arquivos (CSV, PDF...). Nosso CSV fica no volume `bronze.raw_files`.
-- MAGIC - **Tabela:** dados organizados em linhas e colunas, que podemos consultar com SQL.
-- MAGIC
-- MAGIC **Como executar:** clique em *Run all* (canto superior direito) ou execute célula por célula com `Shift + Enter`.

-- COMMAND ----------

-- Cria os 3 schemas (camadas) caso ainda não existam. "IF NOT EXISTS" evita erro se já existirem.
CREATE SCHEMA IF NOT EXISTS workspace.bronze COMMENT 'Camada Bronze: dado bruto, exatamente como chegou da fonte';
CREATE SCHEMA IF NOT EXISTS workspace.silver COMMENT 'Camada Silver: dado limpo, padronizado e tipado';
CREATE SCHEMA IF NOT EXISTS workspace.gold   COMMENT 'Camada Gold: dado modelado (esquema estrela) pronto para análise';

-- COMMAND ----------

-- Cria o volume onde o CSV fica guardado (se você já criou pela interface, este comando não faz nada).
CREATE VOLUME IF NOT EXISTS workspace.bronze.raw_files COMMENT 'Arquivos brutos recebidos da fonte (CSV de ordens de manutenção)';

-- COMMAND ----------

-- Lista os arquivos que estão no volume. Você deve ver: om_manutencao_2026.csv (~2,83 MB)
LIST '/Volumes/workspace/bronze/raw_files/';

-- COMMAND ----------

-- Mostra os schemas do catálogo workspace. Devem aparecer: bronze, silver, gold (além de default e information_schema).
SHOW SCHEMAS IN workspace;
