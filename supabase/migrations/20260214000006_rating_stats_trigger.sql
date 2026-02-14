-- ==========================================================
-- Trigger to auto-update users.rating_avg and users.rating_count
-- when a new rating is inserted.
-- Ratings are immutable (no UPDATE/DELETE), so only AFTER INSERT is needed.
-- ==========================================================

CREATE OR REPLACE FUNCTION update_user_rating_stats()
RETURNS trigger AS $$
BEGIN
    UPDATE users
    SET rating_avg = sub.avg_score,
        rating_count = sub.total_count
    FROM (
        SELECT
            COALESCE(AVG(score)::numeric(3,2), 0) AS avg_score,
            COUNT(*)::integer AS total_count
        FROM ratings
        WHERE rated_id = NEW.rated_id
    ) sub
    WHERE id = NEW.rated_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ratings_update_user_stats
    AFTER INSERT ON ratings
    FOR EACH ROW EXECUTE FUNCTION update_user_rating_stats();
