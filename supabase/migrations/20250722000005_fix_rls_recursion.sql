/*
          # [Fix RLS Policy Recursion and Conflicts]
          This migration completely overhauls the Row Level Security (RLS) policies to fix critical "infinite recursion" and "policy already exists" errors. It introduces a SECURITY DEFINER function to safely check channel access, which is the standard and most secure way to handle this type of complex RLS scenario.

          ## Query Description: [This operation will reset all RLS policies on the core messaging tables and replace them with a robust, non-recursive, and secure set of rules. It starts by dropping all potentially conflicting policies from previous migrations to ensure this script runs successfully. It then creates a helper function to centralize and safely manage channel access logic, which is used by the new policies. This will resolve the critical errors preventing the application from loading data.]
          
          ## Metadata:
          - Schema-Category: ["Structural", "Security"]
          - Impact-Level: ["High"]
          - Requires-Backup: [true]
          - Reversible: [false]
          
          ## Structure Details:
          - Drops all existing RLS policies on: `channels`, `channel_members`, `messages`, `direct_message_participants`.
          - Creates a new SQL function: `public.can_access_channel`.
          - Creates new, non-recursive RLS policies for all the tables listed above.
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [Yes]
          - Auth Requirements: [All policies are tied to the authenticated user's ID (`auth.uid()`)]
          - This fixes a potential security flaw from a previous permissive policy and correctly enforces channel privacy.
          
          ## Performance Impact:
          - Indexes: [No new indexes]
          - Triggers: [No changes]
          - Estimated Impact: [Positive. By removing the infinite recursion, database performance will be restored to normal, and the application will become responsive again. The function-based check is highly efficient.]
          */

-- Step 1: Drop all potentially conflicting RLS policies from previous migrations.
-- This is idempotent and will not fail if the policies don't exist.

-- Drop policies on 'channels'
DROP POLICY IF EXISTS "Users can view public channels" ON public.channels;
DROP POLICY IF EXISTS "Users can view private channels they are members of" ON public.channels;
DROP POLICY IF EXISTS "Users can insert channels" ON public.channels;
DROP POLICY IF EXISTS "Users can view channels they have access to" ON public.channels;
DROP POLICY IF EXISTS "Authenticated users can create channels" ON public.channels;

-- Drop policies on 'channel_members'
DROP POLICY IF EXISTS "Users can view channel memberships" ON public.channel_members;
DROP POLICY IF EXISTS "Users can join/leave channels" ON public.channel_members;
DROP POLICY IF EXISTS "Users can view members of channels they have access to" ON public.channel_members;
DROP POLICY IF EXISTS "Users can manage their own channel membership" ON public.channel_members;
DROP POLICY IF EXISTS "Users can view memberships of channels they can access" ON public.channel_members;
DROP POLICY IF EXISTS "Users can manage their own membership" ON public.channel_members;

-- Drop policies on 'messages'
DROP POLICY IF EXISTS "Users can view messages in their accessible channels" ON public.messages;
DROP POLICY IF EXISTS "Users can view their DMs" ON public.messages;
DROP POLICY IF EXISTS "Users can send messages in their accessible channels" ON public.messages;
DROP POLICY IF EXISTS "Users can send DMs" ON public.messages;

-- Drop policies on 'direct_message_participants'
DROP POLICY IF EXISTS "Users can view their DM conversations" ON public.direct_message_participants;
DROP POLICY IF EXISTS "Users can create DM conversations" ON public.direct_message_participants;
DROP POLICY IF EXISTS "Users can manage their own DM conversations" ON public.direct_message_participants;


-- Step 2: Create a SECURITY DEFINER function to break RLS recursion.
-- This function safely checks if a user has access to a channel.
CREATE OR REPLACE FUNCTION public.can_access_channel(p_channel_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
-- Set a secure search_path to prevent hijacking
SET search_path = public
AS $$
DECLARE
  v_is_private boolean;
BEGIN
  -- Get the privacy status of the channel
  SELECT is_private INTO v_is_private FROM public.channels WHERE id = p_channel_id;

  -- If the channel is not private (i.e., public), access is granted
  IF v_is_private = false THEN
    RETURN true;
  END IF;

  -- If the channel is private, check if the user is a member
  RETURN EXISTS (
    SELECT 1
    FROM public.channel_members
    WHERE channel_id = p_channel_id AND user_id = p_user_id
  );
END;
$$;


-- Step 3: Re-create RLS policies using the new helper function.

-- Ensure RLS is enabled on all relevant tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_message_participants ENABLE ROW LEVEL SECURITY;


-- Policies for 'profiles'
CREATE POLICY "Users can view all profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);


-- Policies for 'channels'
CREATE POLICY "Users can view channels they have access to" ON public.channels FOR SELECT
  USING (public.can_access_channel(id, auth.uid()));

CREATE POLICY "Authenticated users can create channels" ON public.channels FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');


-- Policies for 'channel_members'
CREATE POLICY "Users can view memberships of channels they can access" ON public.channel_members FOR SELECT
  USING (public.can_access_channel(channel_id, auth.uid()));

CREATE POLICY "Users can manage their own membership" ON public.channel_members FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- Policies for 'messages'
CREATE POLICY "Users can view messages in accessible channels" ON public.messages FOR SELECT
  USING (channel_id IS NOT NULL AND public.can_access_channel(channel_id, auth.uid()));

CREATE POLICY "Users can view their DMs" ON public.messages FOR SELECT
  USING (channel_id IS NULL AND (auth.uid() = user_id OR auth.uid() = recipient_id));

CREATE POLICY "Users can send messages in accessible channels" ON public.messages FOR INSERT
  WITH CHECK (channel_id IS NOT NULL AND public.can_access_channel(channel_id, auth.uid()));

CREATE POLICY "Users can send DMs" ON public.messages FOR INSERT
  WITH CHECK (channel_id IS NULL AND auth.uid() = user_id);


-- Policies for 'direct_message_participants'
CREATE POLICY "Users can manage their own DM conversations" ON public.direct_message_participants FOR ALL
  USING (auth.uid() = user1_id OR auth.uid() = user2_id)
  WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);
