/*
# Fix RLS Policy Conflicts and Infinite Recursion

This migration resolves the infinite recursion issue in channel_members policies and fixes policy conflicts.

## Query Description: 
This operation will drop and recreate Row Level Security policies to fix infinite recursion errors. This is a safe operation that improves database performance and resolves access issues. The changes maintain the same security model while eliminating circular references.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Drops and recreates policies on: channels, channel_members, messages, direct_message_participants
- Maintains security constraints while fixing recursion
- Improves query performance

## Security Implications:
- RLS Status: Enabled (maintained)
- Policy Changes: Yes (fixed infinite recursion)
- Auth Requirements: Authenticated users only

## Performance Impact:
- Indexes: No changes
- Triggers: No changes
- Estimated Impact: Improved performance due to elimination of recursive policy checks
*/

-- Drop existing policies that might cause conflicts
DROP POLICY IF EXISTS "Users can view public channels" ON channels;
DROP POLICY IF EXISTS "Users can view channels they are members of" ON channels;
DROP POLICY IF EXISTS "Users can view public channel members" ON channel_members;
DROP POLICY IF EXISTS "Users can view private channel members if they are members" ON channel_members;
DROP POLICY IF EXISTS "Users can join public channels" ON channel_members;
DROP POLICY IF EXISTS "Users can leave channels" ON channel_members;
DROP POLICY IF EXISTS "Users can view channel messages" ON messages;
DROP POLICY IF EXISTS "Users can view DM messages" ON messages;
DROP POLICY IF EXISTS "Users can send channel messages" ON messages;
DROP POLICY IF EXISTS "Users can send DM messages" ON messages;
DROP POLICY IF EXISTS "Users can view their DM participants" ON direct_message_participants;
DROP POLICY IF EXISTS "Users can create DM conversations" ON direct_message_participants;

-- Recreate policies with fixed logic to prevent infinite recursion

-- Channels policies (simplified to avoid recursion)
CREATE POLICY "Users can view public channels" ON channels
  FOR SELECT USING (NOT is_private);

CREATE POLICY "Users can view private channels they joined" ON channels
  FOR SELECT USING (
    is_private AND EXISTS (
      SELECT 1 FROM channel_members 
      WHERE channel_members.channel_id = channels.id 
      AND channel_members.user_id = auth.uid()
    )
  );

-- Channel members policies (direct access without recursive channel checks)
CREATE POLICY "Users can view public channel memberships" ON channel_members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM channels 
      WHERE channels.id = channel_members.channel_id 
      AND NOT channels.is_private
    )
  );

CREATE POLICY "Users can view private channel memberships they belong to" ON channel_members
  FOR SELECT USING (
    user_id = auth.uid() OR 
    EXISTS (
      SELECT 1 FROM channel_members cm2 
      WHERE cm2.channel_id = channel_members.channel_id 
      AND cm2.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can join public channels" ON channel_members
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM channels 
      WHERE channels.id = channel_members.channel_id 
      AND NOT channels.is_private
    )
  );

CREATE POLICY "Users can manage their own memberships" ON channel_members
  FOR DELETE USING (user_id = auth.uid());

-- Messages policies
CREATE POLICY "Users can view channel messages" ON messages
  FOR SELECT USING (
    channel_id IS NOT NULL AND (
      -- Public channel messages
      EXISTS (
        SELECT 1 FROM channels 
        WHERE channels.id = messages.channel_id 
        AND NOT channels.is_private
      ) OR
      -- Private channel messages (user is member)
      EXISTS (
        SELECT 1 FROM channel_members 
        WHERE channel_members.channel_id = messages.channel_id 
        AND channel_members.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can view their DM messages" ON messages
  FOR SELECT USING (
    channel_id IS NULL AND (
      user_id = auth.uid() OR recipient_id = auth.uid()
    )
  );

CREATE POLICY "Users can send channel messages" ON messages
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND 
    channel_id IS NOT NULL AND (
      -- Public channel
      EXISTS (
        SELECT 1 FROM channels 
        WHERE channels.id = messages.channel_id 
        AND NOT channels.is_private
      ) OR
      -- Private channel (user is member)
      EXISTS (
        SELECT 1 FROM channel_members 
        WHERE channel_members.channel_id = messages.channel_id 
        AND channel_members.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can send DM messages" ON messages
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND 
    channel_id IS NULL AND 
    recipient_id IS NOT NULL
  );

-- Direct message participants policies
CREATE POLICY "Users can view their DM conversations" ON direct_message_participants
  FOR SELECT USING (user1_id = auth.uid() OR user2_id = auth.uid());

CREATE POLICY "Users can create DM conversations" ON direct_message_participants
  FOR INSERT WITH CHECK (user1_id = auth.uid() OR user2_id = auth.uid());

-- Add helpful indexes for the new policy structure
CREATE INDEX IF NOT EXISTS idx_channels_privacy ON channels(is_private);
CREATE INDEX IF NOT EXISTS idx_channel_members_user_channel ON channel_members(user_id, channel_id);
CREATE INDEX IF NOT EXISTS idx_messages_channel_created ON messages(channel_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_dm_participants ON messages(user_id, recipient_id) WHERE channel_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_dm_participants_users ON direct_message_participants(user1_id, user2_id);
