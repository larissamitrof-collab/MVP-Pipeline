-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 04 - Camada GOLD: modelagem dimensional (ETL - etapa "Load" final)
-- MAGIC
-- MAGIC **Objetivo:** organizar os dados limpos num **Esquema Estrela (Star Schema)** para responder às perguntas de negócio de forma simples e rápida.
-- MAGIC
-- MAGIC **O que é um esquema estrela?** Uma tabela central de **fatos** (os "eventos" que queremos contar/medir) cercada por
-- MAGIC tabelas de **dimensões** (o "contexto": quem, o quê, quando).
-- MAGIC
-- MAGIC ```
-- MAGIC                 dim_tipo_manutencao
-- MAGIC                          |
-- MAGIC dim_equipamento --- fato_ordem_manutencao --- dim_data
-- MAGIC ```
-- MAGIC
-- MAGIC | Tabela | Granularidade (1 linha = ...) | Papel |
-- MAGIC |---|---|---|
-- MAGIC | `fato_ordem_manutencao` | 1 ordem de manutenção (OM) | Fato: medidas (duração) e situação (estado) de cada OM |
-- MAGIC | `dim_equipamento` | 1 código de equipamento | Contexto: qual equipamento e de qual classe |
-- MAGIC | `dim_tipo_manutencao` | 1 tipo de manutenção | Contexto: tipo e grupo (preventiva, corretiva...) |
-- MAGIC | `dim_data` | 1 dia do calendário | Contexto: ano, mês, trimestre, dia da semana |
-- MAGIC
-- MAGIC **Decisão de modelagem:** a `tag` fica na tabela fato (e não na dimensão de equipamento), porque no diagnóstico
-- MAGIC vimos que 181 equipamentos aparecem com mais de uma tag. Usamos as chaves naturais (código do equipamento, número da OM)
-- MAGIC em vez de chaves artificiais, por simplicidade no MVP.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Dimensão: equipamento
-- MAGIC Uma linha por código de equipamento. O nome legível da **classe** (ex.: `AUT` -> `AUTOCLAVE`) é o nome mais frequente entre os equipamentos daquela classe.

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.gold.dim_equipamento
COMMENT 'Dimensão de equipamentos: 1 linha por código de equipamento.'
AS
WITH eq AS (
  SELECT
    equipamento                    AS cod_equipamento,
    MAX(nome_equipamento)          AS nome_equipamento,     -- 1 nome por código (validado no notebook 02)
    MAX(classe_equipamento)        AS classe_equipamento
  FROM workspace.silver.om_manutencao
  GROUP BY equipamento
),
freq AS (   -- quantas OMs cada nome tem dentro da classe
  SELECT classe_equipamento, nome_equipamento, COUNT(*) AS qtd
  FROM workspace.silver.om_manutencao
  GROUP BY classe_equipamento, nome_equipamento
),
rank_nome AS (   -- o nome mais frequente da classe vira o "nome da classe"
  SELECT classe_equipamento, nome_equipamento AS nome_classe,
         ROW_NUMBER() OVER (PARTITION BY classe_equipamento ORDER BY qtd DESC, nome_equipamento) AS rn
  FROM freq
)
SELECT eq.cod_equipamento, eq.nome_equipamento, eq.classe_equipamento, r.nome_classe
FROM eq
LEFT JOIN rank_nome r ON eq.classe_equipamento = r.classe_equipamento AND r.rn = 1;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Dimensão: tipo de manutenção
-- MAGIC Agrupa os 16 tipos em 4 grupos de negócio. **Este agrupamento é uma decisão de modelagem que você deve revisar com seu conhecimento da área.**

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.gold.dim_tipo_manutencao
COMMENT 'Dimensão de tipos de manutenção com agrupamento de negócio (preventiva, corretiva, projetos, apoio).'
AS
SELECT * FROM VALUES
  ('PREVENTIVA',                         'PREVENTIVA/INSPEÇÃO'),
  ('INSPEÇÃO',                           'PREVENTIVA/INSPEÇÃO'),
  ('ROTEIRO DE INSPEÇÃO',                'PREVENTIVA/INSPEÇÃO'),
  ('LUBRIFICAÇÃO',                       'PREVENTIVA/INSPEÇÃO'),
  ('CALIBRAÇÃO',                         'PREVENTIVA/INSPEÇÃO'),
  ('CORRETIVA PLANEJADA',                'CORRETIVA'),
  ('CORRETIVA EMERGENCIAL',              'CORRETIVA'),
  ('MODIFICAÇÃO/MELHORIA',               'PROJETOS/MELHORIAS'),
  ('APOIO A PROJETOS',                   'PROJETOS/MELHORIAS'),
  ('INSTALAÇÃO',                         'PROJETOS/MELHORIAS'),
  ('COMISSIONAMENTO/DESCOMISSIONAMENTO', 'PROJETOS/MELHORIAS'),
  ('LEVANTAMENTO TÉCNICO',               'PROJETOS/MELHORIAS'),
  ('QUALIFICAÇÃO',                       'PROJETOS/MELHORIAS'),
  ('ADMINISTRAÇÃO DE USUÁRIOS',          'APOIO/ADMINISTRATIVO'),
  ('APOIO OPERACIONAL',                  'APOIO/ADMINISTRATIVO'),
  ('TREINAMENTO',                        'APOIO/ADMINISTRATIVO')
