CREATE SCHEMA IF NOT EXISTS dw;

DROP TABLE IF EXISTS dw.fato_transacao CASCADE;
DROP TABLE IF EXISTS dw.dim_data CASCADE;
DROP TABLE IF EXISTS dw.dim_titular CASCADE;
DROP TABLE IF EXISTS dw.dim_categoria CASCADE;
DROP TABLE IF EXISTS dw.dim_estabelecimento CASCADE;

CREATE TABLE dw.dim_data (
    id_data       SERIAL       PRIMARY KEY,
    data_compra   DATE         NOT NULL UNIQUE,
    dia           INTEGER      NOT NULL,
    mes           INTEGER      NOT NULL,
    trimestre     INTEGER      NOT NULL,
    ano           INTEGER      NOT NULL,
    dia_semana    INTEGER      NOT NULL,
    nome_dia      VARCHAR(20)  NOT NULL,
    nome_mes      VARCHAR(20)  NOT NULL
);

CREATE TABLE dw.dim_titular (
    id_titular    SERIAL       PRIMARY KEY,
    nome_titular  VARCHAR(100) NOT NULL,
    final_cartao  VARCHAR(4)   NOT NULL,
    CONSTRAINT uq_titular UNIQUE (nome_titular, final_cartao)
);

CREATE TABLE dw.dim_categoria (
    id_categoria    SERIAL       PRIMARY KEY,
    nome_categoria  VARCHAR(200) NOT NULL UNIQUE
);

CREATE TABLE dw.dim_estabelecimento (
    id_estabelecimento    SERIAL       PRIMARY KEY,
    nome_estabelecimento  VARCHAR(200) NOT NULL UNIQUE
);

CREATE TABLE dw.fato_transacao (
    id_transacao       SERIAL        PRIMARY KEY,
    id_data            INTEGER       NOT NULL REFERENCES dw.dim_data(id_data),
    id_titular         INTEGER       NOT NULL REFERENCES dw.dim_titular(id_titular),
    id_categoria       INTEGER       NOT NULL REFERENCES dw.dim_categoria(id_categoria),
    id_estabelecimento INTEGER       NOT NULL REFERENCES dw.dim_estabelecimento(id_estabelecimento),
    valor_brl          DECIMAL(12,2) NOT NULL DEFAULT 0,
    valor_usd          DECIMAL(12,2) NOT NULL DEFAULT 0,
    cotacao            DECIMAL(8,4)  NOT NULL DEFAULT 0,
    parcela_texto      VARCHAR(20)   NOT NULL,
    num_parcela        INTEGER,
    total_parcelas     INTEGER,
    arquivo_origem     VARCHAR(50)   NOT NULL
);

CREATE INDEX idx_fato_id_data            ON dw.fato_transacao(id_data);
CREATE INDEX idx_fato_id_titular         ON dw.fato_transacao(id_titular);
CREATE INDEX idx_fato_id_categoria       ON dw.fato_transacao(id_categoria);
CREATE INDEX idx_fato_id_estabelecimento ON dw.fato_transacao(id_estabelecimento);
CREATE INDEX idx_fato_valor_brl          ON dw.fato_transacao(valor_brl);
CREATE INDEX idx_dim_data_ano_mes        ON dw.dim_data(ano, mes);
