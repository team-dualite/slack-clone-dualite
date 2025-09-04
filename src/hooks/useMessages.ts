import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface Message {
  id: string;
  content: string;
  user_id: string;
  channel_id: string | null;
  recipient_id: string | null;
  created_at: string;
  profiles: {
    full_name: string;
    avatar_url: string | null;
  };
}

export const useMessages = (channelId: string | null, recipientId: string | null) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();

  useEffect(() => {
    if (!user || (!channelId && !recipientId)) {
      setMessages([]);
      setLoading(false);
      return;
    }

    const fetchMessages = async () => {
      setLoading(true);
      
      let query = supabase
        .from('messages')
        .select(`
          *,
          profiles:user_id (
            full_name,
            avatar_url
          )
        `)
        .order('created_at', { ascending: true });

      if (channelId) {
        query = query.eq('channel_id', channelId);
      } else if (recipientId) {
        query = query
          .is('channel_id', null)
          .or(`user_id.eq.${user.id},user_id.eq.${recipientId}`)
          .or(`recipient_id.eq.${user.id},recipient_id.eq.${recipientId}`);
      }

      const { data, error } = await query;

      if (error) {
        console.error('Error fetching messages:', error);
        setLoading(false);
        return;
      }

      setMessages(data || []);
      setLoading(false);
    };

    fetchMessages();

    // Subscribe to real-time messages
    let subscription: any;

    if (channelId) {
      subscription = supabase
        .channel(`messages:${channelId}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'messages',
            filter: `channel_id=eq.${channelId}`,
          },
          async (payload) => {
            if (payload.eventType === 'INSERT') {
              // Fetch the complete message with profile data
              const { data: newMessage } = await supabase
                .from('messages')
                .select(`
                  *,
                  profiles:user_id (
                    full_name,
                    avatar_url
                  )
                `)
                .eq('id', payload.new.id)
                .single();

              if (newMessage) {
                setMessages(prev => [...prev, newMessage]);
              }
            }
          }
        )
        .subscribe();
    } else if (recipientId) {
      subscription = supabase
        .channel(`dm:${user.id}:${recipientId}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'messages',
            filter: `channel_id=is.null`,
          },
          async (payload) => {
            const message = payload.new as any;
            // Check if this message is part of our DM conversation
            if (
              (message.user_id === user.id && message.recipient_id === recipientId) ||
              (message.user_id === recipientId && message.recipient_id === user.id)
            ) {
              // Fetch the complete message with profile data
              const { data: newMessage } = await supabase
                .from('messages')
                .select(`
                  *,
                  profiles:user_id (
                    full_name,
                    avatar_url
                  )
                `)
                .eq('id', message.id)
                .single();

              if (newMessage) {
                setMessages(prev => [...prev, newMessage]);
              }
            }
          }
        )
        .subscribe();
    }

    return () => {
      if (subscription) {
        supabase.removeChannel(subscription);
      }
    };
  }, [user, channelId, recipientId]);

  const sendMessage = async (content: string) => {
    if (!user) return;

    const messageData = {
      content,
      user_id: user.id,
      channel_id: channelId,
      recipient_id: recipientId,
    };

    const { error } = await supabase
      .from('messages')
      .insert(messageData);

    if (error) {
      console.error('Error sending message:', error);
    }
  };

  return { messages, loading, sendMessage };
};
