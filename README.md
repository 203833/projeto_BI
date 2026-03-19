# Data Warehouse — Transações de Cartão de Crédito

**Curso**: Análise e Desenvolvimento de Sistemas
**Disciplina**: Business Intelligence e Data Warehouse

---

## Sobre o Projeto

Data Warehouse construído a partir de dados reais (anonimizados) de 12 faturas mensais de cartão de crédito (Mar/2025 a Fev/2026), utilizando modelagem **Star Schema** com pipeline **ETL** em Python e banco **PostgreSQL**.

---

## Pré-requisitos

| Software   | Versão mínima |
|------------|---------------|
| Python     | 3.10+         |
| PostgreSQL | 15+           |
| pip        | 22+           |

**Instalação (Ubuntu/Debian/Pop!_OS):**

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv postgresql postgresql-client
```

---

## Como Executar

### 1. Iniciar o PostgreSQL e criar o banco

```bash
sudo systemctl start postgresql
sudo -u postgres psql -c "CREATE DATABASE dw_transacoes WITH ENCODING = 'UTF8';"
```

### 2. Criar ambiente virtual e instalar dependências

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r etl/requirements.txt
```

### 3. Configurar variáveis de ambiente

```bash
cp etl/.env.example etl/.env
```

Se a senha do PostgreSQL for diferente de `postgres`, edite o arquivo `etl/.env`.

### 4. Executar o pipeline ETL

```bash
cd etl
python etl_pipeline.py
```

### 5. Executar as consultas analíticas

```bash
cd ..
sudo -u postgres psql -d dw_transacoes -f sql/02_consultas_analiticas.sql
```

---

## Estrutura do Projeto

```
projeto_BI/
├── README.md
├── docs/
│   ├── 01_plano_projeto.md
│   ├── 02_modelagem_dw.md
│   └── 03_dicionario_dados.md
├── sql/
│   ├── 01_create_database.sql
│   └── 02_consultas_analiticas.sql
├── etl/
│   ├── etl_pipeline.py
│   ├── requirements.txt
│   └── .env.example
└── data/
    └── Fatura_*.csv (12 arquivos)
```

---

## Tecnologias

- **Python** — pandas, SQLAlchemy, psycopg2
- **PostgreSQL** — Data Warehouse com Star Schema
- **Modelagem** — 4 dimensões + 1 tabela fato
