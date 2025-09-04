import { faker } from '@faker-js/faker';
import { User, Message, Channel, DirectMessage } from '../types';

// Current user
export const currentUser: User = {
  id: 'current-user',
  name: 'You',
  email: 'you@company.com',
  avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop&crop=face',
  status: 'online',
  isCurrentUser: true
};

// Mock users
export const users: User[] = [
  currentUser,
  {
    id: '1',
    name: 'Sarah Johnson',
    email: 'sarah@company.com',
    avatar: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=40&h=40&fit=crop&crop=face',
    status: 'online'
  },
  {
    id: '2',
    name: 'Mike Chen',
    email: 'mike@company.com',
    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=40&h=40&fit=crop&crop=face',
    status: 'away'
  },
  {
    id: '3',
    name: 'Emily Davis',
    email: 'emily@company.com',
    avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=40&h=40&fit=crop&crop=face',
    status: 'online'
  },
  {
    id: '4',
    name: 'Alex Rodriguez',
    email: 'alex@company.com',
    avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=40&h=40&fit=crop&crop=face',
    status: 'offline'
  }
];

export const channels: Channel[] = [
  {
    id: 'general',
    name: 'general',
    description: 'Company-wide announcements and general discussion',
    isPrivate: false,
    memberCount: 42
  },
  {
    id: 'random',
    name: 'random',
    description: 'Non-work related chatter and fun stuff',
    isPrivate: false,
    memberCount: 38
  },
  {
    id: 'development',
    name: 'development',
    description: 'Development team discussions',
    isPrivate: false,
    memberCount: 12
  },
  {
    id: 'design',
    name: 'design',
    description: 'Design team collaboration',
    isPrivate: true,
    memberCount: 6
  },
  {
    id: 'marketing',
    name: 'marketing',
    description: 'Marketing strategy and campaigns',
    isPrivate: false,
    memberCount: 8
  }
];

export const directMessages: DirectMessage[] = [
  {
    id: '1',
    userId: '1',
    lastMessage: 'Hey, are you free for a quick call?',
    lastMessageTime: new Date(Date.now() - 1000 * 60 * 5),
    unreadCount: 2
  },
  {
    id: '2',
    userId: '2',
    lastMessage: 'Thanks for the code review!',
    lastMessageTime: new Date(Date.now() - 1000 * 60 * 30),
    unreadCount: 0
  },
  {
    id: '3',
    userId: '3',
    lastMessage: 'Can you check the latest designs?',
    lastMessageTime: new Date(Date.now() - 1000 * 60 * 60 * 2),
    unreadCount: 1
  }
];

// Generate mock messages for channels and DMs
export const generateMockMessages = (channelId?: string, recipientId?: string): Message[] => {
  const messages: Message[] = [];
  const messageCount = faker.number.int({ min: 5, max: 15 });
  
  for (let i = 0; i < messageCount; i++) {
    const randomUser = faker.helpers.arrayElement(users.filter(u => u.id !== 'current-user'));
    messages.push({
      id: faker.string.uuid(),
      content: faker.lorem.sentence(),
      userId: i % 3 === 0 ? 'current-user' : randomUser.id,
      timestamp: new Date(Date.now() - 1000 * 60 * faker.number.int({ min: 1, max: 1440 })),
      channelId,
      recipientId
    });
  }
  
  return messages.sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
};
