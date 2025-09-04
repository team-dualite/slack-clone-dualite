import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          full_name: string;
          avatar_url: string | null;
          status: 'online' | 'away' | 'offline';
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          full_name: string;
          avatar_url?: string | null;
          status?: 'online' | 'away' | 'offline';
        };
        Update: {
          full_name?: string;
          avatar_url?: string | null;
          status?: 'online' | 'away' | 'offline';
        };
      };
      channels: {
        Row: {
          id: string;
          name: string;
          description: string | null;
          is_private: boolean;
          created_by: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          name: string;
          description?: string | null;
          is_private?: boolean;
          created_by?: string | null;
        };
        Update: {
          name?: string;
          description?: string | null;
          is_private?: boolean;
        };
      };
      channel_members: {
        Row: {
          id: string;
          channel_id: string;
          user_id: string;
          role: 'admin' | 'member';
          joined_at: string;
        };
        Insert: {
          channel_id: string;
          user_id: string;
          role?: 'admin' | 'member';
        };
        Update: {
          role?: 'admin' | 'member';
        };
      };
      messages: {
        Row: {
          id: string;
          content: string;
          user_id: string;
          channel_id: string | null;
          recipient_id: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          content: string;
          user_id: string;
          channel_id?: string | null;
          recipient_id?: string | null;
        };
        Update: {
          content?: string;
        };
      };
      direct_message_participants: {
        Row: {
          id: string;
          user1_id: string;
          user2_id: string;
          last_message_at: string;
          created_at: string;
        };
        Insert: {
          user1_id: string;
          user2_id: string;
          last_message_at?: string;
        };
        Update: {
          last_message_at?: string;
        };
      };
    };
  };
};
