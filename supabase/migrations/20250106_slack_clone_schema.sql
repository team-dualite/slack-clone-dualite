/*
# Slack Clone Database Schema
Complete database setup for a Slack clone with channels, direct messaging, and real-time functionality

## Query Description:
This migration creates the complete database structure for a Slack clone application including:
- User profiles linked to Supabase auth
- Channels with member management
- Messages for both channels and direct messaging
- Real-time subscriptions and RLS policies
- Automatic profile creation via database triggers

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- profiles: User profile data linked to auth.users
- channels: Channel information and settings
- channel_members: Many-to-many relationship for channel membership
- messages: All messages (channel and direct)
- direct_message_participants: Tracking DM conversations

## Security Implications:
- RLS Status: Enabled on all tables
- Policy Changes: Yes - comprehensive RLS policies for data privacy
- Auth Requirements: All operations require authentication

## Performance Impact:
- Indexes: Added for optimal query performance
- Triggers: Profile creation trigger on auth.users
- Estimated Impact: Minimal - optimized for real-time operations
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create profiles table
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT NOT NULL,
    avatar_url TEXT,
    status TEXT CHECK (status IN ('online', 'away', 'offline')) DEFAULT 'offline',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create channels table
CREATE TABLE channels (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    is_private BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create channel_members table
CREATE TABLE channel_members (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    channel_id UUID REFERENCES channels(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    role TEXT CHECK (role IN ('admin', 'member')) DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(channel_id, user_id)
);

-- Create messages table
CREATE TABLE messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    content TEXT NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    channel_id UUID REFERENCES channels(id) ON DELETE CASCADE NULL,
    recipient_id UUID REFERENCES profiles(id) ON DELETE CASCADE NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT check_message_target CHECK (
        (channel_id IS NOT NULL AND recipient_id IS NULL) OR
        (channel_id IS NULL AND recipient_id IS NOT NULL)
    )
);

-- Create direct_message_participants table for tracking DM conversations
CREATE TABLE direct_message_participants (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user1_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    user2_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user1_id, user2_id),
    CONSTRAINT check_different_users CHECK (user1_id != user2_id)
);

-- Create indexes for better performance
CREATE INDEX idx_messages_channel_id ON messages(channel_id);
CREATE INDEX idx_messages_recipient_id ON messages(recipient_id);
CREATE INDEX idx_messages_user_id ON messages(user_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_channel_members_channel_id ON channel_members(channel_id);
CREATE INDEX idx_channel_members_user_id ON channel_members(user_id);
CREATE INDEX idx_direct_message_participants_users ON direct_message_participants(user1_id, user2_id);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE direct_message_participants ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Users can view all profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- RLS Policies for channels
CREATE POLICY "Users can view public channels" ON channels FOR SELECT USING (NOT is_private);
CREATE POLICY "Users can view private channels they're members of" ON channels FOR SELECT USING (
    is_private AND EXISTS (
        SELECT 1 FROM channel_members 
        WHERE channel_id = channels.id AND user_id = auth.uid()
    )
);
CREATE POLICY "Users can create channels" ON channels FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Channel admins can update channels" ON channels FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM channel_members 
        WHERE channel_id = channels.id AND user_id = auth.uid() AND role = 'admin'
    )
);

-- RLS Policies for channel_members
CREATE POLICY "Users can view channel members for channels they're in" ON channel_members FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM channel_members cm2 
        WHERE cm2.channel_id = channel_members.channel_id AND cm2.user_id = auth.uid()
    )
);
CREATE POLICY "Channel admins can manage members" ON channel_members FOR ALL USING (
    EXISTS (
        SELECT 1 FROM channel_members 
        WHERE channel_id = channel_members.channel_id AND user_id = auth.uid() AND role = 'admin'
    )
);
CREATE POLICY "Users can join public channels" ON channel_members FOR INSERT WITH CHECK (
    user_id = auth.uid() AND EXISTS (
        SELECT 1 FROM channels 
        WHERE id = channel_id AND NOT is_private
    )
);

-- RLS Policies for messages
CREATE POLICY "Users can view messages in channels they're members of" ON messages FOR SELECT USING (
    (channel_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM channel_members 
        WHERE channel_id = messages.channel_id AND user_id = auth.uid()
    )) OR
    (recipient_id IS NOT NULL AND (user_id = auth.uid() OR recipient_id = auth.uid()))
);
CREATE POLICY "Users can send messages to channels they're members of" ON messages FOR INSERT WITH CHECK (
    user_id = auth.uid() AND (
        (channel_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM channel_members 
            WHERE channel_id = messages.channel_id AND user_id = auth.uid()
        )) OR
        (recipient_id IS NOT NULL)
    )
);
CREATE POLICY "Users can update their own messages" ON messages FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete their own messages" ON messages FOR DELETE USING (user_id = auth.uid());

-- RLS Policies for direct_message_participants
CREATE POLICY "Users can view their DM conversations" ON direct_message_participants FOR SELECT USING (
    user1_id = auth.uid() OR user2_id = auth.uid()
);
CREATE POLICY "Users can create DM conversations" ON direct_message_participants FOR INSERT WITH CHECK (
    user1_id = auth.uid() OR user2_id = auth.uid()
);

-- Function to handle profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, avatar_url)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', new.email),
        new.raw_user_meta_data->>'avatar_url'
    );
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically create profile for new users
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Function to update direct_message_participants when DM is sent
CREATE OR REPLACE FUNCTION update_dm_participants()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.recipient_id IS NOT NULL THEN
        INSERT INTO direct_message_participants (user1_id, user2_id, last_message_at)
        VALUES (
            LEAST(NEW.user_id, NEW.recipient_id),
            GREATEST(NEW.user_id, NEW.recipient_id),
            NEW.created_at
        )
        ON CONFLICT (user1_id, user2_id) 
        DO UPDATE SET last_message_at = NEW.created_at;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update DM participants
CREATE TRIGGER on_dm_message_sent
    AFTER INSERT ON messages
    FOR EACH ROW EXECUTE PROCEDURE update_dm_participants();

-- Insert default channels
INSERT INTO channels (name, description, is_private, created_by) VALUES
('general', 'Company-wide announcements and general discussion', false, null),
('random', 'Non-work related chatter and fun stuff', false, null),
('development', 'Development team discussions', false, null);
