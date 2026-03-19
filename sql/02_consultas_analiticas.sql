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


SELECT
    c.nome_categoria,
    COUNT(f.id_transacao)  AS qtd_estornos,
    SUM(f.valor_brl)       AS total_estornos_brl
FROM dw.fato_transacao f
JOIN dw.dim_categoria c ON f.id_categoria = c.id_categoria
WHERE f.valor_brl < 0
GROUP BY c.nome_categoria
ORDER BY total_estornos_brl ASC;


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
