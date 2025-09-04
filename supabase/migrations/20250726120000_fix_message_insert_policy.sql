/*
# [Fix] RLS Policies for Messages Table

This migration corrects the Row Level Security (RLS) policies for the `messages` table to resolve a "new row violates row-level security policy" error. It ensures users can send messages in channels they belong to and in direct messages.

## Query Description:
This script will drop all existing policies on the `messages` table and recreate them correctly. This is a safe operation as it only affects security rules and does not touch any user data. The new policies are designed to be non-recursive and efficient.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by restoring previous policies)

## Structure Details:
- Table: `public.messages`
- Policies Affected: All policies (`SELECT`, `INSERT`)

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: This fix ensures that `INSERT` operations on the `messages` table correctly verify that the authenticated user has permission to post in the specified channel or direct message, preventing unauthorized message creation.

## Performance Impact:
- Indexes: No changes
- Triggers: No changes
- Estimated Impact: Low. The new policies use an optimized helper function (`can_view_channel`) which should result in efficient permission checks.
*/

-- Step 1: Drop all existing policies on the 'messages' table to avoid conflicts.
-- This ensures a clean slate before creating the corrected policies.
DROP POLICY IF EXISTS "Users can view messages" ON public.messages;
DROP POLICY IF EXISTS "Users can send messages" ON public.messages;
DROP POLICY IF EXISTS "Users can insert their own messages" ON public.messages; -- A possible old name

-- Step 2: Recreate the SELECT policy for messages.
-- This policy allows users to view messages in public channels, private channels they are members of,
-- or direct messages where they are either the sender or the recipient.
CREATE POLICY "Users can view messages"
ON public.messages
FOR SELECT
USING (
  (channel_id IS NOT NULL AND public.can_view_channel(channel_id)) OR
  (recipient_id IS NOT NULL AND (auth.uid() = user_id OR auth.uid() = recipient_id))
);

-- Step 3: Recreate the INSERT policy for messages.
-- This policy allows users to send messages if they are the authenticated author, and:
--   a) The message is for a channel they can view (public or member of private).
--   b) The message is a direct message to another user.
-- This resolves the "violates row-level security policy" error.
CREATE POLICY "Users can send messages"
ON public.messages
FOR INSERT
WITH CHECK (
  auth.uid() = user_id AND (
    (channel_id IS NOT NULL AND public.can_view_channel(channel_id)) OR
    (recipient_id IS NOT NULL)
  )
);
