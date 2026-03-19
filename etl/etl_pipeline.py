"""
ETL Pipeline — Data Warehouse de Transações de Cartão de Crédito

Pipeline completo para:
  1. Criar as tabelas do DW no PostgreSQL (DDL)
  2. Extrair dados dos 12 arquivos CSV de faturas
  3. Transformar (limpeza, normalização, geração de chaves)
  4. Carregar dimensões e fato no banco de dados
"""

import os
import glob
import re
import logging
from datetime import datetime
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Configuração de logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuração do banco de dados
# ---------------------------------------------------------------------------
load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "dw_transacoes")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

DATA_DIR = Path(__file__).resolve().parent.parent / "data"

DIAS_SEMANA = {
    0: "Segunda-feira",
    1: "Terça-feira",
    2: "Quarta-feira",
    3: "Quinta-feira",
    4: "Sexta-feira",
    5: "Sábado",
    6: "Domingo",
}

NOMES_MES = {
    1: "Janeiro",
    2: "Fevereiro",
    3: "Março",
    4: "Abril",
    5: "Maio",
    6: "Junho",
    7: "Julho",
    8: "Agosto",
    9: "Setembro",
    10: "Outubro",
    11: "Novembro",
    12: "Dezembro",
}


# ============================================================================
# FASE 1 — EXTRACT
# ============================================================================

def extract_csv_files(data_dir: Path) -> pd.DataFrame:
    """Lê todos os arquivos Fatura_*.csv do diretório e concatena em um DataFrame."""
    csv_pattern = str(data_dir / "Fatura_*.csv")
    files = sorted(glob.glob(csv_pattern))

    if not files:
        raise FileNotFoundError(f"Nenhum arquivo CSV encontrado em: {csv_pattern}")

    log.info("Encontrados %d arquivos CSV para processar", len(files))

    frames = []
    for filepath in files:
        filename = os.path.basename(filepath)
        log.info("  Lendo: %s", filename)

        df = pd.read_csv(
            filepath,
            sep=";",
            encoding="utf-8",
            dtype=str,
        )
        df["arquivo_origem"] = filename
        frames.append(df)

    combined = pd.concat(frames, ignore_index=True)
    log.info("Total de registros extraídos: %d", len(combined))
    return combined


# ============================================================================
# FASE 2 — TRANSFORM
# ============================================================================

def parse_parcela(parcela_texto: str) -> tuple:
    """
    Extrai num_parcela e total_parcelas a partir do texto da parcela.
    - "Única" → (1, 1)
    - "2/10"  → (2, 10)
    - Outros  → (None, None)
    """
    if not parcela_texto or pd.isna(parcela_texto):
        return None, None

    texto = parcela_texto.strip()

    if texto.lower() == "única":
        return 1, 1

    match = re.match(r"^(\d+)/(\d+)$", texto)
    if match:
        return int(match.group(1)), int(match.group(2))

    return None, None


def clean_numeric(value: str) -> float:
    """Converte string numérica para float, tratando vírgulas e valores vazios."""
    if not value or pd.isna(value) or str(value).strip() in ("", "-"):
        return 0.0

    cleaned = str(value).strip().replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        return 0.0


