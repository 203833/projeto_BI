-- =============================================================================
-- Consultas Analíticas — Data Warehouse de Transações de Cartão de Crédito
-- Fase 3: Validação e análises de negócio
-- =============================================================================

-- =============================================================================
-- 1. Gasto total por titular no período completo
-- =============================================================================

SELECT
    t.nome_titular,
    t.final_cartao,
    COUNT(f.id_transacao)                                        AS qtd_transacoes,
    SUM(f.valor_brl)                                             AS total_brl,
    SUM(CASE WHEN f.valor_brl > 0 THEN f.valor_brl ELSE 0 END)  AS total_debitos,
    SUM(CASE WHEN f.valor_brl < 0 THEN f.valor_brl ELSE 0 END)  AS total_creditos,
    ROUND(AVG(f.valor_brl), 2)                                   AS media_por_transacao
FROM dw.fato_transacao f
JOIN dw.dim_titular t ON f.id_titular = t.id_titular
GROUP BY t.nome_titular, t.final_cartao
ORDER BY total_brl DESC;


-- =============================================================================
-- 2. Gasto mensal por titular (série temporal)
-- =============================================================================

SELECT
    t.nome_titular,
    d.ano,
    d.mes,
    d.nome_mes,
    COUNT(f.id_transacao)  AS qtd_transacoes,
    SUM(f.valor_brl)       AS total_brl
FROM dw.fato_transacao f
JOIN dw.dim_titular t ON f.id_titular = t.id_titular
JOIN dw.dim_data    d ON f.id_data   = d.id_data
GROUP BY t.nome_titular, d.ano, d.mes, d.nome_mes
ORDER BY t.nome_titular, d.ano, d.mes;


-- =============================================================================
-- 3. Top 10 categorias por valor total (apenas débitos)
-- =============================================================================

SELECT
    c.nome_categoria,
    COUNT(f.id_transacao)  AS qtd_transacoes,
    SUM(f.valor_brl)       AS total_brl,
    ROUND(AVG(f.valor_brl), 2) AS media_brl
FROM dw.fato_transacao f
JOIN dw.dim_categoria c ON f.id_categoria = c.id_categoria
WHERE f.valor_brl > 0
GROUP BY c.nome_categoria
ORDER BY total_brl DESC
LIMIT 10;


-- =============================================================================
-- 4. Evolução mensal do total gasto (série temporal geral)
-- =============================================================================

SELECT
    d.ano,
    d.mes,
    d.nome_mes,
    COUNT(f.id_transacao)                                        AS qtd_transacoes,
    SUM(f.valor_brl)                                             AS total_liquido,
    SUM(CASE WHEN f.valor_brl > 0 THEN f.valor_brl ELSE 0 END)  AS total_debitos,
    SUM(CASE WHEN f.valor_brl < 0 THEN f.valor_brl ELSE 0 END)  AS total_creditos
FROM dw.fato_transacao f
JOIN dw.dim_data d ON f.id_data = d.id_data
GROUP BY d.ano, d.mes, d.nome_mes
ORDER BY d.ano, d.mes;


-- =============================================================================
-- 5. Comparativo entre titulares (valor médio por transação e quantidade)
-- =============================================================================

SELECT
    t.nome_titular,
    COUNT(f.id_transacao)                              AS qtd_transacoes,
    SUM(f.valor_brl)                                   AS total_brl,
    ROUND(AVG(f.valor_brl), 2)                         AS media_por_transacao,
    MIN(f.valor_brl)                                   AS menor_valor,
    MAX(f.valor_brl)                                   AS maior_valor,
    COUNT(DISTINCT t.final_cartao)                     AS qtd_cartoes
FROM dw.fato_transacao f
JOIN dw.dim_titular t ON f.id_titular = t.id_titular
WHERE f.valor_brl > 0
GROUP BY t.nome_titular
ORDER BY total_brl DESC;


-- =============================================================================
-- 6. Top 15 estabelecimentos por valor total
-- =============================================================================

SELECT
    e.nome_estabelecimento,
    COUNT(f.id_transacao)  AS qtd_transacoes,
    SUM(f.valor_brl)       AS total_brl,
    ROUND(AVG(f.valor_brl), 2) AS media_brl
FROM dw.fato_transacao f
JOIN dw.dim_estabelecimento e ON f.id_estabelecimento = e.id_estabelecimento
WHERE f.valor_brl > 0
GROUP BY e.nome_estabelecimento
ORDER BY total_brl DESC
LIMIT 15;


-- =============================================================================
-- 7. Comportamento de parcelamento: à vista vs parcelado
-- =============================================================================

SELECT
    CASE
        WHEN f.total_parcelas = 1 THEN 'À vista (Única)'
        WHEN f.total_parcelas > 1 THEN 'Parcelado'
        ELSE 'Não identificado'
    END AS tipo_compra,
    COUNT(f.id_transacao)      AS qtd_transacoes,
    SUM(f.valor_brl)           AS total_brl,
    ROUND(AVG(f.valor_brl), 2) AS media_brl
FROM dw.fato_transacao f
WHERE f.valor_brl > 0
GROUP BY tipo_compra
ORDER BY total_brl DESC;


-- =============================================================================
-- 8. Distribuição de parcelas (quantidade de vezes por total_parcelas)
-- =============================================================================

SELECT
    f.total_parcelas,
    f.parcela_texto AS exemplo_parcela,
    COUNT(f.id_transacao) AS qtd_transacoes,
    SUM(f.valor_brl)      AS total_brl
