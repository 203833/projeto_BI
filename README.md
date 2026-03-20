Instalação para linux

sudo apt update
sudo apt install -y python3 python3-pip python3-venv postgresql postgresql-client

1. Iniciar o PostgreSQL e criar o banco

sudo systemctl start postgresql
sudo -u postgres psql -c "CREATE DATABASE dw_transacoes WITH ENCODING = 'UTF8';"

2. Criar ambiente virtual e instalar dependências

python3 -m venv venv
source venv/bin/activate
pip install -r etl/requirements.txt

3. Configurar variáveis de ambiente

cp etl/.env.example etl/.env

4. Executar o pipeline ETL

cd etl
python etl_pipeline.py

5. Executar as consultas analíticas

cd ..
sudo -u postgres psql -d dw_transacoes -f sql/02_consultas_analiticas.sql