def transform(df: pd.DataFrame) -> pd.DataFrame:
    """Aplica todas as transformações nos dados brutos."""
    log.info("Iniciando transformações...")

    result = df.copy()

    # --- Limpeza de espaços em branco ---
    for col in result.columns:
        if result[col].dtype == object:
            result[col] = result[col].str.strip()

    # --- Data de Compra → datetime ---
    result["data_compra"] = pd.to_datetime(
        result["Data de Compra"], format="%d/%m/%Y", errors="coerce"
    )
    invalid_dates = result["data_compra"].isna().sum()
    if invalid_dates > 0:
        log.warning("  %d registros com data inválida (serão removidos)", invalid_dates)
        result = result.dropna(subset=["data_compra"])

    # --- Atributos derivados da data ---
    result["dia"] = result["data_compra"].dt.day
    result["mes"] = result["data_compra"].dt.month
    result["trimestre"] = result["data_compra"].dt.quarter
    result["ano"] = result["data_compra"].dt.year
    result["dia_semana"] = result["data_compra"].dt.weekday
    result["nome_dia"] = result["dia_semana"].map(DIAS_SEMANA)
    result["nome_mes"] = result["mes"].map(NOMES_MES)

    # --- Titular ---
    result["nome_titular"] = result["Nome no Cartão"].fillna("Não informado").str.strip()
    result["final_cartao"] = result["Final do Cartão"].fillna("0000").astype(str).str.strip()

    # --- Categoria ---
    result["nome_categoria"] = result["Categoria"].fillna("Não categorizado").str.strip()
    result["nome_categoria"] = result["nome_categoria"].replace(
        {"-": "Não categorizado", "": "Não categorizado"}
    )

    # --- Estabelecimento ---
    result["nome_estabelecimento"] = result["Descrição"].fillna("Não informado").str.strip()
    result["nome_estabelecimento"] = result["nome_estabelecimento"].str.strip('"')
    result["nome_estabelecimento"] = result["nome_estabelecimento"].replace(
        {"": "Não informado", "-": "Não informado"}
    )

    # --- Valores numéricos ---
    result["valor_brl"] = result["Valor (em R$)"].apply(clean_numeric)
    result["valor_usd"] = result["Valor (em US$)"].apply(clean_numeric)
    result["cotacao"] = result["Cotação (em R$)"].apply(clean_numeric)

    # --- Parcelas ---
    result["parcela_texto"] = result["Parcela"].fillna("Única").str.strip()
    parcelas = result["parcela_texto"].apply(parse_parcela)
    result["num_parcela"] = parcelas.apply(lambda x: x[0])
    result["total_parcelas"] = parcelas.apply(lambda x: x[1])

    log.info("Transformações concluídas. Registros: %d", len(result))
    return result


# ============================================================================
# FASE 3 — LOAD
# ============================================================================

def create_schema_and_tables(engine):
    """Cria o schema e as tabelas do DW (full load — drop e recria)."""
    ddl_path = Path(__file__).resolve().parent.parent / "sql" / "01_create_database.sql"

    log.info("Executando DDL: %s", ddl_path)

    with open(ddl_path, "r", encoding="utf-8") as f:
        ddl_sql = f.read()

    with engine.begin() as conn:
        for statement in ddl_sql.split(";"):
            stmt = statement.strip()
            if stmt and not stmt.startswith("--"):
                try:
                    conn.execute(text(stmt))
                except Exception as e:
                    log.warning("DDL ignorado (possível CREATE DATABASE): %s", str(e)[:100])

    log.info("Schema e tabelas criados com sucesso")


def load_dim_data(engine, df: pd.DataFrame):
    """Carrega a dimensão dim_data."""
    dim_data = (
        df[["data_compra", "dia", "mes", "trimestre", "ano", "dia_semana", "nome_dia", "nome_mes"]]
        .drop_duplicates(subset=["data_compra"])
        .sort_values("data_compra")
        .reset_index(drop=True)
    )

    log.info("Carregando dim_data: %d registros", len(dim_data))

    dim_data.to_sql(
        "dim_data",
        engine,
        schema="dw",
        if_exists="append",
        index=False,
    )

    with engine.connect() as conn:
        result = conn.execute(text("SELECT id_data, data_compra FROM dw.dim_data"))
        lookup = {row[1]: row[0] for row in result}

    return lookup


def load_dim_titular(engine, df: pd.DataFrame):
    """Carrega a dimensão dim_titular."""
    dim_titular = (
        df[["nome_titular", "final_cartao"]]
        .drop_duplicates()
        .sort_values(["nome_titular", "final_cartao"])
        .reset_index(drop=True)
    )

    log.info("Carregando dim_titular: %d registros", len(dim_titular))

    dim_titular.to_sql(
        "dim_titular",
        engine,
        schema="dw",
        if_exists="append",
        index=False,
    )

    with engine.connect() as conn:
        result = conn.execute(
            text("SELECT id_titular, nome_titular, final_cartao FROM dw.dim_titular")
        )
        lookup = {(row[1], row[2]): row[0] for row in result}

    return lookup


