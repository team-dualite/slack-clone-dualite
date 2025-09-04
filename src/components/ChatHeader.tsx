import React from 'react';
import { Hash, Lock, Users, Phone, Video, Star, Settings } from 'lucide-react';

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

interface ChatHeaderProps {
  activeChannel?: Channel;
  activeDMUser?: Profile;
}

export const ChatHeader: React.FC<ChatHeaderProps> = ({
  activeChannel,
  activeDMUser,
}) => {
  return (
    <div className="h-16 bg-white border-b border-gray-200 flex items-center justify-between px-6">
      <div className="flex items-center">
        {activeChannel ? (
          <>
            {activeChannel.is_private ? (
              <Lock className="w-5 h-5 text-gray-500 mr-2" />
            ) : (
              <Hash className="w-5 h-5 text-gray-500 mr-2" />
            )}
            <div>
              <h1 className="text-xl font-semibold text-gray-900">
                {activeChannel.name}
              </h1>
              <p className="text-sm text-gray-500">{activeChannel.description}</p>
            </div>
          </>
        ) : activeDMUser ? (
          <>
            <div className="relative mr-3">
              <img
                src={activeDMUser.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(activeDMUser.full_name)}&background=6366f1&color=fff`}
                alt={activeDMUser.full_name}
                className="w-8 h-8 rounded-full"
              />
              <div className={`absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-white ${
                activeDMUser.status === 'online' ? 'bg-green-400' :
                activeDMUser.status === 'away' ? 'bg-yellow-400' : 'bg-gray-400'
              }`} />
            </div>
            <div>
              <h1 className="text-xl font-semibold text-gray-900">
                {activeDMUser.full_name}
              </h1>
              <p className="text-sm text-gray-500 capitalize">{activeDMUser.status}</p>
            </div>
          </>
        ) : null}
      </div>

      <div className="flex items-center space-x-4">
        {activeChannel && (
          <div className="flex items-center text-gray-500">
            <Users className="w-4 h-4 mr-1" />
            <span className="text-sm">{activeChannel.memberCount}</span>
          </div>
        )}
        
        <div className="flex items-center space-x-2">
          {activeDMUser && (
            <>
              <Phone className="w-5 h-5 text-gray-500 hover:text-gray-700 cursor-pointer" />
              <Video className="w-5 h-5 text-gray-500 hover:text-gray-700 cursor-pointer" />
            </>
          )}
          <Star className="w-5 h-5 text-gray-500 hover:text-gray-700 cursor-pointer" />
          <Settings className="w-5 h-5 text-gray-500 hover:text-gray-700 cursor-pointer" />
        </div>
      </div>
    </div>
  );
};
