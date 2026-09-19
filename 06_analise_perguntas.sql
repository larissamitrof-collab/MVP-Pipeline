-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 06 - ANÁLISE: respondendo às perguntas de negócio
-- MAGIC
-- MAGIC **Problema:** o setor de manutenção gerencia dezenas de milhares de ordens de manutenção (OM) por ano e precisa entender
-- MAGIC *onde está o esforço*, *o que está ficando para trás* e *quanto tempo as manutenções levam*, para planejar equipes e priorizar equipamentos.
-- MAGIC
-- MAGIC **Perguntas de negócio**
-- MAGIC 1. Qual é a composição da carga de trabalho por grupo de manutenção e por mês? Qual a proporção de preventivas x corretivas?
-- MAGIC 2. Quais classes de equipamento concentram mais OMs corretivas (candidatas a "problemáticas")?
-- MAGIC 3. Qual a taxa de conclusão das OMs por grupo e por tipo? Onde estão as suspensas e não iniciadas (backlog)?
-- MAGIC 4. Quanto tempo as manutenções levam (mediana e média) por grupo e por tipo?
-- MAGIC 5. Como evoluíram, mês a mês, o volume, a taxa de conclusão e as corretivas emergenciais?
-- MAGIC
-- MAGIC **Como criar os gráficos:** depois de rodar uma consulta, clique em **+ > Visualization** na aba de resultados
-- MAGIC (ao lado de "Table"), escolha o tipo de gráfico (barras, linhas...) e salve. Tire um *screenshot* do gráfico e/ou da tabela para o relatório.
-- MAGIC
-- MAGIC **Regra de ouro:** todas as análises usam a camada **Gold**. Data de referência = `data_inicio_original`.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pergunta 1 - Composição da carga de trabalho

-- COMMAND ----------

-- 1a) Quantidade de OMs por mês e por grupo (gráfico sugerido: barras empilhadas, x = ano_mes, série = grupo_manutencao)
SELECT d.ano_mes, t.grupo_manutencao, COUNT(*) AS qtd_om
FROM workspace.gold.fato_ordem_manutencao f
JOIN workspace.gold.dim_data             d ON f.data_inicio_original = d.data
JOIN workspace.gold.dim_tipo_manutencao  t ON f.tipo_manutencao      = t.tipo_manutencao
GROUP BY d.ano_mes, t.grupo_manutencao
ORDER BY d.ano_mes, t.grupo_manutencao;

-- COMMAND ----------

-- 1b) Proporção de cada grupo no total (gráfico sugerido: pizza ou barras)
SELECT
  t.grupo_manutencao,
  COUNT(*)                                            AS qtd_om,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS pct_do_total
FROM workspace.gold.fato_ordem_manutencao f
JOIN workspace.gold.dim_tipo_manutencao t ON f.tipo_manutencao = t.tipo_manutencao
GROUP BY t.grupo_manutencao
ORDER BY qtd_om DESC;
-- Esperado: PREVENTIVA/INSPEÇÃO 13621 (52,7%) | CORRETIVA 9486 (36,7%) | APOIO/ADMINISTRATIVO 1746 (6,7%) | PROJETOS/MELHORIAS 1019 (3,9%)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pergunta 2 - Classes de equipamento com mais OMs corretivas
-- MAGIC A "classe" `PREDIAL` (manutenção predial geral) não é um equipamento físico, por isso é analisada à parte na consulta 2b.

-- COMMAND ----------