FROM dw.fato_transacao f
WHERE f.valor_brl > 0
  AND f.total_parcelas IS NOT NULL
GROUP BY f.total_parcelas, f.parcela_texto
ORDER BY f.total_parcelas, qtd_transacoes DESC;


-- =============================================================================
-- 9. Dia da semana com mais transações e maior volume
-- =============================================================================

SELECT
    d.dia_semana,
    d.nome_dia,
    COUNT(f.id_transacao)      AS qtd_transacoes,
    SUM(f.valor_brl)           AS total_brl,
    ROUND(AVG(f.valor_brl), 2) AS media_brl
FROM dw.fato_transacao f
JOIN dw.dim_data d ON f.id_data = d.id_data
WHERE f.valor_brl > 0
GROUP BY d.dia_semana, d.nome_dia
ORDER BY qtd_transacoes DESC;


-- =============================================================================
-- 10. Estornos e créditos: total e impacto por titular
-- =============================================================================

SELECT
    t.nome_titular,
    COUNT(f.id_transacao)  AS qtd_estornos,
    SUM(f.valor_brl)       AS total_estornos_brl,
    MIN(f.valor_brl)       AS maior_estorno
FROM dw.fato_transacao f
JOIN dw.dim_titular t ON f.id_titular = t.id_titular
WHERE f.valor_brl < 0
GROUP BY t.nome_titular
ORDER BY total_estornos_brl ASC;


-- =============================================================================
-- 11. Estornos e créditos por categoria
-- =============================================================================

SELECT
    c.nome_categoria,
    COUNT(f.id_transacao)  AS qtd_estornos,
    SUM(f.valor_brl)       AS total_estornos_brl
FROM dw.fato_transacao f
JOIN dw.dim_categoria c ON f.id_categoria = c.id_categoria
WHERE f.valor_brl < 0
GROUP BY c.nome_categoria
ORDER BY total_estornos_brl ASC;


-- =============================================================================
-- 12. Transações em moeda estrangeira (USD)
-- =============================================================================

SELECT
    t.nome_titular,
    d.ano,
    d.mes,
    d.nome_mes,
    e.nome_estabelecimento,
    f.valor_usd,
    f.cotacao,
    f.valor_brl
FROM dw.fato_transacao f
JOIN dw.dim_titular        t ON f.id_titular         = t.id_titular
JOIN dw.dim_data           d ON f.id_data            = d.id_data
JOIN dw.dim_estabelecimento e ON f.id_estabelecimento = e.id_estabelecimento
WHERE f.valor_usd > 0
ORDER BY d.ano, d.mes, t.nome_titular;


-- =============================================================================
-- 13. Ranking de categorias por titular
-- =============================================================================

SELECT
    t.nome_titular,
    c.nome_categoria,
    COUNT(f.id_transacao)  AS qtd_transacoes,
    SUM(f.valor_brl)       AS total_brl,
    RANK() OVER (
        PARTITION BY t.nome_titular
        ORDER BY SUM(f.valor_brl) DESC
    ) AS ranking
FROM dw.fato_transacao f
JOIN dw.dim_titular   t ON f.id_titular   = t.id_titular
JOIN dw.dim_categoria c ON f.id_categoria = c.id_categoria
WHERE f.valor_brl > 0
GROUP BY t.nome_titular, c.nome_categoria
ORDER BY t.nome_titular, ranking;


-- =============================================================================
-- 14. Evolução trimestral por categoria (análise de tendência)
-- =============================================================================

SELECT
    d.ano,
    d.trimestre,
    c.nome_categoria,
    COUNT(f.id_transacao)  AS qtd_transacoes,
    SUM(f.valor_brl)       AS total_brl
FROM dw.fato_transacao f
JOIN dw.dim_data      d ON f.id_data      = d.id_data
JOIN dw.dim_categoria c ON f.id_categoria = c.id_categoria
WHERE f.valor_brl > 0
GROUP BY d.ano, d.trimestre, c.nome_categoria
ORDER BY d.ano, d.trimestre, total_brl DESC;


-- =============================================================================
-- 15. Resumo geral do Data Warehouse (KPIs)
-- =============================================================================

SELECT
    COUNT(*)                                                     AS total_registros,
    COUNT(DISTINCT d.data_compra)                                AS total_dias,
    COUNT(DISTINCT t.id_titular)                                 AS total_titulares,
    COUNT(DISTINCT c.id_categoria)                               AS total_categorias,
    COUNT(DISTINCT e.id_estabelecimento)                         AS total_estabelecimentos,
    SUM(f.valor_brl)                                             AS total_liquido_brl,
    SUM(CASE WHEN f.valor_brl > 0 THEN f.valor_brl ELSE 0 END)  AS total_debitos_brl,
    SUM(CASE WHEN f.valor_brl < 0 THEN f.valor_brl ELSE 0 END)  AS total_creditos_brl,
    SUM(f.valor_usd)                                             AS total_usd,
    ROUND(AVG(CASE WHEN f.valor_brl > 0 THEN f.valor_brl END), 2) AS media_debito_brl,
    MIN(d.data_compra)                                           AS primeira_transacao,
    MAX(d.data_compra)                                           AS ultima_transacao
FROM dw.fato_transacao f
JOIN dw.dim_data            d ON f.id_data            = d.id_data
JOIN dw.dim_titular         t ON f.id_titular         = t.id_titular
JOIN dw.dim_categoria       c ON f.id_categoria       = c.id_categoria
JOIN dw.dim_estabelecimento e ON f.id_estabelecimento = e.id_estabelecimento;
