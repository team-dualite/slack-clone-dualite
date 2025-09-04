import React, { useEffect, useRef } from 'react';
import { format, isToday, isYesterday } from 'date-fns';
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

interface MessageListProps {
  messages: Message[];
  loading: boolean;
}

export const MessageList: React.FC<MessageListProps> = ({
  messages,
  loading
}) => {
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const { user } = useAuth();

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const formatMessageTime = (dateString: string) => {
    const date = new Date(dateString);
    if (isToday(date)) {
      return format(date, 'h:mm a');
    } else if (isYesterday(date)) {
      return `Yesterday at ${format(date, 'h:mm a')}`;
    } else {
      return format(date, 'MMM d, h:mm a');
    }
  };

  const groupMessagesByUser = (messages: Message[]) => {
    const grouped: Array<{ user: any; messages: Message[] }> = [];
    let currentGroup: { user: any; messages: Message[] } | null = null;

    messages.forEach((message) => {
      if (!currentGroup || currentGroup.user.id !== message.user_id) {
        currentGroup = { 
          user: {
            id: message.user_id,
            full_name: message.profiles.full_name,
            avatar_url: message.profiles.avatar_url,
            isCurrentUser: message.user_id === user?.id
          }, 
          messages: [message] 
        };
        grouped.push(currentGroup);
      } else {
        // Check if messages are within 5 minutes of each other
        const lastMessage = currentGroup.messages[currentGroup.messages.length - 1];
        const timeDiff = new Date(message.created_at).getTime() - new Date(lastMessage.created_at).getTime();
        
        if (timeDiff < 5 * 60 * 1000) { // 5 minutes
          currentGroup.messages.push(message);
        } else {
          currentGroup = { 
            user: {
              id: message.user_id,
              full_name: message.profiles.full_name,
              avatar_url: message.profiles.avatar_url,
              isCurrentUser: message.user_id === user?.id
            }, 
            messages: [message] 
          };
          grouped.push(currentGroup);
        }
      }
    });

    return grouped;
  };

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600"></div>
      </div>
    );
  }

  if (messages.length === 0) {
    return (
      <div className="flex-1 flex items-center justify-center text-gray-500">
        <div className="text-center">
          <p className="text-lg mb-2">No messages yet</p>
          <p className="text-sm">Start the conversation!</p>
        </div>
      </div>
    );
  }

  const groupedMessages = groupMessagesByUser(messages);

  return (
    <div className="flex-1 overflow-y-auto p-6 space-y-4">
      {groupedMessages.map((group, groupIndex) => (
        <div key={groupIndex} className="flex space-x-3">
          <img
            src={group.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(group.user.full_name)}&background=6366f1&color=fff`}
            alt={group.user.full_name}
            className="w-10 h-10 rounded-full flex-shrink-0"
          />
          <div className="flex-1">
            <div className="flex items-center space-x-2 mb-1">
              <span className="font-semibold text-gray-900">
                {group.user.isCurrentUser ? 'You' : group.user.full_name}
              </span>
              <span className="text-xs text-gray-500">
                {formatMessageTime(group.messages[0].created_at)}
              </span>
            </div>
            <div className="space-y-1">
              {group.messages.map((message) => (
                <div key={message.id} className="text-gray-900">
                  {message.content}
                </div>
              ))}
            </div>
          </div>
        </div>
      ))}
      <div ref={messagesEndRef} />
    </div>
  );
};
