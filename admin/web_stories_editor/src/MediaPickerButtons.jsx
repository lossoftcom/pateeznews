import { useCallback, useState } from 'react';
import { useStory } from '@googleforcreators/story-editor';
import useInsertElement from '@googleforcreators/story-editor/dist-module/components/canvas/useInsertElement.js';
import { resourceList } from '@googleforcreators/media';

import { pickMediaResource } from './media.js';

const GROUP = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: '6px',
  flex: '0 0 auto',
};

const SIDEBAR_GROUP = {
  ...GROUP,
  flex: '1 1 auto',
  minWidth: 0,
};

const BUTTON = (busy, sidebar = false) => ({
  height: '36px',
  padding: sidebar ? '0 10px' : '0 12px',
  borderRadius: '6px',
  border: '1px solid #3a3a44',
  background: busy ? '#30303a' : '#23232b',
  color: '#f5f5f7',
  fontSize: '12px',
  fontWeight: 700,
  lineHeight: 1,
  cursor: busy ? 'default' : 'pointer',
  whiteSpace: 'nowrap',
  flex: sidebar ? '1 1 0' : '0 0 auto',
  minWidth: sidebar ? '0' : undefined,
});

function cacheResource(resource) {
  resourceList.set(resource.id, {
    url: resource.sizes?.medium?.source_url || resource.poster || resource.src,
    type: 'cached',
  });
}

export default function MediaPickerButtons({
  placement = 'header',
  onPickedResource,
} = {}) {
  const [busyType, setBusyType] = useState(null);
  const insertElement = useInsertElement();
  const sidebar = placement === 'sidebar';
  const { updateCurrentPageProperties } = useStory(({ actions }) => ({
    updateCurrentPageProperties: actions.updateCurrentPageProperties,
  }));

  const pick = useCallback(
    async (mediaType) => {
      if (busyType) return;
      setBusyType(mediaType);
      try {
        const resource = await pickMediaResource(mediaType);
        if (!resource) return;
        cacheResource(resource);
        onPickedResource?.(resource);
        if (resource.type === 'audio') {
          updateCurrentPageProperties({
            properties: { backgroundAudio: { resource, loop: false, tracks: [] } },
          });
          return;
        }
        insertElement(resource.type, { resource });
      } finally {
        setBusyType(null);
      }
    },
    [busyType, insertElement, onPickedResource, updateCurrentPageProperties]
  );

  return (
    <div style={sidebar ? SIDEBAR_GROUP : GROUP}>
      <button
        type="button"
        style={BUTTON(busyType === 'image', sidebar)}
        onClick={() => pick('image')}
        disabled={Boolean(busyType)}
        title="Medya kutuphanesinden resim sec"
      >
        Resim
      </button>
      <button
        type="button"
        style={BUTTON(busyType === 'video', sidebar)}
        onClick={() => pick('video')}
        disabled={Boolean(busyType)}
        title="Medya kutuphanesinden video sec"
      >
        Video
      </button>
      <button
        type="button"
        style={BUTTON(busyType === 'audio', sidebar)}
        onClick={() => pick('audio')}
        disabled={Boolean(busyType)}
        title="Medya kutuphanesinden ses sec"
      >
        Ses
      </button>
    </div>
  );
}
