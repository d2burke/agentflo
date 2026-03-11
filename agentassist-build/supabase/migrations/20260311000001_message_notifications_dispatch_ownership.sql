create or replace function public.enqueue_message_notification_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation public.conversations;
  v_recipient_id uuid;
  v_notifications_enabled boolean;
begin
  if new.conversation_id is null
     or new.sender_id is null
     or new.deleted_at is not null
     or new.message_type = 'system' then
    return new;
  end if;

  select *
  into v_conversation
  from public.conversations
  where id = new.conversation_id;

  if not found then
    return new;
  end if;

  if v_conversation.participant_1_id = new.sender_id then
    v_recipient_id := v_conversation.participant_2_id;
  elsif v_conversation.participant_2_id = new.sender_id then
    v_recipient_id := v_conversation.participant_1_id;
  else
    return new;
  end if;

  if v_recipient_id is null or v_recipient_id = new.sender_id then
    return new;
  end if;

  select np.messages
  into v_notifications_enabled
  from public.notification_preferences np
  where np.user_id = v_recipient_id;

  insert into public.message_notification_jobs (
    message_id,
    conversation_id,
    sender_id,
    recipient_id,
    status,
    notification_id,
    last_error
  )
  values (
    new.id,
    new.conversation_id,
    new.sender_id,
    v_recipient_id,
    case when v_notifications_enabled is distinct from false then 'pending' else 'skipped' end,
    null,
    case when v_notifications_enabled is distinct from false then null else 'disabled_by_preference' end
  )
  on conflict (message_id) do update
  set
    notification_id = public.message_notification_jobs.notification_id,
    status = excluded.status,
    last_error = excluded.last_error;

  return new;
end;
$$;
