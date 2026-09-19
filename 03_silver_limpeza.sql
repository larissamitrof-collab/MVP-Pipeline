-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 03 - Camada SILVER: limpeza e padronização (ETL - etapa "Transform")
-- MAGIC
-- MAGIC **Objetivo:** transformar o dado bruto (Bronze) em um dado **confiável**: com tipos corretos, textos padronizados
-- MAGIC e problemas de qualidade tratados ou sinalizados.
-- MAGIC
-- MAGIC **Fluxo:** `bronze.om_manutencao_raw`  ->  *(este notebook)*  ->  `silver.om_manutencao`
-- MAGIC
-- MAGIC ## Transformações realizadas (documentação exigida pelo trabalho)
-- MAGIC | # | Transformação | Por que foi feita | Impacto nos dados |
-- MAGIC |---|---|---|---|
-- MAGIC | T1 | `try_cast` de `linha` e `ordem` para número | Identificadores eram texto | Tipos INT e BIGINT; falha de conversão vira NULL, sem derrubar o pipeline |
-- MAGIC | T2 | `UPPER(TRIM())` em equipamento, nome, tag, tipo e estado | `predial` e `PREDIAL` eram contados como equipamentos diferentes | 7.608 -> 7.221 códigos de equipamento distintos |
-- MAGIC | T3 | Texto vazio vira NULL (`NULLIF`) | Vazio e NULL significam a mesma coisa: "sem valor" | Padroniza a ausência de valor |
-- MAGIC | T4 | Correção do ano `00xx` -> `20xx` nas datas | `28/04/0026` é erro de digitação (início em 17/04/2026) | 1 linha corrigida, marcada em `flag_ano_corrigido` |
-- MAGIC | T5 | `try_to_date(..., 'dd/MM/yyyy')` nas 3 colunas de data | Datas estavam como texto | Tipo DATE: permite cálculos e ordenação correta |
-- MAGIC | T6 | Colunas de sinalização (`flag_*`) | Problemas que NÃO podemos corrigir com certeza são sinalizados, não apagados | 669 / 461 / 7 linhas sinalizadas |
-- MAGIC | T7 | `duracao_dias` = término - início (só OM terminada e coerente) | Métrica necessária para a pergunta 4 | 23.238 OMs com duração |
-- MAGIC | T8 | `classe_equipamento` = letras iniciais do código (ex.: `AUT114` -> `AUT`) | Agrupar equipamentos do mesmo tipo | 225 classes |
-- MAGIC | T9 | `mes_referencia` = 1º dia do mês do início original | Facilitar análises mensais | 8 meses (jan-ago/2026) |
-- MAGIC | T10 | Deduplicação por `ordem` (`QUALIFY ROW_NUMBER()`) | Garantir 1 linha por OM caso a fonte mude | 0 duplicatas removidas hoje |
-- MAGIC
-- MAGIC > Princípio: **não apagamos linhas**. Todo problema é corrigido (quando óbvio) ou sinalizado (quando duvidoso).

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.silver.om_manutencao
COMMENT 'Ordens de manutenção limpas e tipadas (1 linha por OM). Origem: bronze.om_manutencao_raw.'
AS
WITH limpa AS (
  SELECT
    try_cast(b.linha AS INT)                            AS linha_origem,                -- T1
    try_cast(b.ordem AS BIGINT)                         AS ordem,                       -- T1
    NULLIF(UPPER(TRIM(b.equipamento)), '')              AS equipamento,                 -- T2, T3
    NULLIF(UPPER(TRIM(b.nome_equipamento)), '')         AS nome_equipamento,
    NULLIF(UPPER(TRIM(b.tag)), '')                      AS tag,
    NULLIF(UPPER(TRIM(b.tipo_manutencao)), '')          AS tipo_manutencao,
    NULLIF(UPPER(TRIM(b.estado_om)), '')                AS estado_om,
    -- T4 + T5: corrige o ano 00xx e converte texto -> data
    try_to_date(regexp_replace(TRIM(b.data_manutencao),      '/00([0-9]{2})$', '/20$1'), 'dd/MM/yyyy') AS data_manutencao,
    try_to_date(regexp_replace(TRIM(b.data_termino),         '/00([0-9]{2})$', '/20$1'), 'dd/MM/yyyy') AS data_termino,
    try_to_date(regexp_replace(TRIM(b.data_inicio_original), '/00([0-9]{2})$', '/20$1'), 'dd/MM/yyyy') AS data_inicio_original,
    -- T6: sinaliza se alguma data teve o ano corrigido
    (coalesce(b.data_manutencao      RLIKE '/00[0-9]{2}$', false)
      OR coalesce(b.data_termino         RLIKE '/00[0-9]{2}$', false)
      OR coalesce(b.data_inicio_original RLIKE '/00[0-9]{2}$', false)) AS flag_ano_corrigido,
    b._ingerido_em
  FROM workspace.bronze.om_manutencao_raw b
),
dedup AS (
  SELECT * FROM limpa
  QUALIFY ROW_NUMBER() OVER (PARTITION BY ordem ORDER BY linha_origem) = 1              -- T10
)
SELECT
  linha_origem,
  ordem,
  equipamento,
  nome_equipamento,
  tag,
  tipo_manutencao,
  estado_om,
  data_manutencao,
  data_termino,
  data_inicio_original,
  -- T7: duração em dias (só faz sentido para OM terminada e com datas coerentes)
  CASE WHEN estado_om = 'TERMINADA' AND data_termino >= data_inicio_original
       THEN datediff(data_termino, data_inicio_original) END          AS duracao_dias,
  regexp_extract(equipamento, '^[A-Z]+', 0)                           AS classe_equipamento,   -- T8
  trunc(data_inicio_original, 'MM')                                   AS mes_referencia,       -- T9
  -- T6: sinalizações de qualidade
  flag_ano_corrigido,
  coalesce(data_termino < data_inicio_original, false)                AS flag_termino_antes_inicio,
  coalesce(year(data_manutencao) <> 2026, false)                      AS flag_manutencao_fora_2026,
  (tag IS NULL)                                                       AS flag_tag_ausente,
  _ingerido_em
