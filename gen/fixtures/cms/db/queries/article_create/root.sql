-- ★ root の 1 文(0.11.5 から root を持つ Service に要る)。
-- root: arg:slug clauses
SELECT a.* FROM app.article a WHERE a.slug=$1 AND EXISTS(SELECT 1 FROM jsonb_array_elements($2::jsonb) c
 WHERE (c->'phases'='null'::jsonb OR c->'phases' ? a.phase));
