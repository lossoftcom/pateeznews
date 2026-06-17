import { useCallback, useEffect, useState } from 'react';
import {
  StoryEditor,
  InterfaceSkeleton,
  useStory,
} from '@googleforcreators/story-editor';
import { elementTypes } from '@googleforcreators/element-library';
import { registerElementType } from '@googleforcreators/elements';
import { DATA_VERSION } from '@googleforcreators/migration';

import {
  installHostReceiver,
  onHostEvent,
  postToHost,
  hostRequest,
} from './host.js';
import { getFonts } from './fonts.js';
import { getMedia, uploadMedia, updateMedia, deleteMedia } from './media.js';
import Header from './Header.jsx';

// Note: Turkish locale is installed in setupLocale.js, imported first in
// main.jsx, so it is active before this module's editor imports evaluate.

// Register all built-in element types exactly once (per official getting-started).
elementTypes.forEach(registerElementType);

// Official GoogleForCreators CDN: backs default page templates, shapes,
// stickers, and text-set previews.
const CDN_URL = 'https://wp.stories.google/static/main/';

// Stories saved by this editor are always at the current data version, but the
// version field may be absent in the persisted JSON. Without it the loader runs
// `migrate(storyData, 0)` and re-applies every migration to already-current data,
// corrupting the pages (TypeError: e.map is not a function). Stamp the current
// version when a story already has pages but no version so migrate becomes a
// no-op.
function normalizeIncomingStory(story) {
  if (!story || typeof story !== 'object') return {};
  const { storyData } = story;
  if (
    storyData &&
    typeof storyData === 'object' &&
    Array.isArray(storyData.pages) &&
    storyData.pages.length > 0 &&
    storyData.version == null
  ) {
    return { ...story, storyData: { ...storyData, version: DATA_VERSION } };
  }
  return story;
}

const ALLOWED_MIME_TYPES = {
  image: [
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/gif',
    'image/webp',
    'image/avif',
  ],
  vector: [],
  video: ['video/mp4', 'video/webm'],
  audio: ['audio/mpeg', 'audio/aac', 'audio/wav', 'audio/ogg'],
  caption: ['text/vtt'],
};

// Lives INSIDE <StoryEditor> so it can drive the editor's own save action when
// the host asks for one (kept as a backup path; the Header has its own button).
function SaveBridge() {
  const saveStory = useStory(({ actions }) => actions.saveStory);
  useEffect(() => {
    return onHostEvent('SAVE_REQUEST', () => {
      try {
        saveStory();
      } catch (_) {
        /* ignore */
      }
    });
  }, [saveStory]);
  return null;
}

export default function Editor() {
  // null = still waiting for the host to send the initial story payload.
  const [story, setStory] = useState(null);

  useEffect(() => {
    installHostReceiver();
    const off = onHostEvent('LOAD', (detail) => {
      setStory(normalizeIncomingStory(detail.story));
    });
    // Tell the host we are mounted and ready to receive the initial story.
    postToHost('READY');
    // Standalone (vite dev) fallback so the editor is verifiable without a host.
    let devTimer;
    if (import.meta.env && import.meta.env.DEV) {
      devTimer = setTimeout(
        () => setStory((current) => (current === null ? {} : current)),
        800
      );
    }
    return () => {
      off();
      if (devTimer) clearTimeout(devTimer);
    };
  }, []);

  // Persisted shape mirrors the official tutorial's `storySaveData` so it can be
  // fed straight back into `initialEdits.story` when re-editing. We await the
  // host's SAVE_RESULT so the editor's native "saved/failed" snackbar is honest.
  const saveStoryById = useCallback(async (storyState) => {
    const { pages, globalStoryStyles, currentStoryStyles, content, title } =
      storyState || {};
    const savedStory = {
      title: { raw: typeof title === 'string' ? title : '' },
      storyData: {
        // Persist the data version so re-opening doesn't re-run migrations.
        version: DATA_VERSION,
        pages: Array.isArray(pages) ? pages : [],
        currentStoryStyles: currentStoryStyles || {},
      },
      stylePresets: globalStoryStyles || {},
    };
    const reply = await hostRequest(
      'SAVE',
      {
        payload: {
          title: savedStory.title.raw,
          // `content` is the editor-generated AMP markup (per official tutorial).
          markup: typeof content === 'string' ? content : '',
          story: savedStory,
        },
      },
      { timeout: 60000 }
    );
    // A real host failure rejects so the editor shows its error snackbar; a
    // timeout (e.g. standalone dev with no host) resolves quietly.
    if (reply && reply.ok === false && !reply.timeout) {
      throw new Error(reply.error || 'Kaydetme başarısız');
    }
    return {};
  }, []);

  if (story === null) {
    // The Flutter host draws its own loading overlay until LOAD arrives.
    return null;
  }

  const config = {
    cdnURL: CDN_URL,
    isRTL: false,
    showMedia3p: false,
    maxUpload: 1024 * 1024 * 1024,
    canViewDefaultTemplates: true,
    capabilities: { hasUploadMediaAction: true },
    allowedMimeTypes: ALLOWED_MIME_TYPES,
    apiCallbacks: {
      saveStoryById,
      getFonts,
      getMedia,
      uploadMedia,
      updateMedia,
      deleteMedia,
    },
  };

  return (
    <StoryEditor config={config} initialEdits={{ story }}>
      <InterfaceSkeleton header={<Header />} />
      <SaveBridge />
    </StoryEditor>
  );
}