def load_dim_categoria(engine, df: pd.DataFrame):
    """Carrega a dimensão dim_categoria."""
    dim_cat = (
        df[["nome_categoria"]]
        .drop_duplicates()
        .sort_values("nome_categoria")
        .reset_index(drop=True)
    )

    log.info("Carregando dim_categoria: %d registros", len(dim_cat))

    dim_cat.to_sql(
        "dim_categoria",
        engine,
        schema="dw",
        if_exists="append",
        index=False,
    )

    with engine.connect() as conn:
        result = conn.execute(
            text("SELECT id_categoria, nome_categoria FROM dw.dim_categoria")
        )
        lookup = {row[1]: row[0] for row in result}

    return lookup


def load_dim_estabelecimento(engine, df: pd.DataFrame):
    """Carrega a dimensão dim_estabelecimento."""
    dim_estab = (
        df[["nome_estabelecimento"]]
        .drop_duplicates()
        .sort_values("nome_estabelecimento")
        .reset_index(drop=True)
    )

    log.info("Carregando dim_estabelecimento: %d registros", len(dim_estab))

    dim_estab.to_sql(
        "dim_estabelecimento",
        engine,
        schema="dw",
        if_exists="append",
        index=False,
    )

    with engine.connect() as conn:
        result = conn.execute(
            text("SELECT id_estabelecimento, nome_estabelecimento FROM dw.dim_estabelecimento")
        )
        lookup = {row[1]: row[0] for row in result}

    return lookup


def load_fato_transacao(
    engine,
    df: pd.DataFrame,
    lookup_data: dict,
    lookup_titular: dict,
    lookup_categoria: dict,
    lookup_estabelecimento: dict,
):
    """Carrega a tabela fato, resolvendo FKs via lookups das dimensões."""
    log.info("Montando tabela fato com resolução de chaves...")

    fato = pd.DataFrame()

    fato["id_data"] = df["data_compra"].map(
        lambda d: lookup_data.get(d.date() if hasattr(d, "date") else d)
    )
    fato["id_titular"] = df.apply(
        lambda row: lookup_titular.get((row["nome_titular"], row["final_cartao"])), axis=1
    )
    fato["id_categoria"] = df["nome_categoria"].map(lookup_categoria)
    fato["id_estabelecimento"] = df["nome_estabelecimento"].map(lookup_estabelecimento)
    fato["valor_brl"] = df["valor_brl"]
    fato["valor_usd"] = df["valor_usd"]
    fato["cotacao"] = df["cotacao"]
    fato["parcela_texto"] = df["parcela_texto"]
    fato["num_parcela"] = df["num_parcela"]
    fato["total_parcelas"] = df["total_parcelas"]
    fato["arquivo_origem"] = df["arquivo_origem"]

    nulls_data = fato["id_data"].isna().sum()
    nulls_titular = fato["id_titular"].isna().sum()
    nulls_cat = fato["id_categoria"].isna().sum()
    nulls_estab = fato["id_estabelecimento"].isna().sum()

    if nulls_data + nulls_titular + nulls_cat + nulls_estab > 0:
        log.warning(
            "FKs nulas detectadas — data: %d, titular: %d, categoria: %d, estabelecimento: %d",
            nulls_data, nulls_titular, nulls_cat, nulls_estab,
        )
        fato = fato.dropna(subset=["id_data", "id_titular", "id_categoria", "id_estabelecimento"])

    fato["id_data"] = fato["id_data"].astype(int)
    fato["id_titular"] = fato["id_titular"].astype(int)
    fato["id_categoria"] = fato["id_categoria"].astype(int)
    fato["id_estabelecimento"] = fato["id_estabelecimento"].astype(int)

    log.info("Carregando fato_transacao: %d registros", len(fato))

    fato.to_sql(
        "fato_transacao",
        engine,
        schema="dw",
        if_exists="append",
        index=False,
    )


