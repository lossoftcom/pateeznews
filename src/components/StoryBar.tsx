import React, { useEffect, useState } from 'react';
import { Eye, X, Zap } from 'lucide-react';
import { neon } from '@/lib/neon';
import { trackStoryView } from '@/services/appActions';

interface StoryBarProps {
  initialStories?: any[];
}

const StoryBar: React.FC<StoryBarProps> = ({ initialStories }) => {
  const [stories, setStories] = useState<any[]>(initialStories || []);
  const [loading, setLoading] = useState(!initialStories || initialStories.length === 0);
  const [activeStoryIndex, setActiveStoryIndex] = useState<number | null>(null);

  useEffect(() => {
    if (initialStories && initialStories.length > 0) {
      setStories(initialStories);
      setLoading(false);
      return;
    }

    const fetchStories = async () => {
      try {
        setLoading(true);
        const { data, error } = await neon
          .from('stories')
          .select('*')
          .eq('is_active', true)
          .order('created_at', { ascending: false });

        if (!error && data) {
          setStories(data);
        }
      } catch (err) {
        console.error('Error fetching stories:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchStories();
  }, [initialStories]);

  if (loading) {
    return (
      <div className="w-full pb-1 pt-2">
        <div className="flex gap-2 overflow-x-auto px-1 pb-4 no-scrollbar items-start">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <div key={i} className="flex-shrink-0 w-[120px] h-[200px] rounded-[5px] bg-palette-beige/5 animate-pulse border border-palette-beige/10" />
          ))}
        </div>
      </div>
    );
  }

  if (stories.length === 0) return null;

  const activeStory = activeStoryIndex !== null ? stories[activeStoryIndex] : null;
  const openStory = (index: number) => {
    setActiveStoryIndex(index);
    const story = stories[index];
    if (!story?.id) return;
    trackStoryView(story.id)
      .then((result) => {
        setStories((prev) => prev.map((item, itemIndex) => (
          itemIndex === index ? { ...item, view_count: result.viewCount, viewCount: result.viewCount } : item
        )));
      })
      .catch(() => null);
  };

  return (
    <div className="w-full pb-1 pt-2">
      {/* Scroll Container */}
      <div className="flex gap-2 overflow-x-auto px-1 pb-4 no-scrollbar items-start">

        {/* Story Item */}
        {stories.map((story) => (
          <div
            key={story.id}
            onClick={() => openStory(stories.indexOf(story))}
            className="group relative flex-shrink-0 w-[120px] h-[200px] rounded-[5px] cursor-pointer transition-all duration-75 hover:-translate-y-1.5"
          >
            {/* Arka plan gölgesi - Glow Effect */}
            <div className="absolute inset-2 bg-blue-500/20 rounded-[5px] blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-100" />

            {/* Main Card Container */}
            <div className="relative w-full h-full rounded-[5px] overflow-hidden shadow-sm hover:shadow-xl border border-gray-100 bg-gray-900 transition-all duration-100 z-10">

              {/* Image */}
              <img
                src={story.media_url || story.image}
                alt={story.title}
                className="w-full h-full object-cover opacity-90 group-hover:opacity-100 group-hover:scale-110 transition-transform duration-200 ease-out"
              />

              {/* Gradient Overlay */}
              <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent" />
              <div className="absolute inset-0 bg-gradient-to-b from-black/30 via-transparent to-transparent opacity-60" />

              {/* Top Badge: Source Avatar */}
              <div className="absolute top-3 left-3 flex items-center gap-1.5">
                <div className="relative w-8 h-8 p-[1.5px] rounded-[5px] bg-gradient-to-tr from-blue-400 to-purple-500 shadow-lg">
                  <div className="w-full h-full rounded-[5px] overflow-hidden border border-black/20">
                    <img
                      src={`https://picsum.photos/seed/src${story.id}/100`}
                      alt="Source"
                      className="w-full h-full object-cover"
                    />
                  </div>
                </div>
              </div>

              {/* Bottom Content */}
              <div className="absolute bottom-0 left-0 w-full p-3.5 pt-6 bg-gradient-to-t from-black/80 via-black/40 to-transparent">
                {/* Kategori Tag */}
                <div className="flex items-center gap-1 mb-1.5 opacity-80">
                  <Zap size={10} className="text-yellow-400 fill-yellow-400" />
                  <span className="text-[9px] font-black text-blue-200 uppercase tracking-widest">{story.source_name || story.source || 'Pateez'}</span>
                </div>

                {/* Title */}
                <p className="text-[11px] font-bold text-white leading-snug line-clamp-3 drop-shadow-sm group-hover:text-blue-50 transition-colors">
                  {story.title}
                </p>
              </div>

              {/* Active Border Indicator (On Hover) */}
              <div className="absolute inset-0 rounded-[5px] border-2 border-white/0 group-hover:border-white/20 transition-all duration-300 pointer-events-none" />
            </div>
          </div>
        ))}
      </div>

      {activeStory && (
        <div className="fixed inset-0 z-[500] bg-gray-950/90 backdrop-blur-md flex items-center justify-center p-4 animate-in fade-in">
          <button
            onClick={() => setActiveStoryIndex(null)}
            className="absolute top-5 right-5 w-11 h-11 rounded-[5px] bg-white/10 text-white flex items-center justify-center hover:bg-white/20 transition-colors"
          >
            <X size={22} />
          </button>
          <div className="w-full max-w-[420px] aspect-[9/16] rounded-[5px] overflow-hidden bg-black shadow-2xl border border-white/10 relative">
            {String(activeStory.media_type || activeStory.mediaType).toLowerCase() === 'video' ? (
              <video src={activeStory.media_url || activeStory.mediaUrl} className="w-full h-full object-cover" controls autoPlay />
            ) : (
              <img src={activeStory.media_url || activeStory.mediaUrl || activeStory.image} alt={activeStory.title} className="w-full h-full object-cover" />
            )}
            <div className="absolute inset-x-0 bottom-0 p-6 bg-gradient-to-t from-black/90 via-black/40 to-transparent text-white">
              <div className="flex items-center gap-2 text-[10px] font-black uppercase tracking-widest text-white/60 mb-2">
                <Zap size={12} className="text-yellow-400 fill-yellow-400" />
                <span>{activeStory.source_name || activeStory.source || 'Pateez'}</span>
                <span className="ml-auto flex items-center gap-1"><Eye size={12} /> {activeStory.view_count || activeStory.viewCount || 0}</span>
              </div>
              <h3 className="text-lg font-black leading-tight">{activeStory.title}</h3>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default StoryBar;
