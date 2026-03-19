# Dicionário de Dados — Data Warehouse de Transações

## Índice

1. [Visão Geral das Tabelas](#1-visão-geral-das-tabelas)
2. [dim_data](#2-dim_data)
3. [dim_titular](#3-dim_titular)
4. [dim_categoria](#4-dim_categoria)
5. [dim_estabelecimento](#5-dim_estabelecimento)
6. [fato_transacao](#6-fato_transacao)
7. [Dados de Origem (CSV)](#7-dados-de-origem-csv)
8. [Mapeamento Origem → Destino](#8-mapeamento-origem--destino)

---

## 1. Visão Geral das Tabelas

| Schema | Tabela | Tipo | Registros esperados | Descrição |
|--------|--------|------|---------------------|-----------|
| dw | dim_data | Dimensão | ~400 | Datas únicas das transações |
| dw | dim_titular | Dimensão | ~10-20 | Titulares de cartão + final do cartão |
| dw | dim_categoria | Dimensão | ~25-35 | Categorias MCC distintas |
| dw | dim_estabelecimento | Dimensão | ~150-300 | Estabelecimentos distintos |
| dw | fato_transacao | Fato | ~1500-2500 | Transações de cartão de crédito |

---

## 2. dim_data

**Descrição**: Dimensão temporal derivada das datas de compra encontradas nos CSVs.

| # | Coluna | Tipo PostgreSQL | PK | FK | UNIQUE | NOT NULL | Default | Descrição |
|---|--------|----------------|----|----|--------|----------|---------|-----------|
| 1 | id_data | SERIAL | ✅ | | | ✅ | auto | Chave substituta |
| 2 | data_compra | DATE | | | ✅ | ✅ | | Data completa da compra |
| 3 | dia | INTEGER | | | | ✅ | | Dia do mês (1-31) |
| 4 | mes | INTEGER | | | | ✅ | | Mês do ano (1-12) |
| 5 | trimestre | INTEGER | | | | ✅ | | Trimestre (1-4) |
| 6 | ano | INTEGER | | | | ✅ | | Ano (ex: 2025) |
| 7 | dia_semana | INTEGER | | | | ✅ | | Dia da semana (0=Segunda, 6=Domingo) |
| 8 | nome_dia | VARCHAR(20) | | | | ✅ | | Nome por extenso (ex: "Segunda-feira") |
| 9 | nome_mes | VARCHAR(20) | | | | ✅ | | Nome do mês (ex: "Janeiro") |

**Chave natural**: `data_compra`

**Origem dos dados**: Derivada da coluna "Data de Compra" dos CSVs.

---

## 3. dim_titular

**Descrição**: Identifica cada combinação única de titular + cartão. Um titular pode possuir mais de um cartão.

| # | Coluna | Tipo PostgreSQL | PK | FK | UNIQUE | NOT NULL | Default | Descrição |
|---|--------|----------------|----|----|--------|----------|---------|-----------|
| 1 | id_titular | SERIAL | ✅ | | | ✅ | auto | Chave substituta |
| 2 | nome_titular | VARCHAR(100) | | | | ✅ | | Nome anonimizado no cartão |
| 3 | final_cartao | VARCHAR(4) | | | | ✅ | | Últimos 4 dígitos do cartão |

**Constraint UNIQUE**: `(nome_titular, final_cartao)`

**Origem dos dados**: Colunas "Nome no Cartão" e "Final do Cartão" dos CSVs.

**Exemplos de dados observados**:

| nome_titular | final_cartao |
|-------------|-------------|
| VIN DIESEL | 1115 |
| VIN DIESEL | 1122 |
| CHARLIZE THERON | 1153 |
| BRIAN TYLER | 1114 |
| EVA MENDES | 1117 |

---

## 4. dim_categoria

**Descrição**: Categorias MCC (Merchant Category Code) das transações.

| # | Coluna | Tipo PostgreSQL | PK | FK | UNIQUE | NOT NULL | Default | Descrição |
|---|--------|----------------|----|----|--------|----------|---------|-----------|
| 1 | id_categoria | SERIAL | ✅ | | | ✅ | auto | Chave substituta |
| 2 | nome_categoria | VARCHAR(200) | | | ✅ | ✅ | | Nome da categoria |

**Chave natural**: `nome_categoria`

**Regra de limpeza**: Categorias com valor "-" ou vazio → "Não categorizado".

**Exemplos de categorias observadas**:

- Restaurante / Lanchonete / Bar
- Supermercados / Mercearia / Padarias / Lojas de Conveniência
- Relacionados a Automotivo
- Departamento / Desconto
- Associação
- Elétrico
- T&E Companhia aérea
- Não categorizado

---

## 5. dim_estabelecimento

**Descrição**: Estabelecimentos comerciais onde as transações foram realizadas.

| # | Coluna | Tipo PostgreSQL | PK | FK | UNIQUE | NOT NULL | Default | Descrição |
|---|--------|----------------|----|----|--------|----------|---------|-----------|
| 1 | id_estabelecimento | SERIAL | ✅ | | | ✅ | auto | Chave substituta |
| 2 | nome_estabelecimento | VARCHAR(200) | | | ✅ | ✅ | | Nome do estabelecimento (normalizado) |

**Chave natural**: `nome_estabelecimento`

**Regra de limpeza**: Trim de espaços; descrições vazias → "Não informado".

**Exemplos de dados observados**:

- SUPERMERCADO PORTELLA
- MIX CENTER
- UBER *TRIP
- AMAZON MUSIC
- OPENAI *CHATGPT SUBSCR +1
- Inclusao de Pagamento

---

## 6. fato_transacao

**Descrição**: Tabela fato central contendo cada transação de cartão de crédito.

| # | Coluna | Tipo PostgreSQL | PK | FK | UNIQUE | NOT NULL | Default | Descrição |
|---|--------|----------------|----|----|--------|----------|---------|-----------|
| 1 | id_transacao | SERIAL | ✅ | | | ✅ | auto | Chave substituta |
| 2 | id_data | INTEGER | | ✅ dim_data | | ✅ | | FK para dimensão data |
| 3 | id_titular | INTEGER | | ✅ dim_titular | | ✅ | | FK para dimensão titular |
| 4 | id_categoria | INTEGER | | ✅ dim_categoria | | ✅ | | FK para dimensão categoria |
| 5 | id_estabelecimento | INTEGER | | ✅ dim_estabelecimento | | ✅ | | FK para dimensão estabelecimento |
| 6 | valor_brl | DECIMAL(12,2) | | | | ✅ | 0 | Valor em reais |
| 7 | valor_usd | DECIMAL(12,2) | | | | ✅ | 0 | Valor em dólares |
| 8 | cotacao | DECIMAL(8,4) | | | | ✅ | 0 | Cotação USD→BRL |
| 9 | parcela_texto | VARCHAR(20) | | | | ✅ | | Texto original da parcela |
| 10 | num_parcela | INTEGER | | | | | NULL | Número da parcela atual |
| 11 | total_parcelas | INTEGER | | | | | NULL | Total de parcelas |
| 12 | arquivo_origem | VARCHAR(50) | | | | ✅ | | Arquivo CSV de origem |

**Granularidade**: 1 registro = 1 linha do CSV de origem.

**Valores negativos**: `valor_brl < 0` indica estorno ou crédito (ex: pagamento de fatura, estorno de tarifa).

---

## 7. Dados de Origem (CSV)

| Coluna CSV | Tipo no CSV | Exemplo | Observações |
|-----------|-------------|---------|-------------|
| Data de Compra | Texto DD/MM/AAAA | 12/10/2024 | Converter para DATE |
| Nome no Cartão | Texto | VIN DIESEL | Nomes anonimizados |
| Final do Cartão | Numérico | 1115 | Tratado como VARCHAR(4) no DW |
| Categoria | Texto | Restaurante / Lanchonete / Bar | "-" = sem categoria |
| Descrição | Texto | SUPERMERCADO PORTELLA | Pode conter caracteres especiais |
| Parcela | Texto | Única / 1/3 / 2/10 | Exige parsing |
| Valor (em US$) | Numérico | 24.00 | 0 quando não aplicável |
| Cotação (em R$) | Numérico | 6.08 | 0 quando não aplicável |
| Valor (em R$) | Numérico | 145.96 | Negativo = estorno |

---

## 8. Mapeamento Origem → Destino

### dim_data (derivada de "Data de Compra")

| Origem | Transformação | Destino |
|--------|---------------|---------|
| Data de Compra | `strptime(DD/MM/AAAA)` | data_compra |
| Data de Compra | `.day` | dia |
| Data de Compra | `.month` | mes |
| Data de Compra | `(month-1)//3 + 1` | trimestre |
| Data de Compra | `.year` | ano |
| Data de Compra | `.weekday()` | dia_semana |
| Data de Compra | Lookup tabela dias | nome_dia |
| Data de Compra | Lookup tabela meses | nome_mes |

### dim_titular

| Origem | Transformação | Destino |
|--------|---------------|---------|
| Nome no Cartão | strip() | nome_titular |
| Final do Cartão | str() | final_cartao |

### dim_categoria

| Origem | Transformação | Destino |
|--------|---------------|---------|
| Categoria | strip(); "-" ou vazio → "Não categorizado" | nome_categoria |

### dim_estabelecimento

| Origem | Transformação | Destino |
|--------|---------------|---------|
| Descrição | strip(); vazio → "Não informado" | nome_estabelecimento |

### fato_transacao

| Origem | Transformação | Destino |
|--------|---------------|---------|
| Data de Compra | Lookup dim_data.id_data | id_data |
| Nome no Cartão + Final do Cartão | Lookup dim_titular.id_titular | id_titular |
| Categoria | Lookup dim_categoria.id_categoria | id_categoria |
| Descrição | Lookup dim_estabelecimento.id_estabelecimento | id_estabelecimento |
| Valor (em R$) | float() | valor_brl |
| Valor (em US$) | float() | valor_usd |
| Cotação (em R$) | float() | cotacao |
| Parcela | Manter texto original | parcela_texto |
| Parcela | Parse "x/y" → x | num_parcela |
| Parcela | Parse "x/y" → y; "Única" → 1 | total_parcelas |
| (metadado) | Nome do arquivo CSV | arquivo_origem |
