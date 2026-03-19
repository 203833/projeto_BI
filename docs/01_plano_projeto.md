# Plano do Projeto — Data Warehouse de Transações de Cartão de Crédito

## Índice

1. [Visão Geral](#1-visão-geral)
2. [Objetivo](#2-objetivo)
3. [Escopo](#3-escopo)
4. [Dataset](#4-dataset)
5. [Fases do Projeto](#5-fases-do-projeto)
6. [Tecnologias Utilizadas](#6-tecnologias-utilizadas)
7. [Riscos e Mitigações](#7-riscos-e-mitigações)
8. [Critérios de Qualidade](#8-critérios-de-qualidade)

---

## 1. Visão Geral

Este projeto tem como finalidade construir um **Data Warehouse** a partir de dados reais (anonimizados) de faturas de cartão de crédito de uma instituição financeira. O pipeline completo abrange a modelagem dimensional, o processo de ETL (Extract, Transform, Load) e consultas analíticas para apoio à decisão.

## 2. Objetivo

- Modelar um Data Warehouse utilizando **Star Schema** (modelo dimensional).
- Implementar um pipeline ETL em **Python** para extrair dados de 12 arquivos CSV, transformá-los e carregá-los em um banco **PostgreSQL**.
- Validar os dados carregados por meio de **consultas analíticas SQL** que respondam a perguntas de negócio relevantes.

## 3. Escopo

### 3.1 Dentro do escopo

| Item | Descrição |
|------|-----------|
| Modelagem dimensional | Star Schema com 1 fato e 4 dimensões |
| ETL | Script Python para leitura, limpeza, transformação e carga |
| Banco de dados | PostgreSQL como repositório analítico |
| Consultas analíticas | Conjunto de queries SQL para perguntas de negócio |
| Documentação | Plano do projeto, modelagem, dicionário de dados, README |

### 3.2 Fora do escopo (nesta etapa)

- Dashboards e visualizações interativas (Fase 4 futura).
- Implementação de carga incremental (será full load).
- Segurança e controle de acesso ao banco.

## 4. Dataset

### 4.1 Descrição geral

| Atributo | Valor |
|----------|-------|
| **Fonte** | 12 arquivos CSV (faturas mensais) |
| **Período** | Março/2025 a Fevereiro/2026 |
| **Nomenclatura** | `Fatura_AAAA-MM-DD.csv` |
| **Separador** | Ponto e vírgula (`;`) |
| **Codificação** | UTF-8 |

### 4.2 Arquivos disponíveis

| # | Arquivo | Mês referência |
|---|---------|----------------|
| 1 | Fatura_2025-03-20.csv | Março 2025 |
| 2 | Fatura_2025-04-20.csv | Abril 2025 |
| 3 | Fatura_2025-05-20.csv | Maio 2025 |
| 4 | Fatura_2025-06-20.csv | Junho 2025 |
| 5 | Fatura_2025-07-20.csv | Julho 2025 |
| 6 | Fatura_2025-08-20.csv | Agosto 2025 |
| 7 | Fatura_2025-09-20.csv | Setembro 2025 |
| 8 | Fatura_2025-10-20.csv | Outubro 2025 |
| 9 | Fatura_2025-11-20.csv | Novembro 2025 |
| 10 | Fatura_2025-12-20.csv | Dezembro 2025 |
| 11 | Fatura_2026-01-20.csv | Janeiro 2026 |
| 12 | Fatura_2026-02-20.csv | Fevereiro 2026 |

### 4.3 Colunas do CSV

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| Data de Compra | Texto (DD/MM/AAAA) | Data da transação |
| Nome no Cartão | Texto | Titular do cartão (anonimizado) |
| Final do Cartão | Numérico | Últimos 4 dígitos do cartão |
| Categoria | Texto | Categoria MCC da transação |
| Descrição | Texto | Nome do estabelecimento |
| Parcela | Texto | "Única", "1/3", "2/10", etc. |
| Valor (em US$) | Numérico | Valor em dólar (0 quando não aplicável) |
| Cotação (em R$) | Numérico | Taxa de câmbio usada |
| Valor (em R$) | Numérico | Valor em reais (negativo = estorno) |

## 5. Fases do Projeto

| Fase | Atividade | Entregável | Status |
|------|-----------|------------|--------|
| **1** | Análise do dataset e desenho do DW | Documento de modelagem (Star Schema) e dicionário de dados | ✅ Concluído |
| **2** | Implementação do processo ETL | Scripts Python + dados carregados no DW | ✅ Concluído |
| **3** | Validação e consultas analíticas | Conjunto de consultas SQL para perguntas de negócio | ✅ Concluído |
| **4** | Relatórios e dashboards | Ferramenta de BI acoplada com visualizações | 🔜 Futuro |
| **5** | Apresentação | Apresentação em aula com demonstração | 🔜 Futuro |

### 5.1 Detalhamento das fases atuais

#### Fase 1 — Modelagem

- Definição do modelo dimensional Star Schema.
- Identificação de 1 tabela fato (`fato_transacao`) e 4 dimensões (`dim_data`, `dim_titular`, `dim_categoria`, `dim_estabelecimento`).
- Criação do dicionário de dados com tipos, descrições e regras.
- Decisões de modelagem documentadas.

#### Fase 2 — ETL

- **Extract**: Leitura de todos os 12 arquivos CSV com `pandas`.
- **Transform**: Conversão de datas, normalização de valores numéricos, tratamento de campos nulos/hífens, extração de parcelas, geração de chaves substitutas para dimensões.
- **Load**: Criação das tabelas no PostgreSQL via DDL e inserção dos dados com `SQLAlchemy`/`psycopg2`.

#### Fase 3 — Validação e consultas

- Gasto total por titular no período e por mês.
- Top 10 categorias por valor.
- Evolução mensal do total gasto.
- Comparativo entre titulares.
- Principais estabelecimentos por valor.
- Comportamento de parcelamento (à vista vs parcelado).
- Dia da semana com mais transações.
- Estornos e créditos por titular/categoria.

## 6. Tecnologias Utilizadas

| Tecnologia | Uso |
|------------|-----|
| **Python 3.10+** | Linguagem do pipeline ETL |
| **pandas** | Leitura, limpeza e transformação dos dados |
| **SQLAlchemy** | ORM e conexão com PostgreSQL |
| **psycopg2** | Driver PostgreSQL para Python |
| **PostgreSQL 15+** | Banco de dados do Data Warehouse |

## 7. Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Inconsistência de encoding nos CSVs | Média | Alto | Forçar leitura UTF-8 com tratamento de erros |
| Dados duplicados entre faturas | Alta | Médio | Regra de deduplicação por chave composta |
| Campos vazios ou com hífens | Alta | Baixo | Regras de limpeza: `-` → "Não categorizado" |
| Valores decimais com formato inconsistente | Média | Alto | Normalização para float antes da carga |
| Transações com valor US$ e R$ em linhas separadas | Alta | Médio | Tratamento na transformação |

## 8. Critérios de Qualidade

- Todos os 12 arquivos CSV devem ser processados sem erro.
- As dimensões devem ser únicas (sem duplicatas de chave natural).
- A tabela fato deve referenciar corretamente todas as dimensões (integridade referencial).
- As consultas analíticas devem retornar resultados consistentes com os dados de origem.
- O pipeline ETL deve ser reproduzível (execução idempotente com full load).
