import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface Profile {
  id: string;
  full_name: string;
  avatar_url: string | null;
  status: 'online' | 'away' | 'offline';
}

interface DirectMessage {
  user: Profile;
  lastMessage: string | null;
  lastMessageTime: string | null;
  unreadCount: number;
}

export const useProfiles = () => {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [directMessages, setDirectMessages] = useState<DirectMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();

  useEffect(() => {
    if (!user) return;

    const fetchProfiles = async () => {
      try {
        const { data: profilesData, error } = await supabase
          .from('profiles')
          .select('*')
          .neq('id', user.id);

        if (error) {
          console.error('Error fetching profiles:', error);
          return;
        }

        setProfiles(profilesData || []);

        // Create DM conversations for all other users
        const dmPromises = (profilesData || []).map(async (profile) => {
          // Check if DM conversation exists
          const { data: existingDM } = await supabase
            .from('direct_message_participants')
            .select('*')
            .or(`and(user1_id.eq.${user.id},user2_id.eq.${profile.id}),and(user1_id.eq.${profile.id},user2_id.eq.${user.id})`)
            .single();

          if (!existingDM) {
            // Create DM conversation
            await supabase
              .from('direct_message_participants')
              .insert({
                user1_id: user.id,
                user2_id: profile.id,
              });
          }

          // Get last message between users
          const { data: lastMessage } = await supabase
            .from('messages')
            .select('content, created_at')
            .is('channel_id', null)
            .or(`and(user_id.eq.${user.id},recipient_id.eq.${profile.id}),and(user_id.eq.${profile.id},recipient_id.eq.${user.id})`)
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle();

          return {
            user: profile,
            lastMessage: lastMessage?.content || null,
            lastMessageTime: lastMessage?.created_at || null,
            unreadCount: 0,
          };
        });

        const dmResults = await Promise.all(dmPromises);
        setDirectMessages(dmResults);
      } catch (error) {
        console.error('Error in fetchProfiles:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchProfiles();

    // Subscribe to profile changes for real-time status updates
    const subscription = supabase
      .channel('profiles_status')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'profiles',
        },
        (payload) => {
          setProfiles(prev =>
            prev.map(profile =>
              profile.id === payload.new.id
                ? { ...profile, ...payload.new }
                : profile
            )
          );
          
          // Update DM list as well
          setDirectMessages(prev =>
            prev.map(dm =>
              dm.user.id === payload.new.id
                ? { ...dm, user: { ...dm.user, ...payload.new } }
                : dm
            )
          );
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(subscription);
    };
  }, [user]);

  return { profiles, directMessages, loading };
};
