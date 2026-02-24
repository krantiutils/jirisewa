-- ==========================================================
-- Fix farmer analytics RPC functions:
-- 1. Use SECURITY DEFINER to bypass RLS (avoids infinite recursion
--    between orders and order_items RLS policies)
-- 2. Fix farmer_revenue_trend: cast generate_series output to date
--    so it matches the declared RETURNS TABLE(day date, ...)
-- ==========================================================

-- 1. farmer_sales_by_category: change SECURITY INVOKER → DEFINER
ALTER FUNCTION farmer_sales_by_category(uuid, integer) SECURITY DEFINER;

-- 2. farmer_revenue_trend: recreate with SECURITY DEFINER + date cast fix
CREATE OR REPLACE FUNCTION farmer_revenue_trend(
    p_farmer_id uuid,
    p_days integer DEFAULT 30
)
RETURNS TABLE(
    day date,
    revenue numeric,
    order_count bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
BEGIN
    IF p_days < 1 OR p_days > 365 THEN
        RAISE EXCEPTION 'p_days must be between 1 and 365';
    END IF;

    RETURN QUERY
    SELECT
        d.day::date,
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
    ) agg ON agg.order_day = d.day::date
    GROUP BY d.day
    ORDER BY d.day;
END;
$$;

-- 3. farmer_top_products: change SECURITY INVOKER → DEFINER
ALTER FUNCTION farmer_top_products(uuid, integer, integer) SECURITY DEFINER;

-- 4. farmer_price_benchmarks: change SECURITY INVOKER → DEFINER
ALTER FUNCTION farmer_price_benchmarks(uuid) SECURITY DEFINER;

-- 5. farmer_fulfillment_rate: change SECURITY INVOKER → DEFINER
ALTER FUNCTION farmer_fulfillment_rate(uuid, integer) SECURITY DEFINER;

-- 6. farmer_rating_distribution: change SECURITY INVOKER → DEFINER
ALTER FUNCTION farmer_rating_distribution(uuid) SECURITY DEFINER;
