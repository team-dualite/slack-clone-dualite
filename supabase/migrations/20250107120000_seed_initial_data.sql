/*
# Initial Seed Data for Slack Clone
Creates default channels and ensures proper setup for new users

## Query Description: 
This operation adds initial channels to make the app functional immediately.
Creates public channels like #general and #random that all users can join.
Safe operation that only inserts data if it doesn't already exist.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Inserts default public channels (general, random, development)
- Uses ON CONFLICT DO NOTHING to prevent duplicates

## Security Implications:
- RLS Status: Enabled
- Policy Changes: No
- Auth Requirements: No special requirements

## Performance Impact:
- Indexes: No changes
- Triggers: No changes  
- Estimated Impact: Minimal - just inserting a few rows
*/

-- Insert default channels if they don't exist
INSERT INTO channels (id, name, description, is_private, created_by) 
VALUES 
  ('550e8400-e29b-41d4-a716-446655440001', 'general', 'Company-wide announcements and general discussion', false, null),
  ('550e8400-e29b-41d4-a716-446655440002', 'random', 'Non-work related chatter and fun stuff', false, null),
  ('550e8400-e29b-41d4-a716-446655440003', 'development', 'Development team discussions and code reviews', false, null)
ON CONFLICT (name) DO NOTHING;

-- Create a function to automatically add users to public channels
CREATE OR REPLACE FUNCTION auto_join_public_channels()
RETURNS TRIGGER AS $$
BEGIN
  -- Add user to all public channels
  INSERT INTO channel_members (channel_id, user_id, role)
  SELECT id, NEW.id, 'member'
  FROM channels 
  WHERE is_private = false
  ON CONFLICT (channel_id, user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to auto-join public channels when user profile is created
DROP TRIGGER IF EXISTS auto_join_public_channels_trigger ON profiles;
CREATE TRIGGER auto_join_public_channels_trigger
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_join_public_channels();
