# Modelagem do Data Warehouse — Star Schema

## Índice

1. [Modelo Dimensional](#1-modelo-dimensional)
2. [Diagrama Star Schema](#2-diagrama-star-schema)
3. [Tabela Fato: fato_transacao](#3-tabela-fato-fato_transacao)
4. [Dimensão: dim_data](#4-dimensão-dim_data)
5. [Dimensão: dim_titular](#5-dimensão-dim_titular)
6. [Dimensão: dim_categoria](#6-dimensão-dim_categoria)
7. [Dimensão: dim_estabelecimento](#7-dimensão-dim_estabelecimento)
8. [Decisões de Modelagem](#8-decisões-de-modelagem)
9. [Regras de ETL e Qualidade](#9-regras-de-etl-e-qualidade)

---

## 1. Modelo Dimensional

O Data Warehouse utiliza o modelo **Star Schema** (esquema estrela) com:

- **1 tabela fato**: `fato_transacao` — registra cada transação de cartão de crédito.
- **4 dimensões**:
  - `dim_data` — dimensão temporal (data da compra).
  - `dim_titular` — titular do cartão e identificação do cartão.
  - `dim_categoria` — categoria MCC da transação.
  - `dim_estabelecimento` — estabelecimento onde a compra foi realizada.

## 2. Diagrama Star Schema

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
|    trimestre    |   |    valor_brl         |          ^
|    ano          |   |    valor_usd         |          |
|    dia_semana   |   |    cotacao            |   +---------------------+
|    nome_dia     |   |    parcela_texto     |   | dim_estabelecimento |
+----------------+   |    num_parcela       |   +---------------------+
                      |    total_parcelas    |   | PK id_estabelecimento|
                      |    arquivo_origem    |   |    nome_estabelecim. |
                      +----------------------+   +---------------------+
                             |
                             | FK
                             v
                    +---------------------+
                    | dim_estabelecimento |
                    +---------------------+
```

## 3. Tabela Fato: `fato_transacao`

Granularidade: **uma linha por transação registrada no CSV** (cada linha do arquivo CSV gera um registro na fato).

| Coluna | Tipo | Nulável | Descrição |
|--------|------|---------|-----------|
| `id_transacao` | SERIAL (PK) | Não | Chave substituta autoincremental |
| `id_data` | INTEGER (FK) | Não | Referência para `dim_data` |
| `id_titular` | INTEGER (FK) | Não | Referência para `dim_titular` |
| `id_categoria` | INTEGER (FK) | Não | Referência para `dim_categoria` |
| `id_estabelecimento` | INTEGER (FK) | Não | Referência para `dim_estabelecimento` |
| `valor_brl` | DECIMAL(12,2) | Não | Valor em reais (negativo = estorno/crédito) |
| `valor_usd` | DECIMAL(12,2) | Não | Valor em dólar (0 quando não aplicável) |
| `cotacao` | DECIMAL(8,4) | Não | Cotação USD→BRL usada na conversão |
| `parcela_texto` | VARCHAR(20) | Não | Texto original da parcela ("Única", "1/3") |
| `num_parcela` | INTEGER | Sim | Número da parcela atual (1 para Única) |
| `total_parcelas` | INTEGER | Sim | Total de parcelas (1 para Única) |
| `arquivo_origem` | VARCHAR(50) | Não | Nome do arquivo CSV de origem |

### Métricas disponíveis

- `valor_brl`: métrica principal para análises em reais.
- `valor_usd`: métrica para análises em dólar.
- `cotacao`: para análises de câmbio.
- `num_parcela` / `total_parcelas`: para análises de parcelamento.

## 4. Dimensão: `dim_data`

| Coluna | Tipo | Nulável | Descrição |
|--------|------|---------|-----------|
| `id_data` | SERIAL (PK) | Não | Chave substituta |
| `data_compra` | DATE | Não | Data completa (UNIQUE) |
| `dia` | INTEGER | Não | Dia do mês (1-31) |
| `mes` | INTEGER | Não | Mês (1-12) |
| `trimestre` | INTEGER | Não | Trimestre (1-4) |
| `ano` | INTEGER | Não | Ano (ex: 2025) |
| `dia_semana` | INTEGER | Não | Dia da semana (0=seg, 6=dom) |
| `nome_dia` | VARCHAR(20) | Não | Nome do dia por extenso |
| `nome_mes` | VARCHAR(20) | Não | Nome do mês por extenso |

### Chave natural

`data_compra` (UNIQUE) — cada data distinta gera um registro.

## 5. Dimensão: `dim_titular`

| Coluna | Tipo | Nulável | Descrição |
|--------|------|---------|-----------|
| `id_titular` | SERIAL (PK) | Não | Chave substituta |
| `nome_titular` | VARCHAR(100) | Não | Nome no cartão (anonimizado) |
| `final_cartao` | VARCHAR(4) | Não | Últimos 4 dígitos do cartão |

### Chave natural

Combinação `(nome_titular, final_cartao)` — UNIQUE. Um titular pode ter mais de um cartão.

## 6. Dimensão: `dim_categoria`

| Coluna | Tipo | Nulável | Descrição |
|--------|------|---------|-----------|
| `id_categoria` | SERIAL (PK) | Não | Chave substituta |
| `nome_categoria` | VARCHAR(200) | Não | Nome da categoria MCC (UNIQUE) |

### Chave natural

`nome_categoria` (UNIQUE). Categorias com valor `-` são mapeadas para "Não categorizado".

## 7. Dimensão: `dim_estabelecimento`

| Coluna | Tipo | Nulável | Descrição |
|--------|------|---------|-----------|
| `id_estabelecimento` | SERIAL (PK) | Não | Chave substituta |
| `nome_estabelecimento` | VARCHAR(200) | Não | Descrição do estabelecimento (UNIQUE) |

### Chave natural

`nome_estabelecimento` (UNIQUE) — texto normalizado (trim e uppercase).

## 8. Decisões de Modelagem

### 8.1 Granularidade da fato

**Decisão**: cada linha do CSV corresponde a um registro na `fato_transacao`.

**Justificativa**: Algumas compras internacionais geram duas linhas — uma com o valor em US$ e outra com o IOF em R$. Manter todas as linhas preserva a rastreabilidade completa e permite análises detalhadas por tipo de transação. Filtragem pode ser feita nas consultas.

### 8.2 Parcelas na tabela fato

**Decisão**: manter `parcela_texto`, `num_parcela` e `total_parcelas` como atributos na fato, sem criar dimensão separada de parcelamento.

**Justificativa**: O parcelamento tem baixa cardinalidade e não justifica uma dimensão própria. Os atributos na fato permitem análises diretas.

### 8.3 Estornos e créditos

**Decisão**: manter estornos (valores negativos em `valor_brl`) na mesma tabela fato.

**Justificativa**: Facilita análises de impacto por titular e categoria. Filtros nas consultas separam transações normais de estornos.

### 8.4 Categoria "-" ou vazia

**Decisão**: categorias com valor `-` ou vazio são mapeadas para "Não categorizado".

**Justificativa**: Garante integridade referencial sem perder registros.

### 8.5 Chaves substitutas

**Decisão**: todas as dimensões usam chaves substitutas (SERIAL/autoincrement) em vez de chaves naturais como PK.

**Justificativa**: Padrão em modelagem dimensional para performance e flexibilidade.

## 9. Regras de ETL e Qualidade

| Regra | Descrição |
|-------|-----------|
| **R01** | Datas convertidas de DD/MM/AAAA para tipo DATE |
| **R02** | Valores decimais normalizados para DECIMAL (vírgula → ponto se necessário) |
| **R03** | Campos vazios ou "-" em Categoria → "Não categorizado" |
| **R04** | Campos vazios em Descrição → "Não informado" |
| **R05** | Parcela "Única" → num_parcela=1, total_parcelas=1 |
| **R06** | Parcela "x/y" → num_parcela=x, total_parcelas=y |
| **R07** | Espaços em branco extras removidos (trim) de todos os campos texto |
| **R08** | Dimensões carregadas antes da fato (integridade referencial) |
| **R09** | Full load a cada execução (truncate + insert) |
| **R10** | Registro de arquivo de origem para rastreabilidade |
