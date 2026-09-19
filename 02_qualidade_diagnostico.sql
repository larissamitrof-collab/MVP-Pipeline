-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 02 - Diagnóstico de QUALIDADE DE DADOS (sobre a camada Bronze)
-- MAGIC
-- MAGIC **Objetivo:** antes de limpar, precisamos *descobrir* o que está sujo. Este notebook só **mede** problemas
-- MAGIC (não altera nada). Os tratamentos são feitos no notebook `03_silver_limpeza`.
-- MAGIC
-- MAGIC Verificamos as 5 dimensões de qualidade pedidas no trabalho, para cada atributo:
-- MAGIC | Dimensão | Pergunta |
-- MAGIC |---|---|
-- MAGIC | **Completude** | Existem valores nulos ou vazios? Em que proporção? |
-- MAGIC | **Consistência** | Os valores seguem o padrão esperado (formato de data, maiúsculas/minúsculas, domínio)? |
-- MAGIC | **Unicidade** | Existem duplicatas onde não deveria haver? |
-- MAGIC | **Acurácia** | Os valores fazem sentido no mundo real (ex.: término antes do início)? |
-- MAGIC | **Outliers** | Existem valores extremos que podem distorcer médias? |
-- MAGIC
-- MAGIC > Dica: tire *screenshots* dos resultados de cada seção para o relatório final.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. COMPLETUDE - quantos valores vazios existem em cada coluna?
-- MAGIC Contamos como "vazio" tanto o NULL quanto o texto em branco (`''`).

-- COMMAND ----------

SELECT
  COUNT(*)                                                                             AS total_linhas,
  SUM(CASE WHEN linha                IS NULL OR TRIM(linha)                = '' THEN 1 ELSE 0 END) AS vazios_linha,
  SUM(CASE WHEN ordem                IS NULL OR TRIM(ordem)                = '' THEN 1 ELSE 0 END) AS vazios_ordem,
  SUM(CASE WHEN equipamento          IS NULL OR TRIM(equipamento)          = '' THEN 1 ELSE 0 END) AS vazios_equipamento,
  SUM(CASE WHEN nome_equipamento     IS NULL OR TRIM(nome_equipamento)     = '' THEN 1 ELSE 0 END) AS vazios_nome_equipamento,
  SUM(CASE WHEN tag                  IS NULL OR TRIM(tag)                  = '' THEN 1 ELSE 0 END) AS vazios_tag,
  SUM(CASE WHEN tipo_manutencao      IS NULL OR TRIM(tipo_manutencao)      = '' THEN 1 ELSE 0 END) AS vazios_tipo_manutencao,
  SUM(CASE WHEN data_manutencao      IS NULL OR TRIM(data_manutencao)      = '' THEN 1 ELSE 0 END) AS vazios_data_manutencao,
  SUM(CASE WHEN data_termino         IS NULL OR TRIM(data_termino)         = '' THEN 1 ELSE 0 END) AS vazios_data_termino,
  SUM(CASE WHEN data_inicio_original IS NULL OR TRIM(data_inicio_original) = '' THEN 1 ELSE 0 END) AS vazios_data_inicio_original,
  SUM(CASE WHEN estado_om            IS NULL OR TRIM(estado_om)            = '' THEN 1 ELSE 0 END) AS vazios_estado_om
FROM workspace.bronze.om_manutencao_raw;
-- Esperado: tag = 7 e data_termino = 1965. Todas as demais colunas = 0.

-- COMMAND ----------

-- Os 1965 vazios em data_termino são um PROBLEMA ou algo NORMAL?
-- Hipótese: uma OM que ainda não terminou naturalmente não tem data de término.
SELECT
  upper(estado_om)                                                     AS estado_om,
  COUNT(*)                                                             AS qtd_om,
  SUM(CASE WHEN data_termino IS NULL OR TRIM(data_termino) = '' THEN 1 ELSE 0 END) AS sem_data_termino
FROM workspace.bronze.om_manutencao_raw
GROUP BY upper(estado_om)
ORDER BY qtd_om DESC;
-- Esperado: TERMINADA tem 0 sem data de término; os demais estados têm 100% sem data. => vazio JUSTIFICÁVEL, não é erro.

-- COMMAND ----------

-- As 7 linhas sem tag: quais são?
SELECT linha, ordem, equipamento, nome_equipamento, tipo_manutencao, estado_om
FROM workspace.bronze.om_manutencao_raw
WHERE tag IS NULL OR TRIM(tag) = '';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. CONSISTÊNCIA - formato e padronização

-- COMMAND ----------

