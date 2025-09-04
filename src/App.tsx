import React, { useState, useEffect } from 'react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { AuthForm } from './components/AuthForm';
import { Sidebar } from './components/Sidebar';
import { ChatHeader } from './components/ChatHeader';
import { MessageList } from './components/MessageList';
import { MessageInput } from './components/MessageInput';
import { useChannels } from './hooks/useChannels';
import { useMessages } from './hooks/useMessages';
import { useProfiles } from './hooks/useProfiles';

const MainApp: React.FC = () => {
  const { user, loading: authLoading } = useAuth();
  const [activeChannelId, setActiveChannelId] = useState<string | null>(null);
  const [activeDMUserId, setActiveDMUserId] = useState<string | null>(null);

  const { channels, loading: channelsLoading } = useChannels();
  const { profiles, directMessages, loading: profilesLoading } = useProfiles();
  const { messages, loading: messagesLoading, sendMessage } = useMessages(
    activeChannelId,
    activeDMUserId
  );

  // Auto-select general channel when channels are loaded
  useEffect(() => {
    if (channels.length > 0 && !activeChannelId && !activeDMUserId) {
      const generalChannel = channels.find(c => c.name === 'general');
      if (generalChannel) {
        setActiveChannelId(generalChannel.id);
      } else {
        // If no general channel, select the first available channel
        setActiveChannelId(channels[0].id);
      }
    }
  }, [channels, activeChannelId, activeDMUserId]);

  const handleChannelSelect = (channelId: string) => {
    setActiveChannelId(channelId);
    setActiveDMUserId(null);
  };

  const handleDMSelect = (userId: string) => {
    setActiveDMUserId(userId);
    setActiveChannelId(null);
  };

  const handleSendMessage = async (content: string) => {
    await sendMessage(content);
  };

  const activeChannel = channels.find(c => c.id === activeChannelId);
  const activeDMUser = profiles.find(u => u.id === activeDMUserId);

  const getPlaceholder = () => {
    if (activeChannel) {
      return `Message #${activeChannel.name}`;
    } else if (activeDMUser) {
      return `Message ${activeDMUser.full_name}`;
    }
    return 'Type a message...';
  };

  if (authLoading) {
    return (
      <div className="h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <AuthForm />;
  }

  const isLoading = channelsLoading || profilesLoading;

  return (
    <div className="h-screen flex bg-gray-50">
      <Sidebar
        channels={channels}
        directMessages={directMessages}
        profiles={profiles}
        activeChannelId={activeChannelId}
        activeDMUserId={activeDMUserId}
        onChannelSelect={handleChannelSelect}
        onDMSelect={handleDMSelect}
      />
      
      <div className="flex-1 flex flex-col">
        {isLoading ? (
          <div className="flex-1 flex items-center justify-center">
            <div className="text-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600 mx-auto mb-2"></div>
              <p className="text-gray-600">Setting up your workspace...</p>
            </div>
          </div>
        ) : (
          <>
            <ChatHeader
              activeChannel={activeChannel}
              activeDMUser={activeDMUser}
            />
            
            <MessageList
              messages={messages}
              loading={messagesLoading}
            />
            
            <MessageInput
              onSendMessage={handleSendMessage}
              placeholder={getPlaceholder()}
            />
          </>
        )}
      </div>
    </div>
  );
};

function App() {
  return (
    <AuthProvider>
      <MainApp />
    </AuthProvider>
  );
}

export default App;
