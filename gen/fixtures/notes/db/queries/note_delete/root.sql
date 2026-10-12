-- ★ root の 1 文。主体も相も無いので、id で 1 行読むだけ。
-- root: arg:id
SELECT n.* FROM app.note n WHERE n.id=$1::uuid;
