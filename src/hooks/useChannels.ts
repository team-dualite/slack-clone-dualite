import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface Channel {
  id: string;
  name: string;
  description: string | null;
  is_private: boolean;
  memberCount: number;
}

export const useChannels = () => {
  const [channels, setChannels] = useState<Channel[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();

  useEffect(() => {
    if (!user) return;

    const fetchChannels = async () => {
      try {
        // First, get all channels the user has access to (public + private channels they're a member of)
        const { data: channelData, error } = await supabase
          .from('channels')
          .select('*')
          .order('name');

        if (error) {
          console.error('Error fetching channels:', error);
          setLoading(false);
          return;
        }

        // Get member counts for each channel
        const channelsWithCounts = await Promise.all(
          (channelData || []).map(async (channel) => {
            const { count } = await supabase
              .from('channel_members')
              .select('*', { count: 'exact', head: true })
              .eq('channel_id', channel.id);

            return {
              id: channel.id,
              name: channel.name,
              description: channel.description,
              is_private: channel.is_private,
              memberCount: count || 0
            };
          })
        );

        setChannels(channelsWithCounts);
      } catch (error) {
        console.error('Error in fetchChannels:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchChannels();

    // Subscribe to channel changes
    const subscription = supabase
      .channel('channels_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'channels',
        },
        () => {
          fetchChannels();
        }
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'channel_members',
        },
        (payload) => {
          // Refresh channels when membership changes for current user
          if (payload.new?.user_id === user.id || payload.old?.user_id === user.id) {
            fetchChannels();
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(subscription);
    };
  }, [user]);

  return { channels, loading };
};