FROM dedup;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Validação da Silver (comprova que os tratamentos funcionaram)

-- COMMAND ----------

-- V1: nenhuma linha foi perdida entre Bronze e Silver (esperado: 25872 nas duas)
SELECT
  (SELECT COUNT(*) FROM workspace.bronze.om_manutencao_raw) AS linhas_bronze,
  (SELECT COUNT(*) FROM workspace.silver.om_manutencao)     AS linhas_silver;

-- COMMAND ----------

-- V2: os tipos das colunas agora estão corretos (datas como date, ordem como bigint...)
DESCRIBE TABLE workspace.silver.om_manutencao;

-- COMMAND ----------

-- V3: nenhuma data ficou nula por falha de conversão (só data_termino pode ter NULL, e apenas em OM não terminada)
SELECT
  SUM(CASE WHEN data_manutencao      IS NULL THEN 1 ELSE 0 END) AS nulos_data_manutencao,       -- esperado 0
  SUM(CASE WHEN data_inicio_original IS NULL THEN 1 ELSE 0 END) AS nulos_data_inicio_original,  -- esperado 0
  SUM(CASE WHEN data_termino IS NULL AND estado_om = 'TERMINADA' THEN 1 ELSE 0 END) AS terminada_sem_data, -- esperado 0
  SUM(CASE WHEN data_termino IS NULL THEN 1 ELSE 0 END)         AS nulos_data_termino            -- esperado 1965
FROM workspace.silver.om_manutencao;

-- COMMAND ----------

-- V4: contagem de cada sinalização de qualidade
SELECT
  SUM(CASE WHEN flag_ano_corrigido          THEN 1 ELSE 0 END) AS ano_corrigido,           -- esperado 1
  SUM(CASE WHEN flag_termino_antes_inicio   THEN 1 ELSE 0 END) AS termino_antes_inicio,    -- esperado 669
  SUM(CASE WHEN flag_manutencao_fora_2026   THEN 1 ELSE 0 END) AS manutencao_fora_2026,    -- esperado 461
  SUM(CASE WHEN flag_tag_ausente            THEN 1 ELSE 0 END) AS tag_ausente,             -- esperado 7
  SUM(CASE WHEN duracao_dias IS NOT NULL    THEN 1 ELSE 0 END) AS oms_com_duracao          -- esperado 23238
FROM workspace.silver.om_manutencao;

-- COMMAND ----------

-- V5: padronização de texto funcionou? (esperado: 0 linhas com letras minúsculas)
SELECT COUNT(*) AS linhas_com_minuscula
FROM workspace.silver.om_manutencao
WHERE equipamento <> UPPER(equipamento) OR nome_equipamento <> UPPER(nome_equipamento) OR tag <> UPPER(tag);

-- COMMAND ----------

-- V6: equipamentos distintos (esperado: 7221) e classes de equipamento (esperado: 225)
SELECT COUNT(DISTINCT equipamento) AS equipamentos_distintos, COUNT(DISTINCT classe_equipamento) AS classes_distintas
FROM workspace.silver.om_manutencao;

-- COMMAND ----------

-- V7: a linha que tinha o ano 0026 foi corrigida?
SELECT linha_origem, ordem, data_manutencao, data_termino, data_inicio_original, flag_ano_corrigido
FROM workspace.silver.om_manutencao
WHERE flag_ano_corrigido;
-- Esperado: linha 1, com 2026-04-28 nas duas datas.