AS t(tipo_manutencao, grupo_manutencao);

-- COMMAND ----------

-- Teste: existe algum tipo na Silver que ficou SEM grupo? (esperado: 0 linhas)
SELECT DISTINCT s.tipo_manutencao
FROM workspace.silver.om_manutencao s
LEFT JOIN workspace.gold.dim_tipo_manutencao d ON s.tipo_manutencao = d.tipo_manutencao
WHERE d.tipo_manutencao IS NULL;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Dimensão: data (calendário)
-- MAGIC Gerada automaticamente: uma linha para cada dia de 2026 e 2027.

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.gold.dim_data
COMMENT 'Dimensão calendário: 1 linha por dia (2026-2027).'
AS
SELECT
  d                                                                                   AS data,
  year(d)                                                                             AS ano,
  month(d)                                                                            AS mes,
  element_at(array('Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho',
                   'Agosto','Setembro','Outubro','Novembro','Dezembro'), month(d))    AS nome_mes,
  date_format(d, 'yyyy-MM')                                                           AS ano_mes,
  quarter(d)                                                                          AS trimestre,
  element_at(array('Domingo','Segunda','Terça','Quarta','Quinta','Sexta','Sábado'),
             dayofweek(d))                                                            AS dia_semana
FROM (SELECT explode(sequence(DATE'2026-01-01', DATE'2027-12-31', INTERVAL 1 DAY)) AS d);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Fato: ordem de manutenção
-- MAGIC Uma linha por OM, com as chaves para as dimensões, as datas, o estado, a duração e os sinalizadores de qualidade.

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.gold.fato_ordem_manutencao
COMMENT 'Fato: 1 linha por ordem de manutenção (OM), jan-ago/2026.'
AS
SELECT
  ordem,                                   -- chave da OM
  equipamento          AS cod_equipamento, -- -> dim_equipamento
  tipo_manutencao,                         -- -> dim_tipo_manutencao
  data_inicio_original,                    -- -> dim_data (data de referência das análises)
  tag                  AS tag_local,
  estado_om,
  data_manutencao,
  data_termino,
  duracao_dias,
  flag_ano_corrigido,
  flag_termino_antes_inicio,
  flag_manutencao_fora_2026,
  flag_tag_ausente
FROM workspace.silver.om_manutencao;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Validações da Gold (integridade do modelo)

-- COMMAND ----------

-- G1: reconciliação de volumes ao longo do pipeline (esperado: 25872 nos três)
SELECT
  (SELECT COUNT(*) FROM workspace.bronze.om_manutencao_raw)      AS bronze,
  (SELECT COUNT(*) FROM workspace.silver.om_manutencao)          AS silver,
  (SELECT COUNT(*) FROM workspace.gold.fato_ordem_manutencao)    AS gold_fato;

-- COMMAND ----------

-- G2: integridade referencial - toda OM encontra seu equipamento, tipo e data? (esperado: 0, 0, 0)
SELECT
  SUM(CASE WHEN e.cod_equipamento  IS NULL THEN 1 ELSE 0 END) AS oms_sem_equipamento,
  SUM(CASE WHEN t.tipo_manutencao  IS NULL THEN 1 ELSE 0 END) AS oms_sem_tipo,
  SUM(CASE WHEN d.data             IS NULL THEN 1 ELSE 0 END) AS oms_sem_data
FROM workspace.gold.fato_ordem_manutencao f
LEFT JOIN workspace.gold.dim_equipamento    e ON f.cod_equipamento      = e.cod_equipamento
LEFT JOIN workspace.gold.dim_tipo_manutencao t ON f.tipo_manutencao     = t.tipo_manutencao
LEFT JOIN workspace.gold.dim_data           d ON f.data_inicio_original = d.data;

-- COMMAND ----------

-- G3: a chave da fato é única? (esperado: 25872 linhas e 25872 ordens distintas)
SELECT COUNT(*) AS linhas, COUNT(DISTINCT ordem) AS ordens_distintas FROM workspace.gold.fato_ordem_manutencao;

-- COMMAND ----------

-- G4: tamanho de cada tabela do modelo
SELECT 'fato_ordem_manutencao' AS tabela, COUNT(*) AS linhas FROM workspace.gold.fato_ordem_manutencao   -- 25872
UNION ALL SELECT 'dim_equipamento',       COUNT(*) FROM workspace.gold.dim_equipamento                     -- 7221
UNION ALL SELECT 'dim_tipo_manutencao',   COUNT(*) FROM workspace.gold.dim_tipo_manutencao                 -- 16
UNION ALL SELECT 'dim_data',              COUNT(*) FROM workspace.gold.dim_data;                           -- 730
