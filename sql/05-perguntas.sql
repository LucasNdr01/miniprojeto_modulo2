-- =====================================================================================
--  ARQUIVO 5:  AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 04-fato.sql
--
--  Cada pergunta e UMA consulta: um SELECT com JOIN e GROUP BY. A subconsulta
--  aparece na P2 e na P5, e serve para trazer o total da rede como denominador.
-- =====================================================================================

USE dw_pata_amiga;

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Media (AVG) dos quatro intervalos ja calculados na carga, agrupada por porte
--  de loja. AVG ignora NULL - por isso a etapa nao cumprida foi gravada como NULL.
--  dias_total_ate_entrega e o processo inteiro, nao um dos quatro intervalos.

-- >>> ESCREVA AQUI a consulta da P1

SELECT
    dl.porte,
    ROUND(AVG(fp.dias_integracao_separacao),2) AS erp_separacao,
    ROUND(AVG(fp.dias_separacao_nota),2) AS separacao_nota,
    ROUND(AVG(fp.dias_nota_despacho),2) AS nota_despacho,
    ROUND(AVG(fp.dias_despacho_entrega),2) AS despacho_entrega,
    ROUND(AVG(fp.dias_total_ate_entrega),2) AS total_entrega
FROM fato_pedido fp
JOIN dim_loja dl ON fp.sk_loja = dl.sk_loja
WHERE fp.sk_loja <> -1
GROUP BY dl.porte
ORDER BY dl.porte;

-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_categoria. Agrupe pelo nome_categoria
--  PADRONIZADO (nunca pela grafia crua). O percentual do total usa uma
--  subconsulta com o faturamento da rede como denominador.

-- >>> ESCREVA AQUI a consulta da P2

WITH resultado AS (
    SELECT
        dc.nome_categoria,
        ROUND(SUM(fp.vl_liquido), 2) AS faturamento,
        ROUND(
            SUM(fp.vl_liquido) /
            (SELECT SUM(vl_liquido) FROM fato_pedido) * 100,
            2
        ) AS percentual_faturamento
    FROM fato_pedido fp
    JOIN dim_categoria dc
        ON fp.sk_categoria = dc.sk_categoria
    WHERE fp.sk_categoria <> -1
    GROUP BY dc.nome_categoria
)

SELECT
    nome_categoria,
    faturamento,
    percentual_faturamento,
    CASE
        WHEN ROW_NUMBER() OVER (ORDER BY faturamento DESC) = 1
        THEN ROUND((SELECT SUM(vl_liquido) FROM fato_pedido), 2)
        ELSE NULL
    END AS faturamento_total
FROM resultado
ORDER BY faturamento DESC;

-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Aqui NAO ha JOIN: desconto e canal foram padronizados na carga e moram na
--  propria fato. Compare o TICKET MEDIO com e sem desconto DENTRO de cada canal.
--  Confira se o WhatsApp aparece - se nao, o CASE do arquivo 04 testou APP antes
--  de WHATS.

-- >>> ESCREVA AQUI a consulta da P3

SELECT
    canal_pedido,
    ROUND(AVG(CASE WHEN houve_desconto = 'Nao' THEN vl_liquido END), 2) AS ticket_sem_desconto,
    ROUND(AVG(CASE WHEN houve_desconto = 'Sim' THEN vl_liquido END), 2) AS ticket_com_desconto,
    ROUND(SUM(vl_liquido), 2) AS faturamento,
    ROUND(SUM(vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido) * 100, 2) AS percentual_faturamento
FROM fato_pedido
WHERE vl_liquido IS NOT NULL
GROUP BY canal_pedido
ORDER BY canal_pedido;

-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_praca e a ponte.
--  Caminho: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a ponte
--  entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido, uma por
--  praca - isso esta certo. Multiplique por b.fator_publico para o faturamento
--  nao ser contado duas vezes.

-- >>> ESCREVA AQUI a consulta da P4

SELECT
    dp.nome_praca,
    ROUND(SUM(fp.vl_liquido * b.fator_publico), 2) AS faturamento,
    ROUND(
        SUM(fp.vl_liquido * b.fator_publico) /
        (SELECT SUM(vl_liquido) FROM fato_pedido) * 100,
        2
    ) AS percentual_faturamento
FROM fato_pedido fp
JOIN dim_loja dl
    ON fp.sk_loja = dl.sk_loja
JOIN bridge_loja_praca b
    ON dl.cod_loja = b.cod_loja
JOIN dim_praca dp
    ON b.sk_praca = dp.sk_praca
WHERE fp.sk_loja <> -1
GROUP BY dp.nome_praca
ORDER BY faturamento DESC;

-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  (a) Ranqueie as lojas por itens POR MIL HABITANTES (numerador na fato,
--      denominador na dimensao), calculado AQUI na consulta - nunca gravado
--      pronto. Cruze com o tempo medio de entrega.
--  (b) Mostre o faturamento por faixa de franquia e explique por que ele NAO
--      responde "quanto veio de lojas que JA ERAM Ouro na data do pedido": o
--      cadastro so tem a foto de hoje.
--  (c) Meca o que ficou de fora: pedidos sem loja, entregas nao concluidas,
--      itens e valores em branco.

-- >>> ESCREVA AQUI as consultas da P5

-- A)
SELECT
    dl.nome_loja,
    dl.cidade,
    dl.porte,
    ROUND(
        SUM(fp.qt_itens) / dl.populacao_cidade * 1000,
        2
    ) AS itens_por_mil_habitantes,
    ROUND(AVG(fp.dias_total_ate_entrega), 2) AS tempo_medio_entrega
FROM fato_pedido fp
JOIN dim_loja dl
    ON fp.sk_loja = dl.sk_loja
WHERE fp.sk_loja <> -1
    AND fp.qt_itens IS NOT NULL
    AND dl.populacao_cidade IS NOT NULL
GROUP BY
    dl.sk_loja,
    dl.nome_loja,
    dl.cidade,
    dl.porte,
    dl.populacao_cidade
ORDER BY itens_por_mil_habitantes DESC;

-- B)
SELECT
    dl.faixa_franquia,
    ROUND(SUM(fp.vl_liquido), 2) AS faturamento,
    COUNT(*) AS quantidade_pedidos
FROM fato_pedido fp
JOIN dim_loja dl
    ON fp.sk_loja = dl.sk_loja
WHERE fp.sk_loja <> -1
GROUP BY dl.faixa_franquia
ORDER BY faturamento DESC;

-- C)
SELECT
    COUNT(CASE WHEN sk_loja = -1 THEN 1 END) AS pedidos_sem_loja,
    COUNT(CASE WHEN sk_tempo_entrega = -1 THEN 1 END) AS entregas_nao_concluidas,
    COUNT(CASE WHEN qt_itens IS NULL THEN 1 END) AS itens_em_branco,
    COUNT(CASE WHEN vl_liquido IS NULL THEN 1 END) AS valores_em_branco
FROM fato_pedido;