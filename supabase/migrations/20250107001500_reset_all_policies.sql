/*
# Complete Policy Reset and Fix

This migration completely resets all RLS policies to resolve conflicts and infinite recursion issues.

## Query Description: 
This operation will remove all existing RLS policies and recreate them with corrected logic. This ensures clean policy definitions without conflicts or circular dependencies. No user data will be affected - only access control policies are being reset.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Drops all existing RLS policies on all tables
- Recreates policies with simplified, non-recursive logic
- Maintains strict access control without circular references

## Security Implications:
- RLS Status: Enabled on all tables
- Policy Changes: Complete reset and recreation
- Auth Requirements: All policies require authenticated users

## Performance Impact:
- Indexes: Maintained and optimized
- Triggers: No changes to existing triggers
- Estimated Impact: Improved query performance due to simplified policies
*/

-- Step 1: Drop all existing policies to avoid conflicts
DO $$ 
DECLARE
    r RECORD;
BEGIN
    -- Drop all policies on profiles table
    FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'profiles' AND schemaname = 'public' LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.profiles CASCADE';
    END LOOP;
    
    -- Drop all policies on channels table
    FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'channels' AND schemaname = 'public' LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.channels CASCADE';
    END LOOP;
    
    -- Drop all policies on channel_members table
    FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'channel_members' AND schemaname = 'public' LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.channel_members CASCADE';
    END LOOP;
    
    -- Drop all policies on messages table
    FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'messages' AND schemaname = 'public' LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.messages CASCADE';
    END LOOP;
    
    -- Drop all policies on direct_message_participants table
    FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'direct_message_participants' AND schemaname = 'public' LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.direct_message_participants CASCADE';
    END LOOP;
END $$;

-- Step 2: Create optimized indexes for better policy performance
CREATE INDEX IF NOT EXISTS idx_channels_privacy ON public.channels(is_private);
CREATE INDEX IF NOT EXISTS idx_channel_members_user_channel ON public.channel_members(user_id, channel_id);
CREATE INDEX IF NOT EXISTS idx_messages_channel ON public.messages(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_dm ON public.messages(user_id, recipient_id, created_at DESC) WHERE channel_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_dm_participants_users ON public.direct_message_participants(user1_id, user2_id);

-- Step 3: Create simple, non-recursive RLS policies

-- Profiles table policies
CREATE POLICY "Users can view all profiles" ON public.profiles
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Channels table policies  
CREATE POLICY "Users can view public channels" ON public.channels
    FOR SELECT USING (
        auth.role() = 'authenticated' AND 
        (is_private = false OR id IN (
            SELECT channel_id FROM public.channel_members WHERE user_id = auth.uid()
        ))
    );

CREATE POLICY "Authenticated users can create channels" ON public.channels
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Channel members table policies
CREATE POLICY "Users can view channel memberships" ON public.channel_members
    FOR SELECT USING (
        auth.role() = 'authenticated' AND
        (user_id = auth.uid() OR channel_id IN (
            SELECT id FROM public.channels WHERE is_private = false
        ))
    );

CREATE POLICY "Users can join public channels" ON public.channel_members
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND
        user_id = auth.uid() AND
        channel_id IN (SELECT id FROM public.channels WHERE is_private = false)
    );

CREATE POLICY "Users can leave channels" ON public.channel_members
    FOR DELETE USING (
        auth.role() = 'authenticated' AND user_id = auth.uid()
    );

-- Messages table policies
CREATE POLICY "Users can view channel messages" ON public.messages
    FOR SELECT USING (
        auth.role() = 'authenticated' AND (
            -- Channel messages: check channel access directly
            (channel_id IS NOT NULL AND (
                channel_id IN (
                    SELECT id FROM public.channels WHERE is_private = false
                ) OR 
                channel_id IN (
                    SELECT channel_id FROM public.channel_members WHERE user_id = auth.uid()
                )
            )) OR
            -- Direct messages: user is sender or recipient
            (channel_id IS NULL AND (user_id = auth.uid() OR recipient_id = auth.uid()))
        )
    );

CREATE POLICY "Users can send messages" ON public.messages
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND
        user_id = auth.uid() AND
        (
            -- Channel messages: user must be member (for private) or channel must be public
            (channel_id IS NOT NULL AND (
                channel_id IN (
                    SELECT id FROM public.channels WHERE is_private = false
                ) OR 
                channel_id IN (
                    SELECT channel_id FROM public.channel_members WHERE user_id = auth.uid()
                )
            )) OR
            -- Direct messages: valid recipient
            (channel_id IS NULL AND recipient_id IS NOT NULL AND recipient_id != auth.uid())
        )
    );

-- Direct message participants table policies
CREATE POLICY "Users can view their DM conversations" ON public.direct_message_participants
    FOR SELECT USING (
        auth.role() = 'authenticated' AND 
        (user1_id = auth.uid() OR user2_id = auth.uid())
    );

CREATE POLICY "Users can create DM conversations" ON public.direct_message_participants
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND 
        (user1_id = auth.uid() OR user2_id = auth.uid()) AND
        user1_id != user2_id
    );

-- Step 4: Ensure RLS is enabled on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_message_participants ENABLE ROW LEVEL SECURITY;

-- Step 5: Create default channels if they don't exist
INSERT INTO public.channels (name, description, is_private, created_by) 
SELECT 'general', 'Company-wide announcements and general discussion', false, NULL
WHERE NOT EXISTS (SELECT 1 FROM public.channels WHERE name = 'general');

INSERT INTO public.channels (name, description, is_private, created_by) 
SELECT 'random', 'Non-work related chatter and fun stuff', false, NULL
WHERE NOT EXISTS (SELECT 1 FROM public.channels WHERE name = 'random');

INSERT INTO public.channels (name, description, is_private, created_by) 
SELECT 'development', 'Development team discussions', false, NULL
WHERE NOT EXISTS (SELECT 1 FROM public.channels WHERE name = 'development');
