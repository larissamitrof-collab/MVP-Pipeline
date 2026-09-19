-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 01 - Camada BRONZE: ingestão do dado bruto (ETL - etapa "Extract" + "Load")
-- MAGIC
-- MAGIC **Objetivo:** ler o CSV do volume e gravá-lo como **tabela Delta** *sem alterar nenhum valor*.
-- MAGIC
-- MAGIC **Por que não corrigir nada aqui?** A camada Bronze é o "cofre de evidências": se algo der errado
-- MAGIC nas camadas seguintes, sempre podemos voltar aqui e ver o que chegou originalmente.
-- MAGIC
-- MAGIC **Decisões técnicas**
-- MAGIC 1. `inferColumnTypes => false`: o Databricks NÃO tenta adivinhar tipos. Tudo entra como texto (STRING).
-- MAGIC    Assim, uma data digitada errada (ex.: `28/04/0026`) não é perdida nem convertida sem querermos.
-- MAGIC 2. Adicionamos 2 colunas de **controle** (metadados): `_arquivo_origem` (de qual arquivo veio) e
-- MAGIC    `_ingerido_em` (quando foi carregado). Isso dá **rastreabilidade**.
-- MAGIC 3. A tabela é **Delta** (formato padrão do Databricks): garante transações ACID e permite "voltar no tempo".
-- MAGIC
-- MAGIC **Resultado esperado:** tabela `workspace.bronze.om_manutencao_raw` com **25.872 linhas**.

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.bronze.om_manutencao_raw
COMMENT 'Ordens de manutenção (OM) de jan-ago/2026, exatamente como exportadas do sistema de manutenção. Todas as colunas em texto.'
AS
SELECT
  *,                                       -- todas as colunas originais do CSV
  _metadata.file_path  AS _arquivo_origem, -- metadado: caminho do arquivo lido
  current_timestamp()  AS _ingerido_em     -- metadado: momento da carga
FROM read_files(
  '/Volumes/workspace/bronze/raw_files/om_manutencao_2026.csv',
  format            => 'csv',
  header            => true,    -- a 1ª linha do arquivo contém os nomes das colunas
  delimiter         => ',',
  encoding          => 'UTF-8', -- garante acentos corretos (INSPEÇÃO, MANUTENÇÃO...)
  inferColumnTypes  => false    -- mantém tudo como texto: nada de "adivinhação"
);

-- COMMAND ----------

-- Conferência 1: quantas linhas foram carregadas? (esperado: 25872, igual ao CSV sem o cabeçalho)
SELECT COUNT(*) AS total_linhas FROM workspace.bronze.om_manutencao_raw;

-- COMMAND ----------

-- Conferência 2: os tipos das colunas. Todas as colunas originais devem estar como string.
-- (a coluna _ingerido_em é timestamp de propósito; _rescued_data é criada automaticamente pelo Databricks
--  e guarda qualquer dado que "não coube" no formato - o esperado é que fique vazia)
DESCRIBE TABLE workspace.bronze.om_manutencao_raw;

-- COMMAND ----------

-- Conferência 3: uma amostra para "olhar" os dados brutos (note as datas como texto dd/MM/yyyy)
SELECT * FROM workspace.bronze.om_manutencao_raw LIMIT 10;

-- COMMAND ----------

-- Conferência 4: a coluna _rescued_data deve estar 100% vazia (nenhuma linha com problema de leitura)
SELECT COUNT(*) AS linhas_com_problema_de_leitura
FROM workspace.bronze.om_manutencao_raw
WHERE _rescued_data IS NOT NULL;
