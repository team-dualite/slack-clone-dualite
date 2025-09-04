/*
# [Definitive RLS Policy Reset and Recursion Fix]
This migration completely resets all RLS policies for the application tables to resolve conflicts and infinite recursion errors. It first drops all existing policies on the relevant tables, then recreates them using a safe, non-recursive pattern with a SECURITY DEFINER function.

## Query Description: [This operation will reset your database's Row Level Security. It is designed to be safe and non-destructive to your data, but it fundamentally changes access control rules. It will drop all previous policies on profiles, channels, messages, and related tables, then apply a new, corrected set of policies.]

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false

## Structure Details:
- Drops all policies on: `profiles`, `channels`, `channel_members`, `messages`, `direct_message_participants`.
- Drops and recreates the function: `is_channel_member`.
- Recreates all SELECT, INSERT, UPDATE, DELETE policies for the tables listed above.

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: This script defines the core authentication and authorization logic for data access.

## Performance Impact:
- Indexes: No new indexes are added, but the new policies are designed to be more performant by avoiding recursion.
- Triggers: No changes.
- Estimated Impact: Positive. Resolves database errors and improves query performance by fixing recursion.
*/

-- Step 1: Drop all existing policies on relevant tables to ensure a clean slate.
-- This is a robust way to handle "policy already exists" errors.
DO $$
DECLARE
    policy_name TEXT;
BEGIN
    -- Drop policies for 'profiles'
    FOR policy_name IN (SELECT policyname FROM pg_policies WHERE tablename = 'profiles' AND schemaname = 'public')
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_name || '" ON public.profiles;';
    END LOOP;

    -- Drop policies for 'channels'
    FOR policy_name IN (SELECT policyname FROM pg_policies WHERE tablename = 'channels' AND schemaname = 'public')
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_name || '" ON public.channels;';
    END LOOP;

    -- Drop policies for 'channel_members'
    FOR policy_name IN (SELECT policyname FROM pg_policies WHERE tablename = 'channel_members' AND schemaname = 'public')
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_name || '" ON public.channel_members;';
    END LOOP;

    -- Drop policies for 'messages'
    FOR policy_name IN (SELECT policyname FROM pg_policies WHERE tablename = 'messages' AND schemaname = 'public')
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_name || '" ON public.messages;';
    END LOOP;

    -- Drop policies for 'direct_message_participants'
    FOR policy_name IN (SELECT policyname FROM pg_policies WHERE tablename = 'direct_message_participants' AND schemaname = 'public')
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_name || '" ON public.direct_message_participants;';
    END LOOP;
END
$$;

-- Step 2: Drop and recreate the helper function to break recursion.
DROP FUNCTION IF EXISTS public.is_channel_member(uuid, uuid);

CREATE OR REPLACE FUNCTION public.is_channel_member(channel_id_to_check uuid, user_id_to_check uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
-- Set a secure search path to prevent hijacking.
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.channel_members
        WHERE channel_id = channel_id_to_check AND user_id = user_id_to_check
    );
$$;

-- Step 3: Re-enable RLS and create the new, corrected policies.

-- Table: profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view all profiles" ON public.profiles FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Table: channels
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view public channels and private channels they are members of" ON public.channels FOR SELECT USING (
    is_private = false OR public.is_channel_member(id, auth.uid())
);
CREATE POLICY "Authenticated users can create channels" ON public.channels FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Channel creators can update their channels" ON public.channels FOR UPDATE USING (auth.uid() = created_by) WITH CHECK (auth.uid() = created_by);

-- Table: channel_members
ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view members of channels they belong to" ON public.channel_members FOR SELECT USING (
    public.is_channel_member(channel_id, auth.uid())
);
CREATE POLICY "Users can join and leave channels" ON public.channel_members FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Table: messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view messages in their channels and DMs" ON public.messages FOR SELECT USING (
    (channel_id IS NOT NULL AND public.is_channel_member(channel_id, auth.uid())) OR
    (recipient_id IS NOT NULL AND (auth.uid() = user_id OR auth.uid() = recipient_id))
);
CREATE POLICY "Users can send messages in their channels and DMs" ON public.messages FOR INSERT WITH CHECK (
    (channel_id IS NOT NULL AND public.is_channel_member(channel_id, auth.uid())) OR
    (recipient_id IS NOT NULL AND (auth.uid() = user_id OR auth.uid() = recipient_id))
);
CREATE POLICY "Users can edit/delete their own messages" ON public.messages FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own messages" ON public.messages FOR DELETE USING (auth.uid() = user_id);


-- Table: direct_message_participants
ALTER TABLE public.direct_message_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view and manage their own DM conversations" ON public.direct_message_participants FOR ALL USING (
    auth.uid() = user1_id OR auth.uid() = user2_id
) WITH CHECK (
    auth.uid() = user1_id OR auth.uid() = user2_id
);
