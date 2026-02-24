-- ==========================================================
-- Farmer Analytics RPC Functions
-- Provides server-side aggregation for the farmer analytics dashboard.
-- ==========================================================

-- 1. Sales by produce category for a given time window
CREATE OR REPLACE FUNCTION farmer_sales_by_category(
    p_farmer_id uuid,
    p_days integer DEFAULT 30
)
RETURNS TABLE(
    category_id uuid,
    category_name_en text,
    category_name_ne text,
    category_icon text,
    total_qty_kg numeric,
    total_revenue numeric,
    order_count bigint
) LANGUAGE plpgsql STABLE SECURITY INVOKER AS $$
BEGIN
    IF p_days < 1 OR p_days > 365 THEN
        RAISE EXCEPTION 'p_days must be between 1 and 365';
    END IF;

    RETURN QUERY
    SELECT
        pc.id AS category_id,
        pc.name_en AS category_name_en,
        pc.name_ne AS category_name_ne,
        pc.icon AS category_icon,
        COALESCE(SUM(oi.quantity_kg), 0) AS total_qty_kg,
        COALESCE(SUM(oi.subtotal), 0) AS total_revenue,
        COUNT(DISTINCT o.id) AS order_count
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    JOIN produce_listings pl ON pl.id = oi.listing_id
    JOIN produce_categories pc ON pc.id = pl.category_id
    WHERE oi.farmer_id = p_farmer_id
      AND o.status = 'delivered'
      AND o.created_at >= (now() - make_interval(days => p_days))
    GROUP BY pc.id, pc.name_en, pc.name_ne, pc.icon
    ORDER BY total_revenue DESC;
END;
$$;

-- 2. Revenue trend over time (daily buckets)
-- Joins order_items first (filtered by farmer), then orders,
-- ensuring we only count this farmer's orders per day.
CREATE OR REPLACE FUNCTION farmer_revenue_trend(
    p_farmer_id uuid,
    p_days integer DEFAULT 30
)
RETURNS TABLE(
    day date,
    revenue numeric,
    order_count bigint
) LANGUAGE plpgsql STABLE SECURITY INVOKER AS $$
BEGIN
    IF p_days < 1 OR p_days > 365 THEN
        RAISE EXCEPTION 'p_days must be between 1 and 365';
    END IF;

    RETURN QUERY
    SELECT
        d.day,
        COALESCE(SUM(agg.daily_revenue), 0) AS revenue,
        COALESCE(SUM(agg.daily_orders), 0)::bigint AS order_count
    FROM generate_series(
        (now() - make_interval(days => p_days))::date,
        now()::date,
        '1 day'::interval
    ) AS d(day)
    LEFT JOIN (
        SELECT
            o.created_at::date AS order_day,
            SUM(oi.subtotal) AS daily_revenue,
            COUNT(DISTINCT o.id) AS daily_orders
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE oi.farmer_id = p_farmer_id
          AND o.status = 'delivered'
          AND o.created_at >= (now() - make_interval(days => p_days))
        GROUP BY o.created_at::date
    ) agg ON agg.order_day = d.day
    GROUP BY d.day
    ORDER BY d.day;
END;
$$;

-- 3. Top-selling products
CREATE OR REPLACE FUNCTION farmer_top_products(
    p_farmer_id uuid,
    p_days integer DEFAULT 30,
    p_limit integer DEFAULT 10
)
RETURNS TABLE(
    listing_id uuid,
    name_en text,
    name_ne text,
    category_name_en text,
    total_qty_kg numeric,
    total_revenue numeric,
    order_count bigint
) LANGUAGE plpgsql STABLE SECURITY INVOKER AS $$
BEGIN
    IF p_days < 1 OR p_days > 365 THEN
        RAISE EXCEPTION 'p_days must be between 1 and 365';
    END IF;

    RETURN QUERY
    SELECT
        pl.id AS listing_id,
        pl.name_en,
        pl.name_ne,
        pc.name_en AS category_name_en,
        COALESCE(SUM(oi.quantity_kg), 0) AS total_qty_kg,
        COALESCE(SUM(oi.subtotal), 0) AS total_revenue,
        COUNT(DISTINCT o.id) AS order_count
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    JOIN produce_listings pl ON pl.id = oi.listing_id
    JOIN produce_categories pc ON pc.id = pl.category_id
    WHERE oi.farmer_id = p_farmer_id
      AND o.status = 'delivered'
      AND o.created_at >= (now() - make_interval(days => p_days))
    GROUP BY pl.id, pl.name_en, pl.name_ne, pc.name_en
    ORDER BY total_revenue DESC
    LIMIT p_limit;
