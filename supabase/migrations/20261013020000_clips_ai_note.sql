-- Why there is no AI view on a clip. The first live clip came back with no
-- `ai` vote and nothing to say why; the function swallowed every failure. A
-- short note on the row ("gemini 400", "capped", "unclear") is enough to tell
-- a quota problem from a model problem without reading function logs.
alter table public.clips add column if not exists ai_note text;
