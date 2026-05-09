-- ============================================================
-- Procedures for managing rootcause.risk_level
-- ============================================================

-- Upsert: p_row_id NULL -> insert (returns new id), else update
CREATE OR REPLACE PROCEDURE rootcause.save_risk_level(
    INOUT p_row_id     integer,
    IN    p_risk_level varchar,
    IN    p_is_active  boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_risk_level IS NULL OR length(trim(p_risk_level)) = 0 THEN
        RAISE EXCEPTION 'risk_level cannot be empty';
    END IF;

    IF p_row_id IS NULL THEN
        -- Prevent duplicate active labels (case-insensitive, trimmed)
        IF EXISTS (
            SELECT 1 FROM rootcause.risk_level
             WHERE lower(trim(risk_level)) = lower(trim(p_risk_level))
        ) THEN
            RAISE EXCEPTION 'risk_level "%" already exists', p_risk_level;
        END IF;

        INSERT INTO rootcause.risk_level (risk_level, is_active)
        VALUES (trim(p_risk_level), COALESCE(p_is_active, true))
        RETURNING row_id INTO p_row_id;
    ELSE
        UPDATE rootcause.risk_level
           SET risk_level = trim(p_risk_level),
               is_active  = COALESCE(p_is_active, is_active)
         WHERE row_id = p_row_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'risk_level row_id % not found', p_row_id;
        END IF;
    END IF;
END;
$$;


CREATE OR REPLACE PROCEDURE rootcause.delete_risk_level(
    IN p_row_id integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM rootcause.risk_level WHERE row_id = p_row_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'risk_level row_id % not found', p_row_id;
    END IF;
END;
$$;
