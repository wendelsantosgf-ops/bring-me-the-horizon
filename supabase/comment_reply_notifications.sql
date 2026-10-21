-- BMTH: notificação ao autor quando outro membro responde a seu comentário.
-- Execute no Supabase SQL Editor após notifications.sql e comment_replies.sql.
-- Não permite que o cliente crie notificações arbitrárias: a origem é um trigger.
CREATE OR REPLACE FUNCTION public.bmth_notify_comment_reply()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  parent_author uuid;
  actor_name text;
  preview text;
BEGIN
  IF NEW.parent_id IS NULL THEN RETURN NEW; END IF;
  IF TG_TABLE_NAME NOT IN ('community_comments','character_comments','wiki_comments') THEN RETURN NEW; END IF;
  EXECUTE format('SELECT user_id FROM public.%I WHERE id = $1', TG_TABLE_NAME)
    INTO parent_author USING NEW.parent_id;
  IF parent_author IS NULL OR parent_author = NEW.user_id THEN RETURN NEW; END IF;
  SELECT coalesce(nullif(trim(display_name),''),'Um membro')
    INTO actor_name FROM public.profile WHERE user_id = NEW.user_id LIMIT 1;
  preview := left(regexp_replace(trim(NEW.content),'[[:space:]]+',' ','g'),100);
  INSERT INTO public.bmth_notifications(recipient_id,actor_id,kind,title,href)
  VALUES (
    parent_author,NEW.user_id,'comment_reply',
    left(coalesce(actor_name,'Um membro') || ' respondeu ao seu comentário: ' || preview,220),
    './comunidade.html#posts'
  );
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.bmth_notify_comment_reply() FROM PUBLIC, anon, authenticated;
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['community_comments','character_comments','wiki_comments'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS bmth_comment_reply_notify ON public.%I',t);
    EXECUTE format('CREATE TRIGGER bmth_comment_reply_notify AFTER INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public.bmth_notify_comment_reply()',t);
  END LOOP;
END $$;
