
CREATE OR REPLACE TABLE workspace.bronze.om_manutencao_raw
COMMENT 'Ordens de manutenção (OM) de jan-ago/2026, exatamente como exportadas do sistema de manutenção. Todas as colunas em texto.'
AS
SELECT
  *,                                       
  _metadata.file_path  AS _arquivo_origem, 
  current_timestamp()  AS _ingerido_em     
FROM read_files(
  '/Volumes/workspace/bronze/raw_files/om_manutencao_2026.csv',
  format            => 'csv',
  header            => true,    
  delimiter         => ',',
  encoding          => 'UTF-8', 
  inferColumnTypes  => false    
);


SELECT COUNT(*) AS total_linhas FROM workspace.bronze.om_manutencao_raw;

DESCRIBE TABLE workspace.bronze.om_manutencao_raw;


SELECT * FROM workspace.bronze.om_manutencao_raw LIMIT 10;

SELECT COUNT(*) AS linhas_com_problema_de_leitura
FROM workspace.bronze.om_manutencao_raw
WHERE _rescued_data IS NOT NULL;
