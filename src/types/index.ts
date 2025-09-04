export interface User {
  id: string;
  name: string;
  email: string;
  avatar: string;
  status: 'online' | 'away' | 'offline';
  isCurrentUser?: boolean;
}

export interface Message {
  id: string;
  content: string;
  userId: string;
  timestamp: Date;
  channelId?: string;
  recipientId?: string;
}

export interface Channel {
  id: string;
  name: string;
  description: string;
  isPrivate: boolean;
  memberCount: number;
}

export interface DirectMessage {
  id: string;
  userId: string;
  lastMessage?: string;
  lastMessageTime?: Date;
  unreadCount: number;
}
