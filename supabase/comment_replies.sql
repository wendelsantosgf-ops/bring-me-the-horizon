-- BMTH: respostas encadeadas em comentários de publicações, personagens e Wikis.
-- Execute uma vez no SQL Editor do Supabase.
-- Uma resposta aponta para um comentário principal do mesmo conteúdo.
DO $$
DECLARE t text; fk text;
BEGIN
 FOR t,fk IN SELECT * FROM (VALUES ('community_comments','post_id'),('character_comments','character_id'),('wiki_comments','wiki_id')) AS v(t,fk) LOOP
  EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS parent_id uuid',t);
  EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I(parent_id)',t||'_parent_idx',t);
  -- Impede que a resposta pertença a uma publicação/ficha/wiki diferente.
  EXECUTE format('CREATE OR REPLACE FUNCTION public.%I() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '''' AS $fn$ BEGIN IF NEW.parent_id IS NOT NULL THEN IF NEW.parent_id = NEW.id THEN RAISE EXCEPTION ''Um comentário não pode responder a si mesmo''; END IF; IF NOT EXISTS (SELECT 1 FROM public.%I p WHERE p.id=NEW.parent_id AND p.%I=NEW.%I AND p.parent_id IS NULL) THEN RAISE EXCEPTION ''A resposta deve pertencer a um comentário principal do mesmo conteúdo''; END IF; END IF; RETURN NEW; END $fn$',t||'_validate_reply',t,fk,fk);
  EXECUTE format('DROP TRIGGER IF EXISTS bmth_validate_reply ON public.%I',t);
  EXECUTE format('CREATE TRIGGER bmth_validate_reply BEFORE INSERT OR UPDATE OF parent_id,%I ON public.%I FOR EACH ROW EXECUTE FUNCTION public.%I()',fk,t,t||'_validate_reply');
 END LOOP;
END $$;
