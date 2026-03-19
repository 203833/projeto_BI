# Data Warehouse — Transações de Cartão de Crédito

**Curso**: Análise e Desenvolvimento de Sistemas  
**Disciplina**: Business Intelligence e Data Warehouse

---

## Índice

1. [Objetivo](#1-objetivo)
2. [Estrutura do Projeto](#2-estrutura-do-projeto)
3. [Pré-requisitos](#3-pré-requisitos)
4. [Configuração do Ambiente](#4-configuração-do-ambiente)
5. [Execução do ETL](#5-execução-do-etl)
6. [Consultas Analíticas](#6-consultas-analíticas)
7. [Documentação](#7-documentação)
8. [Arquitetura do Data Warehouse](#8-arquitetura-do-data-warehouse)

---

## 1. Objetivo

Construir um **Data Warehouse** a partir de dados reais (anonimizados) de faturas de cartão de crédito, aplicando conceitos de ETL e análise de dados.

O projeto implementa:
- **Fase 1**: Modelagem dimensional (Star Schema) com dicionário de dados.
- **Fase 2**: Pipeline ETL em Python para extrair, transformar e carregar dados no PostgreSQL.
- **Fase 3**: Consultas analíticas SQL para responder perguntas de negócio.

---

## 2. Estrutura do Projeto

```
projeto-dw-transacoes/
├── README.md                          # Este arquivo
├── .gitignore
├── docs/
│   ├── 01_plano_projeto.md            # Plano do projeto
│   ├── 02_modelagem_dw.md             # Modelagem Star Schema
│   └── 03_dicionario_dados.md         # Dicionário de dados
├── sql/
│   ├── 01_create_database.sql         # DDL das tabelas do DW
│   └── 02_consultas_analiticas.sql    # Consultas analíticas (Fase 3)
├── etl/
│   ├── etl_pipeline.py                # Script ETL principal
│   ├── requirements.txt               # Dependências Python
│   └── .env.example                   # Template de variáveis de ambiente
└── data/
    ├── Fatura_2025-03-20.csv          # Faturas mensais (12 arquivos)
    ├── Fatura_2025-04-20.csv
    ├── ...
    └── Fatura_2026-02-20.csv
```

---

## 3. Pré-requisitos

| Software | Versão mínima | Instalação |
|----------|---------------|------------|
| Python | 3.10+ | [python.org](https://www.python.org/downloads/) |
| PostgreSQL | 15+ | [postgresql.org](https://www.postgresql.org/download/) |
| pip | 22+ | Incluso com Python |

---

## 4. Configuração do Ambiente

### 4.1 Banco de dados PostgreSQL

Criar o banco de dados:

```sql
CREATE DATABASE dw_transacoes
    WITH ENCODING = 'UTF8';
```

### 4.2 Variáveis de ambiente

Copiar o template e configurar:

```bash
cd etl/
cp .env.example .env
```

Editar o arquivo `.env` com as credenciais do seu PostgreSQL:

```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dw_transacoes
DB_USER=postgres
DB_PASSWORD=sua_senha_aqui
```

### 4.3 Dependências Python

```bash
cd etl/
pip install -r requirements.txt
```

---

## 5. Execução do ETL

Executar o pipeline completo:

```bash
cd etl/
python etl_pipeline.py
```

O pipeline executa as seguintes etapas automaticamente:

1. **Criação do schema e tabelas** (DDL) no PostgreSQL.
2. **Extração** dos 12 arquivos CSV de faturas.
3. **Transformação** dos dados (datas, valores, parcelas, categorias).
4. **Carga** das dimensões e tabela fato no banco.
5. **Validação** com contagem de registros por tabela.

### Saída esperada

```
[INFO] INÍCIO DO PIPELINE ETL
[INFO] [FASE 0] Criando schema e tabelas...
[INFO] [FASE 1] Extraindo dados dos CSVs...
[INFO] Encontrados 12 arquivos CSV para processar
[INFO] [FASE 2] Transformando dados...
[INFO] [FASE 3] Carregando dados no Data Warehouse...
[INFO] VALIDAÇÃO PÓS-CARGA
[INFO]   dim_data                 : XXX registros
[INFO]   dim_titular              : XXX registros
[INFO]   dim_categoria            : XXX registros
[INFO]   dim_estabelecimento      : XXX registros
[INFO]   fato_transacao           : XXXX registros
[INFO] Pipeline ETL concluído em 0:00:XX
```

---

## 6. Consultas Analíticas

Após a carga dos dados, execute as consultas disponíveis em `sql/02_consultas_analiticas.sql` no PostgreSQL.

As consultas respondem às seguintes perguntas de negócio:

| # | Pergunta |
|---|----------|
| 1 | Gasto total por titular no período |
| 2 | Gasto mensal por titular (série temporal) |
| 3 | Top 10 categorias por valor |
| 4 | Evolução mensal do total gasto |
| 5 | Comparativo entre titulares |
| 6 | Top 15 estabelecimentos por valor |
| 7 | Comportamento de parcelamento (à vista vs parcelado) |
| 8 | Distribuição de parcelas |
| 9 | Dia da semana com mais transações |
| 10 | Estornos e créditos por titular |
| 11 | Estornos e créditos por categoria |
| 12 | Transações em moeda estrangeira |
| 13 | Ranking de categorias por titular |
| 14 | Evolução trimestral por categoria |
| 15 | Resumo geral (KPIs) |

---

## 7. Documentação

| Documento | Descrição |
|-----------|-----------|
| [Plano do Projeto](docs/01_plano_projeto.md) | Visão geral, escopo, fases e cronograma |
| [Modelagem do DW](docs/02_modelagem_dw.md) | Star Schema, decisões de modelagem |
| [Dicionário de Dados](docs/03_dicionario_dados.md) | Tabelas, colunas, tipos e mapeamentos |

---

## 8. Arquitetura do Data Warehouse

### Modelo Star Schema

```
                    +-------------------+
                    |   dim_titular     |
                    +-------------------+
                    | PK id_titular     |
                    |    nome_titular   |
                    |    final_cartao   |
                    +--------+----------+
                             |
                             | FK
                             v
+----------------+   +----------------------+   +---------------------+
|   dim_data     |   |   fato_transacao     |   |   dim_categoria     |
+----------------+   +----------------------+   +---------------------+
| PK id_data     |<--| FK id_data           |   | PK id_categoria     |
|    data_compra  |   | FK id_titular        |-->|    nome_categoria   |
|    dia          |   | FK id_categoria      |   +---------------------+
|    mes          |   | FK id_estabelecimento|
|    trimestre    |   |    valor_brl         |
|    ano          |   |    valor_usd         |   +---------------------+
|    dia_semana   |   |    cotacao           |   | dim_estabelecimento |
|    nome_dia     |   |    parcela_texto     |   +---------------------+
|    nome_mes     |   |    num_parcela       |   | PK id_estabelecim.  |
+----------------+   |    total_parcelas    |-->|    nome_estabelecim. |
                      |    arquivo_origem    |   +---------------------+
                      +----------------------+
```

### Dataset

- **Fonte**: 12 arquivos CSV (faturas mensais de cartão de crédito)
- **Período**: Março/2025 a Fevereiro/2026
- **Separador**: `;` (ponto e vírgula)
- **Codificação**: UTF-8

### Tecnologias

- **Python 3.10+** com pandas e SQLAlchemy
- **PostgreSQL 15+** como banco de dados do DW
