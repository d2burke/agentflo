-- Conversation list RPC for the Messages tab.
-- Returns one row per conversation the authenticated user participates in,
-- with the other user's profile info, last message preview, and unread count.

CREATE OR REPLACE FUNCTION get_conversation_list(p_user_id uuid)
RETURNS TABLE (
  conversation_id uuid,
  other_user_id uuid,
  other_user_name text,
  other_user_avatar text,
  last_message_body text,
  last_message_at timestamptz,
  last_message_sender_id uuid,
  unread_count bigint
) LANGUAGE sql STABLE AS $$
  SELECT
    c.id AS conversation_id,
    CASE WHEN c.participant_1_id = p_user_id THEN c.participant_2_id ELSE c.participant_1_id END AS other_user_id,
    u.full_name AS other_user_name,
    u.avatar_url AS other_user_avatar,
    m_last.body AS last_message_body,
    m_last.created_at AS last_message_at,
    m_last.sender_id AS last_message_sender_id,
    COALESCE(unread.cnt, 0) AS unread_count
  FROM conversations c
  -- Resolve the other user's profile
  JOIN users u ON u.id = CASE
    WHEN c.participant_1_id = p_user_id THEN c.participant_2_id
    ELSE c.participant_1_id
  END
  -- Latest message in the conversation
  LEFT JOIN LATERAL (
    SELECT body, created_at, sender_id
    FROM messages
    WHERE conversation_id = c.id
    ORDER BY created_at DESC
    LIMIT 1
  ) m_last ON true
  -- Unread count (messages from other user where read_at is null)
  LEFT JOIN LATERAL (
    SELECT count(*) AS cnt
    FROM messages
    WHERE conversation_id = c.id
      AND sender_id != p_user_id
      AND read_at IS NULL
  ) unread ON true
  WHERE c.participant_1_id = p_user_id OR c.participant_2_id = p_user_id
  ORDER BY COALESCE(m_last.created_at, c.created_at) DESC;
$$;