-- 2a) Top 10 classes de equipamento por quantidade de OMs corretivas (gráfico sugerido: barras horizontais)
SELECT
  e.classe_equipamento,
  e.nome_classe,
  COUNT(*)                                                                    AS total_om,
  SUM(CASE WHEN t.grupo_manutencao = 'CORRETIVA' THEN 1 ELSE 0 END)           AS qtd_corretivas,
  SUM(CASE WHEN f.tipo_manutencao = 'CORRETIVA EMERGENCIAL' THEN 1 ELSE 0 END) AS qtd_emergenciais,
  ROUND(100.0 * SUM(CASE WHEN t.grupo_manutencao = 'CORRETIVA' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_corretiva
FROM workspace.gold.fato_ordem_manutencao f
JOIN workspace.gold.dim_equipamento     e ON f.cod_equipamento = e.cod_equipamento
JOIN workspace.gold.dim_tipo_manutencao t ON f.tipo_manutencao = t.tipo_manutencao
WHERE e.classe_equipamento <> 'PREDIAL'
GROUP BY e.classe_equipamento, e.nome_classe
ORDER BY qtd_corretivas DESC
LIMIT 10;
-- Esperado (topo): FAC/FANCOIL 803 | AUT/AUTOCLAVE 396 | CFR/CÂMARA FRIA 208 | ARS/AR CONDICIONADO SPLIT 204 | CPA 201 | FRE 195 | PUF 175 ...

-- COMMAND ----------

-- 2b) Manutenção predial (classe PREDIAL): quanto pesa nas corretivas?
SELECT
  SUM(CASE WHEN e.classe_equipamento = 'PREDIAL' THEN 1 ELSE 0 END)                     AS corretivas_prediais,
  COUNT(*)                                                                              AS corretivas_total,
  ROUND(100.0 * SUM(CASE WHEN e.classe_equipamento = 'PREDIAL' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_predial_nas_corretivas
FROM workspace.gold.fato_ordem_manutencao f
JOIN workspace.gold.dim_equipamento     e ON f.cod_equipamento = e.cod_equipamento
JOIN workspace.gold.dim_tipo_manutencao t ON f.tipo_manutencao = t.tipo_manutencao
WHERE t.grupo_manutencao = 'CORRETIVA';
-- Esperado: 3917 de 9486 (41,3%).

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pergunta 3 - Taxa de conclusão e backlog

-- COMMAND ----------

-- 3a) Estado das OMs por grupo, em quantidade e percentual (gráfico sugerido: barras 100% empilhadas)
SELECT
  t.grupo_manutencao,
  COUNT(*)                                                                         AS total_om,
  SUM(CASE WHEN f.estado_om = 'TERMINADA'    THEN 1 ELSE 0 END)                    AS terminadas,
  SUM(CASE WHEN f.estado_om = 'INICIADA'     THEN 1 ELSE 0 END)                    AS iniciadas,
  SUM(CASE WHEN f.estado_om = 'NÃO INICIADA' THEN 1 ELSE 0 END)                    AS nao_iniciadas,
  SUM(CASE WHEN f.estado_om = 'SUSPENSA'     THEN 1 ELSE 0 END)                    AS suspensas,
  ROUND(100.0 * SUM(CASE WHEN f.estado_om = 'TERMINADA' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_terminadas
FROM workspace.gold.fato_ordem_manutencao f
JOIN workspace.gold.dim_tipo_manutencao t ON f.tipo_manutencao = t.tipo_manutencao
GROUP BY t.grupo_manutencao
ORDER BY pct_terminadas;
-- Esperado: PROJETOS/MELHORIAS 76,2% | CORRETIVA 84,6% | APOIO/ADMIN 97,3% | PREVENTIVA/INSPEÇÃO 98,4%

-- COMMAND ----------

-- 3b) Mesma visão, por tipo de manutenção (os tipos com menor conclusão indicam onde está o gargalo)
SELECT
  f.tipo_manutencao,
  COUNT(*)                                                                         AS total_om,
  SUM(CASE WHEN f.estado_om = 'SUSPENSA'     THEN 1 ELSE 0 END)                    AS suspensas,
  SUM(CASE WHEN f.estado_om = 'NÃO INICIADA' THEN 1 ELSE 0 END)                    AS nao_iniciadas,
  ROUND(100.0 * SUM(CASE WHEN f.estado_om = 'TERMINADA' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_terminadas
FROM workspace.gold.fato_ordem_manutencao f
GROUP BY f.tipo_manutencao
ORDER BY pct_terminadas;
-- Esperado (menores): APOIO A PROJETOS 57,5% | MODIFICAÇÃO/MELHORIA 70,6% | INSTALAÇÃO 78,0% | CORRETIVA PLANEJADA 83,6%

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pergunta 4 - Tempo de execução
-- MAGIC Usa apenas OMs **terminadas e sem inconsistência de datas** (coluna `duracao_dias` preenchida). Mostramos a mediana ao lado da média porque há outliers (ver notebook 02).

-- COMMAND ----------

-- 4a) Duração por grupo (gráfico sugerido: barras comparando mediana e média)
SELECT
  t.grupo_manutencao,
  COUNT(f.duracao_dias)                  AS oms_com_duracao,
  percentile(f.duracao_dias, 0.5)        AS mediana_dias,
  ROUND(AVG(f.duracao_dias), 1)          AS media_dias,
  MAX(f.duracao_dias)                    AS maximo_dias
FROM workspace.gold.fato_ordem_manutencao f
JOIN workspace.gold.dim_tipo_manutencao t ON f.tipo_manutencao = t.tipo_manutencao
GROUP BY t.grupo_manutencao
ORDER BY mediana_dias DESC;
-- Esperado: PREVENTIVA/INSPEÇÃO mediana 6 (média 9,4) | PROJETOS/MELHORIAS 5 (11,8) | CORRETIVA 2 (9,5) | APOIO/ADMIN 2 (5,6)

-- COMMAND ----------

-- 4b) Duração por tipo de manutenção
SELECT
  f.tipo_manutencao,
  COUNT(f.duracao_dias)                  AS oms_com_duracao,
  percentile(f.duracao_dias, 0.5)        AS mediana_dias,
  ROUND(AVG(f.duracao_dias), 1)          AS media_dias,
  MAX(f.duracao_dias)                    AS maximo_dias
FROM workspace.gold.fato_ordem_manutencao f
GROUP BY f.tipo_manutencao
ORDER BY mediana_dias DESC, oms_com_duracao DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pergunta 5 - Evolução mensal

-- COMMAND ----------

-- 5a) Volume e taxa de conclusão por mês (gráfico sugerido: barras para total_om + linha para pct_terminadas)
SELECT
  d.ano_mes,
  COUNT(*)                                                                         AS total_om,
  SUM(CASE WHEN f.estado_om = 'TERMINADA' THEN 1 ELSE 0 END)                       AS terminadas,
  ROUND(100.0 * SUM(CASE WHEN f.estado_om = 'TERMINADA' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_terminadas
FROM workspace.gold.fato_ordem_manutencao f
JOIN workspace.gold.dim_data d ON f.data_inicio_original = d.data
GROUP BY d.ano_mes
ORDER BY d.ano_mes;
-- Esperado: jan 97,1% | fev 96,1% | mar 94,9% | abr 95,6% | mai 95,1% | jun 92,2% | jul 89,4% | ago 79,1%

-- COMMAND ----------

-- 5b) Corretivas emergenciais por mês (gráfico sugerido: linha)
SELECT d.ano_mes, COUNT(*) AS qtd_emergenciais
FROM workspace.gold.fato_ordem_manutencao f
JOIN workspace.gold.dim_data d ON f.data_inicio_original = d.data
WHERE f.tipo_manutencao = 'CORRETIVA EMERGENCIAL'
GROUP BY d.ano_mes
ORDER BY d.ano_mes;
-- Esperado: jan 230 | fev 175 | mar 140 | abr 121 | mai 129 | jun 133 | jul 141 | ago 171

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Cuidados na interpretação (para a discussão do relatório)
-- MAGIC - **Meses recentes parecem "piores" por natureza:** OMs abertas em agosto ainda estão em andamento, então a taxa de conclusão de agosto (79%) não é comparável à de janeiro (97%).
-- MAGIC - **Duração pela data de início *original*:** se uma OM foi reprogramada, a duração inclui a espera.
-- MAGIC - **OMs com datas inconsistentes** (669) ficam de fora da duração; elas continuam nas contagens.
-- MAGIC - **Agrupamento de tipos** (preventiva, corretiva, projetos, apoio) é uma decisão de modelagem: outro agrupamento mudaria os percentuais.