END;
$$;

-- 4. Price benchmarks: farmer's avg price vs market avg per category
-- market_avg_price EXCLUDES the farmer's own listings for fair comparison.
CREATE OR REPLACE FUNCTION farmer_price_benchmarks(
    p_farmer_id uuid
)
RETURNS TABLE(
    category_id uuid,
    category_name_en text,
    category_name_ne text,
    my_avg_price numeric,
    market_avg_price numeric,
    my_listing_count bigint,
    market_listing_count bigint
) LANGUAGE plpgsql STABLE SECURITY INVOKER AS $$
BEGIN
    RETURN QUERY
    SELECT
        pc.id AS category_id,
        pc.name_en AS category_name_en,
        pc.name_ne AS category_name_ne,
        COALESCE(
            AVG(pl.price_per_kg) FILTER (WHERE pl.farmer_id = p_farmer_id),
            0
        ) AS my_avg_price,
        COALESCE(
            AVG(pl.price_per_kg) FILTER (WHERE pl.farmer_id != p_farmer_id),
            0
        ) AS market_avg_price,
        COUNT(*) FILTER (WHERE pl.farmer_id = p_farmer_id) AS my_listing_count,
        COUNT(*) FILTER (WHERE pl.farmer_id != p_farmer_id) AS market_listing_count
    FROM produce_listings pl
    JOIN produce_categories pc ON pc.id = pl.category_id
    WHERE pl.is_active = true
    GROUP BY pc.id, pc.name_en, pc.name_ne
    HAVING COUNT(*) FILTER (WHERE pl.farmer_id = p_farmer_id) > 0
    ORDER BY pc.name_en;
END;
$$;

-- 5. Fulfillment rate (terminal orders only: delivered + cancelled)
CREATE OR REPLACE FUNCTION farmer_fulfillment_rate(
    p_farmer_id uuid,
    p_days integer DEFAULT 30
)
RETURNS TABLE(
    total_orders bigint,
    delivered bigint,
    cancelled bigint,
    fulfillment_pct numeric
) LANGUAGE plpgsql STABLE SECURITY INVOKER AS $$
BEGIN
    IF p_days < 1 OR p_days > 365 THEN
        RAISE EXCEPTION 'p_days must be between 1 and 365';
    END IF;

    RETURN QUERY
    SELECT
        COUNT(DISTINCT o.id) AS total_orders,
        COUNT(DISTINCT o.id) FILTER (WHERE o.status = 'delivered') AS delivered,
        COUNT(DISTINCT o.id) FILTER (WHERE o.status = 'cancelled') AS cancelled,
        CASE
            WHEN COUNT(DISTINCT o.id) = 0 THEN 0
            ELSE ROUND(
                100.0 * COUNT(DISTINCT o.id) FILTER (WHERE o.status = 'delivered')
                / COUNT(DISTINCT o.id),
                1
            )
        END AS fulfillment_pct
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    WHERE oi.farmer_id = p_farmer_id
      AND o.created_at >= (now() - make_interval(days => p_days))
      AND o.status IN ('delivered', 'cancelled');
END;
$$;

-- 6. Rating distribution
CREATE OR REPLACE FUNCTION farmer_rating_distribution(
    p_farmer_id uuid
)
RETURNS TABLE(
    score integer,
    count bigint
) LANGUAGE plpgsql STABLE SECURITY INVOKER AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.score,
        COALESCE(COUNT(r.id), 0) AS count
    FROM generate_series(1, 5) AS s(score)
    LEFT JOIN ratings r
        ON r.score = s.score
        AND r.rated_id = p_farmer_id
        AND r.role_rated = 'farmer'
    GROUP BY s.score
    ORDER BY s.score;
END;
$$;

-- Grant execute to authenticated users (required for Supabase PostgREST)
GRANT EXECUTE ON FUNCTION farmer_sales_by_category(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION farmer_revenue_trend(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION farmer_top_products(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION farmer_price_benchmarks(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION farmer_fulfillment_rate(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION farmer_rating_distribution(uuid) TO authenticated;
