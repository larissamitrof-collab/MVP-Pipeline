CREATE SCHEMA IF NOT EXISTS workspace.bronze COMMENT 'Camada Bronze: dado bruto, exatamente como chegou da fonte';
CREATE SCHEMA IF NOT EXISTS workspace.silver COMMENT 'Camada Silver: dado limpo, padronizado e tipado';
CREATE SCHEMA IF NOT EXISTS workspace.gold   COMMENT 'Camada Gold: dado modelado (esquema estrela) pronto para análise';

CREATE VOLUME IF NOT EXISTS workspace.bronze.raw_files COMMENT 'Arquivos brutos recebidos da fonte (CSV de ordens de manutenção)';


LIST '/Volumes/workspace/bronze/raw_files/';

SHOW SCHEMAS IN workspace;
