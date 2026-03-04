-- Migration: Add room and photo_type columns to deliverables for staging before/after photos

ALTER TABLE public.deliverables
  ADD COLUMN IF NOT EXISTS room text,
  ADD COLUMN IF NOT EXISTS photo_type text CHECK (photo_type IS NULL OR photo_type IN ('before', 'after'));

CREATE INDEX idx_deliverables_staging ON public.deliverables(task_id, room, photo_type)
  WHERE photo_type IS NOT NULL;