# ============================================================================
# VALIDAÇÃO
# ============================================================================

def validate_load(engine):
    """Executa validações básicas após a carga."""
    log.info("=" * 60)
    log.info("VALIDAÇÃO PÓS-CARGA")
    log.info("=" * 60)

    queries = {
        "dim_data": "SELECT COUNT(*) FROM dw.dim_data",
        "dim_titular": "SELECT COUNT(*) FROM dw.dim_titular",
        "dim_categoria": "SELECT COUNT(*) FROM dw.dim_categoria",
        "dim_estabelecimento": "SELECT COUNT(*) FROM dw.dim_estabelecimento",
        "fato_transacao": "SELECT COUNT(*) FROM dw.fato_transacao",
    }

    with engine.connect() as conn:
        for table, query in queries.items():
            result = conn.execute(text(query))
            count = result.scalar()
            log.info("  %-25s: %d registros", table, count)

        result = conn.execute(text("""
            SELECT
                SUM(valor_brl) AS total_brl,
                SUM(CASE WHEN valor_brl > 0 THEN valor_brl ELSE 0 END) AS total_debitos,
                SUM(CASE WHEN valor_brl < 0 THEN valor_brl ELSE 0 END) AS total_creditos,
                COUNT(*) AS total_transacoes
            FROM dw.fato_transacao
        """))
        row = result.fetchone()
        log.info("  Total BRL:        R$ %.2f", row[0] or 0)
        log.info("  Total débitos:    R$ %.2f", row[1] or 0)
        log.info("  Total créditos:   R$ %.2f", row[2] or 0)
        log.info("  Total transações: %d", row[3] or 0)

        result = conn.execute(text("""
            SELECT f.arquivo_origem, COUNT(*) AS qtd
            FROM dw.fato_transacao f
            GROUP BY f.arquivo_origem
            ORDER BY f.arquivo_origem
        """))
        log.info("  Transações por arquivo:")
        for row in result:
            log.info("    %-30s: %d", row[0], row[1])

    log.info("=" * 60)
    log.info("Validação concluída com sucesso!")


# ============================================================================
# ORQUESTRADOR PRINCIPAL
# ============================================================================

def run_etl():
    """Executa o pipeline ETL completo."""
    start_time = datetime.now()
    log.info("=" * 60)
    log.info("INÍCIO DO PIPELINE ETL")
    log.info("=" * 60)

    engine = create_engine(DATABASE_URL)

    # Fase 0: Criar schema e tabelas
    log.info("[FASE 0] Criando schema e tabelas...")
    create_schema_and_tables(engine)

    # Fase 1: Extract
    log.info("[FASE 1] Extraindo dados dos CSVs...")
    raw_df = extract_csv_files(DATA_DIR)

    # Fase 2: Transform
    log.info("[FASE 2] Transformando dados...")
    transformed_df = transform(raw_df)

    # Fase 3: Load
    log.info("[FASE 3] Carregando dados no Data Warehouse...")

    log.info("  Carregando dimensões...")
    lookup_data = load_dim_data(engine, transformed_df)
    lookup_titular = load_dim_titular(engine, transformed_df)
    lookup_categoria = load_dim_categoria(engine, transformed_df)
    lookup_estabelecimento = load_dim_estabelecimento(engine, transformed_df)

    log.info("  Carregando fato...")
    load_fato_transacao(
        engine,
        transformed_df,
        lookup_data,
        lookup_titular,
        lookup_categoria,
        lookup_estabelecimento,
    )

    # Validação
    validate_load(engine)

    elapsed = datetime.now() - start_time
    log.info("Pipeline ETL concluído em %s", elapsed)


if __name__ == "__main__":
    run_etl()