-- 2.1 As datas seguem o formato dd/MM/yyyy? E há anos "impossíveis" (ex.: 0026)?
SELECT 'data_manutencao' AS coluna,
       SUM(CASE WHEN data_manutencao IS NOT NULL AND NOT data_manutencao RLIKE '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN 1 ELSE 0 END) AS fora_do_formato,
       SUM(CASE WHEN data_manutencao RLIKE '/00[0-9]{2}$' THEN 1 ELSE 0 END) AS ano_impossivel_00xx
FROM workspace.bronze.om_manutencao_raw
UNION ALL
SELECT 'data_termino',
       SUM(CASE WHEN data_termino IS NOT NULL AND NOT data_termino RLIKE '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN 1 ELSE 0 END),
       SUM(CASE WHEN data_termino RLIKE '/00[0-9]{2}$' THEN 1 ELSE 0 END)
FROM workspace.bronze.om_manutencao_raw
UNION ALL
SELECT 'data_inicio_original',
       SUM(CASE WHEN data_inicio_original IS NOT NULL AND NOT data_inicio_original RLIKE '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN 1 ELSE 0 END),
       SUM(CASE WHEN data_inicio_original RLIKE '/00[0-9]{2}$' THEN 1 ELSE 0 END)
FROM workspace.bronze.om_manutencao_raw;
-- Esperado: fora_do_formato = 0 nas três; ano_impossivel_00xx = 1 em data_manutencao e 1 em data_termino (mesma linha).

-- COMMAND ----------

-- Qual é a linha com o ano impossível?
SELECT linha, ordem, equipamento, tipo_manutencao, data_manutencao, data_termino, data_inicio_original
FROM workspace.bronze.om_manutencao_raw
WHERE data_manutencao RLIKE '/00[0-9]{2}$' OR data_termino RLIKE '/00[0-9]{2}$' OR data_inicio_original RLIKE '/00[0-9]{2}$';
-- Esperado: linha 1, com 28/04/0026. O início original é 17/04/2026 => é claramente um erro de digitação de 2026.

-- COMMAND ----------

-- 2.2 Padronização de texto: valores que mudam ao passar para MAIÚSCULAS (ex.: "predial" x "PREDIAL")
SELECT 'equipamento' AS coluna,
       SUM(CASE WHEN equipamento <> upper(trim(equipamento)) THEN 1 ELSE 0 END) AS linhas_com_caixa_inconsistente,
       COUNT(DISTINCT equipamento)                                               AS distintos_original,
       COUNT(DISTINCT upper(trim(equipamento)))                                  AS distintos_padronizado
FROM workspace.bronze.om_manutencao_raw
UNION ALL
SELECT 'nome_equipamento',
       SUM(CASE WHEN nome_equipamento <> upper(trim(nome_equipamento)) THEN 1 ELSE 0 END),
       COUNT(DISTINCT nome_equipamento),
       COUNT(DISTINCT upper(trim(nome_equipamento)))
FROM workspace.bronze.om_manutencao_raw
UNION ALL
SELECT 'tag',
       SUM(CASE WHEN tag <> upper(trim(tag)) THEN 1 ELSE 0 END),
       COUNT(DISTINCT tag),
       COUNT(DISTINCT upper(trim(tag)))
FROM workspace.bronze.om_manutencao_raw;
-- Esperado: equipamento = 1006 linhas (7608 códigos distintos viram 7221 depois de padronizar);
--           nome_equipamento = 19 linhas (656 -> 656); tag = 29 linhas (1591 -> 1585).
-- Ou seja: o mesmo equipamento estava sendo contado como se fossem equipamentos diferentes.

-- COMMAND ----------

-- Exemplos concretos do problema de caixa:
SELECT equipamento, COUNT(*) AS qtd
FROM workspace.bronze.om_manutencao_raw
WHERE equipamento <> upper(equipamento)
GROUP BY equipamento
ORDER BY qtd DESC
LIMIT 10;

-- COMMAND ----------

-- 2.3 Domínio (valores permitidos) das colunas categóricas
SELECT 'tipo_manutencao' AS coluna, tipo_manutencao AS valor, COUNT(*) AS qtd FROM workspace.bronze.om_manutencao_raw GROUP BY tipo_manutencao
UNION ALL
SELECT 'estado_om', estado_om, COUNT(*) FROM workspace.bronze.om_manutencao_raw GROUP BY estado_om
ORDER BY coluna, qtd DESC;
-- Esperado: 16 tipos de manutenção e 4 estados (Terminada, Suspensa, Não Iniciada, Iniciada), sem variações de escrita.

-- COMMAND ----------

-- 2.4 Padrão do campo "ordem" (esperado: 9 dígitos numéricos) e do campo "tag"
SELECT
  SUM(CASE WHEN NOT ordem RLIKE '^[0-9]{9}$' THEN 1 ELSE 0 END) AS ordem_fora_do_padrao_9_digitos
FROM workspace.bronze.om_manutencao_raw;

-- COMMAND ----------

-- Formatos de tag encontrados (9 = dígito, A = letra). O padrão dominante é 9.999.9.9999.
SELECT
  regexp_replace(regexp_replace(upper(tag), '[0-9]', '9'), '[A-Z]', 'A') AS formato_tag,
  COUNT(*) AS qtd
FROM workspace.bronze.om_manutencao_raw
WHERE tag IS NOT NULL
GROUP BY 1
ORDER BY qtd DESC;
-- Esperado: 6 formatos. Variações (letra no lugar de dígito, ou 2 dígitos no 1º bloco) são raras e
-- plausíveis para um código de identificação técnica; por isso foram MANTIDAS (só padronizadas em maiúsculas).

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. UNICIDADE - duplicatas

-- COMMAND ----------

SELECT
  COUNT(*)                                            AS total_linhas,
  COUNT(DISTINCT ordem)                               AS ordens_distintas,
  COUNT(*) - COUNT(DISTINCT ordem)                    AS ordens_duplicadas
FROM workspace.bronze.om_manutencao_raw;
-- Esperado: 25872 linhas, 25872 ordens distintas, 0 duplicadas. O número da OM funciona como chave primária.

-- COMMAND ----------

-- Linhas 100% idênticas (ignorando o número da linha e os metadados de carga):
SELECT COUNT(*) AS grupos_de_linhas_identicas FROM (
  SELECT ordem, equipamento, nome_equipamento, tag, tipo_manutencao, data_manutencao, data_termino, data_inicio_original, estado_om
  FROM workspace.bronze.om_manutencao_raw
  GROUP BY ALL
  HAVING COUNT(*) > 1
);
-- Esperado: 0.

-- COMMAND ----------

-- Um mesmo código de equipamento tem sempre o mesmo nome? (regra necessária para criar a dimensão de equipamento)
SELECT COUNT(*) AS equipamentos_com_mais_de_um_nome FROM (
  SELECT upper(trim(equipamento)) AS equipamento
  FROM workspace.bronze.om_manutencao_raw
  GROUP BY upper(trim(equipamento))
  HAVING COUNT(DISTINCT upper(trim(nome_equipamento))) > 1
);
-- Esperado: 0. Ou seja: equipamento -> nome é uma relação 1 para 1.

-- COMMAND ----------

-- E o mesmo equipamento pode estar em mais de uma tag (local)?
SELECT COUNT(*) AS equipamentos_com_mais_de_uma_tag FROM (
  SELECT upper(trim(equipamento)) AS equipamento
  FROM workspace.bronze.om_manutencao_raw
  GROUP BY upper(trim(equipamento))
  HAVING COUNT(DISTINCT upper(trim(tag))) > 1
);
-- Esperado: 181. Portanto a TAG não é um atributo do equipamento: ela ficará na tabela fato (por ordem).

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. ACURÁCIA - os valores fazem sentido?
-- MAGIC Aqui convertemos as datas (já corrigindo o ano `00xx`) só para poder comparar.

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW vw_datas AS
SELECT
  ordem, tipo_manutencao, upper(estado_om) AS estado_om,
  try_to_date(regexp_replace(data_manutencao,      '/00([0-9]{2})$', '/20$1'), 'dd/MM/yyyy') AS data_manutencao,
  try_to_date(regexp_replace(data_termino,         '/00([0-9]{2})$', '/20$1'), 'dd/MM/yyyy') AS data_termino,
  try_to_date(regexp_replace(data_inicio_original, '/00([0-9]{2})$', '/20$1'), 'dd/MM/yyyy') AS data_inicio_original
FROM workspace.bronze.om_manutencao_raw;

-- COMMAND ----------

-- 4.1 Intervalo de cada data: faz sentido estar tudo em 2026?
SELECT 'data_inicio_original' AS coluna, MIN(data_inicio_original) AS minima, MAX(data_inicio_original) AS maxima FROM vw_datas
UNION ALL SELECT 'data_termino',   MIN(data_termino),   MAX(data_termino)   FROM vw_datas
UNION ALL SELECT 'data_manutencao', MIN(data_manutencao), MAX(data_manutencao) FROM vw_datas;
-- Esperado: início entre 01/01/2026 e 31/08/2026 (o recorte do arquivo).
--           término e manutenção têm datas de 2022, 2023, 2025 e até 2027 => suspeito.

-- COMMAND ----------

-- 4.2 Distribuição do ANO de cada data. Quase tudo deveria ser 2026.
SELECT year(data_manutencao) AS ano, COUNT(*) AS qtd_data_manutencao
FROM vw_datas GROUP BY year(data_manutencao) ORDER BY ano;
-- Esperado: 2022 (1), 2023 (3), 2024 (4), 2025 (439), 2026 (25410 + 1 corrigida = 25411), 2027 (14).

-- COMMAND ----------

-- 4.3 Término ANTES do início: fisicamente estranho
SELECT
  COUNT(*) AS oms_terminadas,
  SUM(CASE WHEN data_termino < data_inicio_original THEN 1 ELSE 0 END) AS termino_antes_do_inicio,
  ROUND(100.0 * SUM(CASE WHEN data_termino < data_inicio_original THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct
FROM vw_datas
WHERE data_termino IS NOT NULL;
-- Esperado: 669 casos (~2,8% das OMs terminadas).

-- COMMAND ----------

-- Exemplos: repare que muitas vezes só o ANO parece errado (ex.: término 22/04/2025 com início 22/04/2026)
SELECT ordem, tipo_manutencao, data_inicio_original, data_manutencao, data_termino,
       datediff(data_termino, data_inicio_original) AS dias
FROM vw_datas
WHERE data_termino < data_inicio_original
ORDER BY dias ASC
LIMIT 15;

-- COMMAND ----------

-- 4.4 Todas as OMs terminadas têm data de término, e nenhuma OM não terminada tem? (regra de negócio)
SELECT
  SUM(CASE WHEN estado_om = 'TERMINADA'  AND data_termino IS NULL     THEN 1 ELSE 0 END) AS terminada_sem_data,
  SUM(CASE WHEN estado_om <> 'TERMINADA' AND data_termino IS NOT NULL THEN 1 ELSE 0 END) AS nao_terminada_com_data
FROM vw_datas;
-- Esperado: 0 e 0. A regra de negócio é respeitada.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. OUTLIERS - duração das manutenções
-- MAGIC Duração = data de término - data de início original, só para OMs terminadas e sem inconsistência de datas.
-- MAGIC Usamos a regra do **IQR**: é outlier quem passa de `Q3 + 1,5 x (Q3 - Q1)`.

-- COMMAND ----------

WITH dur AS (
  SELECT datediff(data_termino, data_inicio_original) AS dias
  FROM vw_datas
  WHERE estado_om = 'TERMINADA' AND data_termino >= data_inicio_original
),
q AS (
  SELECT percentile(dias, 0.25) AS q1, percentile(dias, 0.75) AS q3 FROM dur
)
SELECT
  COUNT(*)                                        AS oms_com_duracao,
  MIN(dias)                                       AS minimo,
  ROUND(percentile(dias, 0.5), 1)                 AS mediana,
  ROUND(AVG(dias), 2)                             AS media,
  MAX(dias)                                       AS maximo,
  MAX(q.q3 + 1.5 * (q.q3 - q.q1))                 AS limite_outlier_iqr,
  SUM(CASE WHEN dias > q.q3 + 1.5 * (q.q3 - q.q1) THEN 1 ELSE 0 END) AS qtd_outliers
FROM dur CROSS JOIN q;
-- Esperado: 23238 OMs; mediana 4; média ~9,28; máximo 217; limite 28,5; ~1424 outliers (~6%).
-- Decisão: os outliers foram MANTIDOS (manutenções longas são reais, ex.: espera de peça) e,
-- nas análises, usamos a MEDIANA junto com a média, porque a mediana é pouco sensível a extremos.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Resumo dos problemas e tratamento (aplicado no notebook 03)
-- MAGIC | # | Dimensão | Problema detectado | Qtd | Tratamento na Silver |
-- MAGIC |---|---|---|---|---|
-- MAGIC | 1 | Completude | `data_termino` vazia | 1.965 | **Mantido como NULL** (100% são OMs não terminadas: comportamento esperado) |
-- MAGIC | 2 | Completude | `tag` vazia | 7 | Mantido NULL + coluna `flag_tag_ausente` |
-- MAGIC | 3 | Consistência | Ano impossível (`28/04/0026`) | 1 linha (2 campos) | Corrigido para 2026 + `flag_ano_corrigido` |
-- MAGIC | 4 | Consistência | Datas como texto `dd/MM/yyyy` | todas | Convertidas para o tipo DATE |
-- MAGIC | 5 | Consistência | Caixa alta/baixa (`predial` x `PREDIAL`) | equipamento 1.006 / nome 19 / tag 29 | `UPPER(TRIM())` em todos os textos |
-- MAGIC | 6 | Acurácia | Término antes do início | 669 | Mantido + `flag_termino_antes_inicio`; excluído do cálculo de duração |
-- MAGIC | 7 | Acurácia | `data_manutencao` fora de 2026 | 461 | Mantido + `flag_manutencao_fora_2026` (não usado como data de referência) |
-- MAGIC | 8 | Outliers | Duração > 28,5 dias | ~1.424 | Mantidos; análises usam mediana |
-- MAGIC | 9 | Unicidade | Duplicatas de OM | 0 | Nenhuma ação (deduplicação por `ordem` mantida no ETL por segurança) |
