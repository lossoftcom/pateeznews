import { useCallback, useEffect, useState } from 'react';
import {
  StoryEditor,
  InterfaceSkeleton,
  useStory,
} from '@googleforcreators/story-editor';
import { elementTypes } from '@googleforcreators/element-library';
import { registerElementType } from '@googleforcreators/elements';

// Register all built-in element types exactly once (per official getting-started).
elementTypes.forEach(registerElementType);

// Bridge namespaces. Kept distinct from the posta_builder (LOSPOSTA_*) bridge.
const HOST_SOURCE = 'PATEEZ_WS_HOST'; // messages coming FROM the Flutter host
const EDITOR_SOURCE = 'PATEEZ_WS_EDITOR'; // messages going TO the Flutter host
const NATIVE_HANDLER = 'PateezWebStories'; // flutter_inappwebview JavaScript handler
const HOST_EVENT = 'pateez-ws-host'; // internal CustomEvent re-broadcast

function isNativeHost() {
  return typeof window !== 'undefined' && Boolean(window.flutter_inappwebview);
}

function postToHost(type, extra) {
  const message = { source: EDITOR_SOURCE, type, ...(extra || {}) };
  try {
    if (isNativeHost()) {
      window.flutter_inappwebview.callHandler(NATIVE_HANDLER, message);
    } else {
      window.parent.postMessage(message, '*');
    }
  } catch (_) {
    /* no-op: the host may have detached */
  }
}

// Install a single host->editor receiver (web postMessage + native
// __pateezWsReceive) that re-broadcasts as a CustomEvent so multiple components
// (Editor, SaveBridge) can react to the same host messages on either transport.
let receiverInstalled = false;
function installHostReceiver() {
  if (receiverInstalled) return;
  receiverInstalled = true;
  const dispatch = (data) => {
    if (!data || data.source !== HOST_SOURCE) return;
    window.dispatchEvent(new CustomEvent(HOST_EVENT, { detail: data }));
  };
  window.addEventListener('message', (event) => dispatch(event.data));
  window.__pateezWsReceive = (raw) => {
    try {
      dispatch(typeof raw === 'string' ? JSON.parse(raw) : raw);
    } catch (_) {
      /* ignore malformed payloads */
    }
  };
}

// Lives INSIDE <StoryEditor> so it can access the editor's `saveStory` action
// (the editor renders no top header/save button in this minimal embed, so the
// Flutter dialog's "Save" button drives saving through a SAVE_REQUEST message).
function SaveBridge() {
  const saveStory = useStory(({ actions }) => actions.saveStory);
  useEffect(() => {
    function onHost(event) {
      if (event.detail && event.detail.type === 'SAVE_REQUEST') {
        try {
          saveStory();
        } catch (_) {
          /* ignore */
        }
      }
    }
    window.addEventListener(HOST_EVENT, onHost);
    return () => window.removeEventListener(HOST_EVENT, onHost);
  }, [saveStory]);
  return null;
}

export default function Editor() {
  // null = still waiting for the host to send the initial story payload.
  const [story, setStory] = useState(null);

  useEffect(() => {
    installHostReceiver();
    function onHost(event) {
      if (event.detail && event.detail.type === 'LOAD') {
        const incoming =
          event.detail.story && typeof event.detail.story === 'object'
            ? event.detail.story
            : {};
        setStory(incoming);
      }
    }
    window.addEventListener(HOST_EVENT, onHost);
    // Tell the host we are mounted and ready to receive the initial story.
    postToHost('READY');
    return () => window.removeEventListener(HOST_EVENT, onHost);
  }, []);

  const saveStoryById = useCallback((storyState) => {
    const { pages, globalStoryStyles, currentStoryStyles, content, title } =
      storyState || {};
    // Persisted shape mirrors the official tutorial's `storySaveData` so it can
    // be fed straight back into `initialEdits.story` when re-editing.
    const savedStory = {
      title: { raw: typeof title === 'string' ? title : '' },
      storyData: {
        pages: Array.isArray(pages) ? pages : [],
        currentStoryStyles: currentStoryStyles || {},
      },
      stylePresets: globalStoryStyles || {},
    };
    postToHost('SAVE', {
      payload: {
        title: savedStory.title.raw,
        // `content` is the editor-generated AMP markup (per official tutorial).
        markup: typeof content === 'string' ? content : '',
        story: savedStory,
      },
    });
    return Promise.resolve({});
  }, []);

  if (story === null) {
    // The Flutter host draws its own loading overlay until LOAD arrives.
    return null;
  }

  const config = { apiCallbacks: { saveStoryById } };

  return (
    <StoryEditor config={config} initialEdits={{ story }}>
      <InterfaceSkeleton />
      <SaveBridge />
    </StoryEditor>
  );
}
