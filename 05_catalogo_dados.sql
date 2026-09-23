-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 05 - CATÁLOGO DE DADOS (documentação no Unity Catalog)
-- MAGIC
-- MAGIC **Objetivo:** registrar, dentro do próprio Databricks, uma descrição para cada **tabela** e cada **coluna**.
-- MAGIC Depois de rodar este notebook, abra **Catalog > workspace > (schema) > (tabela)**: a aba *Overview* mostra as descrições
-- MAGIC e a aba *Lineage* mostra de onde cada tabela veio (linhagem dos dados, gerada automaticamente pelo Databricks).
-- MAGIC
-- MAGIC O **Unity Catalog** é o "catálogo de dados" do Databricks: ele guarda o dicionário de dados que o trabalho exige
-- MAGIC (descrição, tipo, domínio de valores e linhagem). Tipo e linhagem o Databricks preenche sozinho; a descrição e o domínio
-- MAGIC nós escrevemos abaixo. O catálogo completo em texto está em `docs/catalogo_dados.md`.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## workspace.bronze.om_manutencao_raw  (Bronze)

-- COMMAND ----------

COMMENT ON TABLE workspace.bronze.om_manutencao_raw IS 'Ordens de manutenção (OM) de janeiro a agosto de 2026, exatamente como exportadas do sistema de gestão de manutenção. Nenhum valor foi alterado; todas as colunas originais estão em texto. Granularidade: 1 linha por OM (25.872 linhas). Origem: arquivo om_manutencao_2026.csv, carregado no volume workspace.bronze.raw_files.';

COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.linha IS 'Número sequencial da linha no arquivo exportado. Domínio: Texto numérico de 1 a 25872. Linhagem: CSV: coluna linha (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.ordem IS 'Número da ordem de manutenção (OM), identificador único da OM. Domínio: Texto numérico de 9 dígitos (100050417 a 300157661). Linhagem: CSV: coluna ordem (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.equipamento IS 'Código do equipamento: letras da classe + número (ex.: AUT114 = autoclave 114). O código PREDIAL representa manutenção predial geral, sem equipamento específico. Domínio: Texto de 4 a 16 caracteres; pode ter minúsculas (problema tratado na Silver). Linhagem: CSV: coluna equipamento (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.nome_equipamento IS 'Descrição textual do equipamento (ex.: AUTOCLAVE, CHILLER). Domínio: 656 nomes distintos. Linhagem: CSV: coluna nome_equipamento (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.tag IS 'Tag: código de identificação técnica/local do ativo, no formato 9.999.9.9999 (ex.: 1.023.3.0346). Domínio: Texto de 12 a 13 caracteres; 7 valores vazios. Linhagem: CSV: coluna tag (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.tipo_manutencao IS 'Tipo da ordem de manutenção (ex.: PREVENTIVA, INSPEÇÃO, CORRETIVA PLANEJADA). Domínio: 16 categorias (ver dim_tipo_manutencao). Linhagem: CSV: coluna tipo_manutencao (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.data_manutencao IS 'Data da manutenção registrada na OM, em texto dd/MM/yyyy. Em 74% das OMs fica a até 7 dias do início original. Domínio: Datas de 2022 a 2027 (a maioria em 2026); contém o valor inválido 28/04/0026. Linhagem: CSV: coluna data_manutencao (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.data_termino IS 'Data de término (encerramento) da OM, em texto dd/MM/yyyy. Vazia quando a OM não foi terminada. Domínio: Vazia em 1.965 linhas (todas OMs não terminadas). Linhagem: CSV: coluna data_termino (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.data_inicio_original IS 'Data de início originalmente prevista da OM, em texto dd/MM/yyyy. Domínio: 01/01/2026 a 31/08/2026. Linhagem: CSV: coluna data_inicio_original (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw.estado_om IS 'Situação atual da OM. Domínio: Terminada, Suspensa, Não Iniciada, Iniciada. Linhagem: CSV: coluna estado_om (sem transformação).';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw._rescued_data IS 'Coluna criada automaticamente pelo Databricks: guarda dados que não couberam no formato esperado na leitura do CSV. Domínio: Esperado: sempre vazia (NULL). Linhagem: Gerada pelo read_files.';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw._arquivo_origem IS 'Metadado de controle: caminho do arquivo do qual a linha foi lida. Domínio: /Volumes/workspace/bronze/raw_files/om_manutencao_2026.csv Linhagem: Metadado _metadata.file_path.';
COMMENT ON COLUMN workspace.bronze.om_manutencao_raw._ingerido_em IS 'Metadado de controle: data e hora da carga na Bronze. Domínio: Data/hora da execução do notebook 01. Linhagem: current_timestamp() no notebook 01.';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## workspace.silver.om_manutencao  (Silver)

-- COMMAND ----------

COMMENT ON TABLE workspace.silver.om_manutencao IS 'Ordens de manutenção limpas: tipos corretos (datas como DATE), textos padronizados em maiúsculas, erro de ano corrigido e problemas de qualidade sinalizados em colunas flag_*. Granularidade: 1 linha por OM (25.872 linhas). Origem: workspace.bronze.om_manutencao_raw (notebook 03).';

COMMENT ON COLUMN workspace.silver.om_manutencao.linha_origem IS 'Número da linha no arquivo original (rastreabilidade). Domínio: 1 a 25872. Linhagem: bronze.om_manutencao_raw.linha via try_cast INT (T1).';
COMMENT ON COLUMN workspace.silver.om_manutencao.ordem IS 'Número da ordem de manutenção (OM). Chave primária: única em toda a tabela. Domínio: 100050417 a 300157661; sem duplicatas. Linhagem: bronze.om_manutencao_raw.ordem via try_cast BIGINT (T1).';
COMMENT ON COLUMN workspace.silver.om_manutencao.equipamento IS 'Código do equipamento em maiúsculas (ex.: AUT114). PREDIAL = manutenção predial geral. Domínio: 7.221 códigos distintos. Linhagem: bronze.om_manutencao_raw.equipamento com UPPER(TRIM) (T2).';
COMMENT ON COLUMN workspace.silver.om_manutencao.nome_equipamento IS 'Descrição do equipamento em maiúsculas. Domínio: 656 nomes distintos. Linhagem: bronze.om_manutencao_raw.nome_equipamento com UPPER(TRIM) (T2).';
COMMENT ON COLUMN workspace.silver.om_manutencao.tag IS 'Tag (código técnico/local) em maiúsculas. NULL quando ausente. Domínio: 1.585 tags distintas; 7 NULL. Linhagem: bronze.om_manutencao_raw.tag com UPPER(TRIM), vazio vira NULL (T2, T3).';
COMMENT ON COLUMN workspace.silver.om_manutencao.tipo_manutencao IS 'Tipo da OM em maiúsculas. Domínio: 16 categorias. Linhagem: bronze.om_manutencao_raw.tipo_manutencao com UPPER(TRIM) (T2).';
COMMENT ON COLUMN workspace.silver.om_manutencao.estado_om IS 'Situação da OM em maiúsculas. Domínio: TERMINADA, SUSPENSA, NÃO INICIADA, INICIADA. Linhagem: bronze.om_manutencao_raw.estado_om com UPPER(TRIM) (T2).';
COMMENT ON COLUMN workspace.silver.om_manutencao.data_manutencao IS 'Data da manutenção registrada na OM. Domínio: 2022-11-28 a 2027-08-23 (461 fora de 2026 sinalizadas). Linhagem: bronze.om_manutencao_raw.data_manutencao: correção do ano 00xx e conversão dd/MM/yyyy para DATE (T4, T5).';
COMMENT ON COLUMN workspace.silver.om_manutencao.data_termino IS 'Data de término da OM. NULL quando a OM não foi terminada. Domínio: 2023-03-15 a 2026-09-04; 1.965 NULL (OMs não terminadas). Linhagem: bronze.om_manutencao_raw.data_termino: correção do ano e conversão para DATE (T4, T5).';
COMMENT ON COLUMN workspace.silver.om_manutencao.data_inicio_original IS 'Data de início originalmente prevista da OM. É a data de referência das análises. Domínio: 2026-01-01 a 2026-08-31. Linhagem: bronze.om_manutencao_raw.data_inicio_original: conversão para DATE (T5).';
COMMENT ON COLUMN workspace.silver.om_manutencao.duracao_dias IS 'Dias entre início original e término. Calculada só para OM TERMINADA com datas coerentes; caso contrário NULL. Domínio: 0 a 217; 23.238 preenchidas. Linhagem: datediff(data_termino, data_inicio_original) (T7).';
COMMENT ON COLUMN workspace.silver.om_manutencao.classe_equipamento IS 'Classe do equipamento: letras iniciais do código (AUT, CHI, ARS...). Domínio: 225 classes. Linhagem: regexp_extract(equipamento, letras iniciais) (T8).';
COMMENT ON COLUMN workspace.silver.om_manutencao.mes_referencia IS 'Primeiro dia do mês do início original. Domínio: 2026-01-01 a 2026-08-01 (8 meses). Linhagem: trunc(data_inicio_original, MM) (T9).';
COMMENT ON COLUMN workspace.silver.om_manutencao.flag_ano_corrigido IS 'Verdadeiro se alguma data teve o ano inválido (00xx) corrigido para 20xx. Domínio: true em 1 linha. Linhagem: Comparação regex sobre datas da Bronze (T4/T6).';
COMMENT ON COLUMN workspace.silver.om_manutencao.flag_termino_antes_inicio IS 'Verdadeiro se data_termino é anterior a data_inicio_original (inconsistência). Essas OMs ficam sem duracao_dias. Domínio: true em 669 linhas. Linhagem: data_termino < data_inicio_original (T6).';
COMMENT ON COLUMN workspace.silver.om_manutencao.flag_manutencao_fora_2026 IS 'Verdadeiro se o ano de data_manutencao não é 2026 (suspeita de erro de digitação do ano). Domínio: true em 461 linhas. Linhagem: year(data_manutencao) <> 2026 (T6).';
COMMENT ON COLUMN workspace.silver.om_manutencao.flag_tag_ausente IS 'Verdadeiro se a OM não tem tag. Domínio: true em 7 linhas. Linhagem: tag IS NULL (T6).';
COMMENT ON COLUMN workspace.silver.om_manutencao._ingerido_em IS 'Data/hora da carga na Bronze (herdada). Domínio: Data/hora da execução do notebook 01. Linhagem: bronze.om_manutencao_raw._ingerido_em.';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## workspace.gold.dim_equipamento  (Gold)

-- COMMAND ----------

COMMENT ON TABLE workspace.gold.dim_equipamento IS 'Dimensão de equipamentos do esquema estrela. Granularidade: 1 linha por código de equipamento (7.221 linhas). Origem: workspace.silver.om_manutencao (notebook 04).';

COMMENT ON COLUMN workspace.gold.dim_equipamento.cod_equipamento IS 'Código do equipamento (chave da dimensão). Domínio: 7.221 valores únicos. Linhagem: silver.om_manutencao.equipamento.';
COMMENT ON COLUMN workspace.gold.dim_equipamento.nome_equipamento IS 'Descrição do equipamento. Domínio: 656 nomes distintos. Linhagem: silver.om_manutencao.nome_equipamento (MAX por código).';
COMMENT ON COLUMN workspace.gold.dim_equipamento.classe_equipamento IS 'Classe do equipamento (letras iniciais do código). Domínio: 225 classes. Linhagem: silver.om_manutencao.classe_equipamento.';
COMMENT ON COLUMN workspace.gold.dim_equipamento.nome_classe IS 'Nome legível da classe: o nome de equipamento mais frequente dentro da classe (ex.: AUT = AUTOCLAVE). Domínio: 225 valores. Linhagem: Calculado com ROW_NUMBER sobre a frequência de nomes por classe.';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## workspace.gold.dim_tipo_manutencao  (Gold)

-- COMMAND ----------

COMMENT ON TABLE workspace.gold.dim_tipo_manutencao IS 'Dimensão de tipos de manutenção com agrupamento de negócio. Granularidade: 1 linha por tipo (16 linhas). Origem: tabela de mapeamento definida no notebook 04.';

COMMENT ON COLUMN workspace.gold.dim_tipo_manutencao.tipo_manutencao IS 'Tipo da ordem de manutenção (chave da dimensão). Domínio: 16 valores únicos. Linhagem: silver.om_manutencao.tipo_manutencao.';
COMMENT ON COLUMN workspace.gold.dim_tipo_manutencao.grupo_manutencao IS 'Grupo de negócio do tipo: PREVENTIVA/INSPEÇÃO, CORRETIVA, PROJETOS/MELHORIAS ou APOIO/ADMINISTRATIVO. Domínio: 4 grupos. Linhagem: Mapeamento manual definido no notebook 04 (decisão de modelagem).';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## workspace.gold.dim_data  (Gold)

-- COMMAND ----------

COMMENT ON TABLE workspace.gold.dim_data IS 'Dimensão calendário. Granularidade: 1 linha por dia, de 01/01/2026 a 31/12/2027 (730 linhas). Gerada por código, sem fonte externa.';

COMMENT ON COLUMN workspace.gold.dim_data.data IS 'Dia do calendário (chave da dimensão). Domínio: 2026-01-01 a 2027-12-31. Linhagem: sequence() no notebook 04.';
COMMENT ON COLUMN workspace.gold.dim_data.ano IS 'Ano. Domínio: 2026 ou 2027. Linhagem: year(data).';
COMMENT ON COLUMN workspace.gold.dim_data.mes IS 'Número do mês. Domínio: 1 a 12. Linhagem: month(data).';
COMMENT ON COLUMN workspace.gold.dim_data.nome_mes IS 'Nome do mês em português. Domínio: Janeiro a Dezembro. Linhagem: Derivado de month(data).';
COMMENT ON COLUMN workspace.gold.dim_data.ano_mes IS 'Ano e mês no formato yyyy-MM (útil para ordenar gráficos). Domínio: 2026-01 a 2027-12. Linhagem: date_format(data, yyyy-MM).';
COMMENT ON COLUMN workspace.gold.dim_data.trimestre IS 'Trimestre do ano. Domínio: 1 a 4. Linhagem: quarter(data).';
COMMENT ON COLUMN workspace.gold.dim_data.dia_semana IS 'Nome do dia da semana em português. Domínio: Domingo a Sábado. Linhagem: Derivado de dayofweek(data).';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## workspace.gold.fato_ordem_manutencao  (Gold)

-- COMMAND ----------

COMMENT ON TABLE workspace.gold.fato_ordem_manutencao IS 'Tabela fato do esquema estrela. Granularidade: 1 linha por ordem de manutenção (25.872 linhas). Relaciona-se com dim_equipamento (cod_equipamento), dim_tipo_manutencao (tipo_manutencao) e dim_data (data_inicio_original). Origem: workspace.silver.om_manutencao (notebook 04).';

COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.ordem IS 'Número da OM (chave da fato). Domínio: Único; 100050417 a 300157661. Linhagem: silver.om_manutencao.ordem.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.cod_equipamento IS 'Chave estrangeira para dim_equipamento. Domínio: 7.221 valores. Linhagem: silver.om_manutencao.equipamento.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.tipo_manutencao IS 'Chave estrangeira para dim_tipo_manutencao. Domínio: 16 valores. Linhagem: silver.om_manutencao.tipo_manutencao.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.data_inicio_original IS 'Chave estrangeira para dim_data; data de referência das análises. Domínio: 2026-01-01 a 2026-08-31. Linhagem: silver.om_manutencao.data_inicio_original.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.tag_local IS 'Tag (código técnico/local) da OM. Fica na fato porque um equipamento pode ter mais de uma tag. Domínio: 1.585 tags; 7 NULL. Linhagem: silver.om_manutencao.tag.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.estado_om IS 'Situação da OM. Domínio: TERMINADA, SUSPENSA, NÃO INICIADA, INICIADA. Linhagem: silver.om_manutencao.estado_om.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.data_manutencao IS 'Data da manutenção registrada na OM. Domínio: 2022-11-28 a 2027-08-23. Linhagem: silver.om_manutencao.data_manutencao.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.data_termino IS 'Data de término da OM; NULL se não terminada. Domínio: 2023-03-15 a 2026-09-04. Linhagem: silver.om_manutencao.data_termino.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.duracao_dias IS 'Medida: dias de execução (término - início original). NULL se não aplicável. Domínio: 0 a 217. Linhagem: silver.om_manutencao.duracao_dias.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.flag_ano_corrigido IS 'Sinalizador: ano de data corrigido. Domínio: 1 linha true. Linhagem: silver.om_manutencao.flag_ano_corrigido.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.flag_termino_antes_inicio IS 'Sinalizador: término anterior ao início. Domínio: 669 linhas true. Linhagem: silver.om_manutencao.flag_termino_antes_inicio.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.flag_manutencao_fora_2026 IS 'Sinalizador: data_manutencao fora de 2026. Domínio: 461 linhas true. Linhagem: silver.om_manutencao.flag_manutencao_fora_2026.';
COMMENT ON COLUMN workspace.gold.fato_ordem_manutencao.flag_tag_ausente IS 'Sinalizador: OM sem tag. Domínio: 7 linhas true. Linhagem: silver.om_manutencao.flag_tag_ausente.';

-- COMMAND ----------

-- Conferência: veja as descrições gravadas na tabela fato
DESCRIBE TABLE EXTENDED workspace.gold.fato_ordem_manutencao;
