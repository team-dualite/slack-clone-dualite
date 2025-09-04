/*
          # [Final RLS Policy Fix]
          This migration provides a comprehensive fix for all RLS policy issues, including infinite recursion, policy conflicts, and incorrect insert permissions. It resets all relevant policies and rebuilds them using a safe helper function.

          ## Query Description: [This script will drop and recreate all RLS policies for the application's tables. It is designed to be idempotent and resolve all previous migration errors. It ensures that the database schema is in a correct and consistent state. No data will be lost.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Medium"
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - Drops all policies on: `profiles`, `channels`, `channel_members`, `messages`, `direct_message_participants`.
          - Drops and recreates the `can_view_channel` function.
          - Recreates all SELECT, INSERT, UPDATE, DELETE policies for the tables above.
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes
          - Auth Requirements: Policies are dependent on `auth.uid()` and `auth.role()`.
          
          ## Performance Impact:
          - Indexes: No changes to indexes.
          - Triggers: No changes to triggers.
          - Estimated Impact: This will resolve performance issues caused by RLS recursion.
          */

-- Step 1: Clean up all existing policies to ensure a fresh start.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('profiles', 'channels', 'channel_members', 'messages', 'direct_message_participants'))
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public."' || r.tablename || '";';
    END LOOP;
END $$;

-- Step 2: Drop the helper function if it exists to make the script re-runnable.
DROP FUNCTION IF EXISTS public.can_view_channel(uuid);

-- Step 3: Create the SECURITY DEFINER function to safely check channel access.
CREATE OR REPLACE FUNCTION public.can_view_channel(channel_id_to_check uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
-- Set a fixed search path to address the "Function Search Path Mutable" warning.
SET search_path = public
AS $$
    SELECT
        EXISTS (
            SELECT 1
            FROM public.channels c
            WHERE c.id = channel_id_to_check
            AND (
                -- Condition 1: The channel is public.
                c.is_private = false
                OR
                -- Condition 2: The user is a member of the private channel.
                (
                    c.is_private = true
                    AND EXISTS (
                        SELECT 1
                        FROM public.channel_members cm
                        WHERE cm.channel_id = c.id
                        AND cm.user_id = auth.uid()
                    )
                )
            )
        );
$$;

-- Step 4: Re-enable RLS on all tables (it might have been disabled by failed migrations).
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_message_participants ENABLE ROW LEVEL SECURITY;

-- Step 5: Re-create all policies from scratch.

-- == PROFILES POLICIES ==
CREATE POLICY "Users can view all profiles" ON public.profiles
    FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- == CHANNELS POLICIES ==
CREATE POLICY "Users can view accessible channels" ON public.channels
    FOR SELECT USING (public.can_view_channel(id));
CREATE POLICY "Authenticated users can create channels" ON public.channels
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- == CHANNEL_MEMBERS POLICIES ==
CREATE POLICY "Users can view members of accessible channels" ON public.channel_members
    FOR SELECT USING (public.can_view_channel(channel_id));
CREATE POLICY "Users can join or leave channels" ON public.channel_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove themselves from channels" ON public.channel_members
    FOR DELETE USING (auth.uid() = user_id);

-- == MESSAGES POLICIES (CRITICAL FIX) ==
CREATE POLICY "Users can view messages in accessible conversations" ON public.messages
    FOR SELECT USING (
        (channel_id IS NOT NULL AND public.can_view_channel(channel_id)) -- Channel messages
        OR
        (recipient_id IS NOT NULL AND (auth.uid() = user_id OR auth.uid() = recipient_id)) -- Direct messages
    );

CREATE POLICY "Users can send messages in accessible conversations" ON public.messages
    FOR INSERT WITH CHECK (
        (auth.uid() = user_id) -- User can only send as themselves
        AND
        (
            (channel_id IS NOT NULL AND public.can_view_channel(channel_id)) -- Channel messages
            OR
            (recipient_id IS NOT NULL) -- Direct messages (no check needed as long as sender is correct)
        )
    );

-- == DIRECT_MESSAGE_PARTICIPANTS POLICIES ==
CREATE POLICY "Users can view their own DM conversations" ON public.direct_message_participants
    FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);
CREATE POLICY "Users can create their own DM conversations" ON public.direct_message_participants
    FOR INSERT WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);
