import React from 'react';
import { Hash, Lock, Plus, Circle, Users, LogOut } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

interface Channel {
  id: string;
  name: string;
  description: string | null;
  is_private: boolean;
  memberCount: number;
}

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

interface SidebarProps {
  channels: Channel[];
  directMessages: DirectMessage[];
  profiles: Profile[];
  activeChannelId: string | null;
  activeDMUserId: string | null;
  onChannelSelect: (channelId: string) => void;
  onDMSelect: (userId: string) => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  channels,
  directMessages,
  profiles,
  activeChannelId,
  activeDMUserId,
  onChannelSelect,
  onDMSelect
}) => {
  const { user, signOut } = useAuth();

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'online': return 'bg-green-400';
      case 'away': return 'bg-yellow-400';
      default: return 'bg-gray-400';
    }
  };

  const handleSignOut = async () => {
    await signOut();
  };

  const onlineUsers = profiles.filter(p => p.status === 'online');

  return (
    <div className="w-64 bg-purple-900 text-white flex flex-col h-full">
      {/* Header */}
      <div className="p-4 border-b border-purple-800">
        <h1 className="text-lg font-bold">SlackClone</h1>
        <div className="flex items-center justify-between mt-2">
          <div className="flex items-center text-sm text-purple-200">
            <Circle className="w-2 h-2 fill-green-400 text-green-400 mr-2" />
            You
          </div>
          <button
            onClick={handleSignOut}
            className="p-1 hover:bg-purple-800 rounded text-purple-200 hover:text-white transition-colors"
            title="Sign out"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Scrollable content */}
      <div className="flex-1 overflow-y-auto">
        {/* Channels Section */}
        <div className="p-4">
          <div className="flex items-center justify-between mb-2">
            <h2 className="text-sm font-semibold text-purple-200">Channels</h2>
            <Plus className="w-4 h-4 text-purple-300 hover:text-white cursor-pointer transition-colors" />
          </div>
          <div className="space-y-1">
            {channels.map((channel) => (
              <div
                key={channel.id}
                onClick={() => onChannelSelect(channel.id)}
                className={`flex items-center px-2 py-1 rounded cursor-pointer transition-colors hover:bg-purple-800 ${
                  activeChannelId === channel.id ? 'bg-blue-600' : ''
                }`}
              >
                {channel.is_private ? (
                  <Lock className="w-4 h-4 mr-2 text-purple-300" />
                ) : (
                  <Hash className="w-4 h-4 mr-2 text-purple-300" />
                )}
                <span className="text-sm">{channel.name}</span>
                {channel.memberCount > 0 && (
                  <span className="ml-auto text-xs text-purple-300">
                    {channel.memberCount}
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Direct Messages Section */}
        <div className="p-4">
          <div className="flex items-center justify-between mb-2">
            <h2 className="text-sm font-semibold text-purple-200">Direct Messages</h2>
            <Plus className="w-4 h-4 text-purple-300 hover:text-white cursor-pointer transition-colors" />
          </div>
          <div className="space-y-1">
            {directMessages.map((dm) => (
              <div
                key={dm.user.id}
                onClick={() => onDMSelect(dm.user.id)}
                className={`flex items-center px-2 py-1 rounded cursor-pointer transition-colors hover:bg-purple-800 ${
                  activeDMUserId === dm.user.id ? 'bg-blue-600' : ''
                }`}
              >
                <div className="relative mr-2">
                  <img
                    src={dm.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(dm.user.full_name)}&background=6366f1&color=fff`}
                    alt={dm.user.full_name}
                    className="w-5 h-5 rounded-full"
                  />
                  <div className={`absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full border border-purple-900 ${getStatusColor(dm.user.status)}`} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <span className="text-sm truncate">{dm.user.full_name}</span>
                    {dm.unreadCount > 0 && (
                      <span className="bg-red-500 text-xs px-1.5 py-0.5 rounded-full">
                        {dm.unreadCount}
                      </span>
                    )}
                  </div>
                  {dm.lastMessage && (
                    <p className="text-xs text-purple-300 truncate">{dm.lastMessage}</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Online Users */}
        {onlineUsers.length > 0 && (
          <div className="p-4">
            <div className="flex items-center mb-2">
              <Users className="w-4 h-4 mr-2 text-purple-300" />
              <h2 className="text-sm font-semibold text-purple-200">
                Online ({onlineUsers.length})
              </h2>
            </div>
            <div className="space-y-1">
              {onlineUsers.map((profile) => (
                <div
                  key={profile.id}
                  onClick={() => onDMSelect(profile.id)}
                  className="flex items-center px-2 py-1 rounded cursor-pointer transition-colors hover:bg-purple-800"
                >
                  <div className="relative mr-2">
                    <img
                      src={profile.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(profile.full_name)}&background=6366f1&color=fff`}
                      alt={profile.full_name}
                      className="w-5 h-5 rounded-full"
                    />
                    <div className={`absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full border border-purple-900 ${getStatusColor(profile.status)}`} />
                  </div>
                  <span className="text-sm">{profile.full_name}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
