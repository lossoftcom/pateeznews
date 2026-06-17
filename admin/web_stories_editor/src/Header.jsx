import { useCallback } from 'react';
import { useStory } from '@googleforcreators/story-editor';

import { postToHost } from './host.js';
import PreviewButton from './Preview.jsx';

// Custom top bar rendered in the editor's header slot. Replaces the Flutter
// host's old "Hikayeler / Kaydet" bar: an editable story title, the editor's
// own Save action, and a close (X) button at the top-right that asks the host
// to dismiss the full-screen editor.
const BAR = {
  display: 'flex',
  alignItems: 'center',
  gap: '12px',
  height: '56px',
  padding: '0 16px',
  background: '#1b1b1f',
  borderBottom: '1px solid #2d2d35',
  boxSizing: 'border-box',
};

const TITLE_INPUT = {
  flex: '1 1 auto',
  minWidth: 0,
  height: '36px',
  padding: '0 12px',
  borderRadius: '6px',
  border: '1px solid #3a3a44',
  background: '#26262e',
  color: '#f5f5f7',
  fontSize: '14px',
  fontWeight: 600,
  outline: 'none',
};

const SAVE_BTN = (disabled) => ({
  flex: '0 0 auto',
  height: '36px',
  padding: '0 20px',
  borderRadius: '6px',
  border: 'none',
  background: disabled ? '#3f6db0' : '#1f6feb',
  color: '#ffffff',
  fontSize: '13px',
  fontWeight: 700,
  cursor: disabled ? 'default' : 'pointer',
});

const CLOSE_BTN = {
  flex: '0 0 auto',
  width: '36px',
  height: '36px',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  borderRadius: '6px',
  border: '1px solid #3a3a44',
  background: 'transparent',
  color: '#f5f5f7',
  fontSize: '18px',
  lineHeight: 1,
  cursor: 'pointer',
};

export default function Header() {
  const { title, isSaving, saveStory, updateStory } = useStory(
    ({ state, actions }) => ({
      title: state.story.title,
      isSaving: state.meta.isSaving,
      saveStory: actions.saveStory,
      updateStory: actions.updateStory,
    })
  );

  const onTitleChange = useCallback(
    (event) => updateStory({ properties: { title: event.target.value } }),
    [updateStory]
  );

  const onSave = useCallback(() => {
    if (isSaving) return;
    try {
      saveStory();
    } catch (_) {
      /* editor surfaces its own failure snackbar */
    }
  }, [isSaving, saveStory]);

  const onClose = useCallback(() => postToHost('CLOSE'), []);

  return (
    <div style={BAR}>
      <input
        type="text"
        style={TITLE_INPUT}
        value={title || ''}
        onChange={onTitleChange}
        placeholder="Başlıksız Hikaye"
        aria-label="Hikaye başlığı"
      />
      <PreviewButton />
      <button
        type="button"
        style={SAVE_BTN(isSaving)}
        onClick={onSave}
        disabled={isSaving}
      >
        {isSaving ? 'Kaydediliyor…' : 'Kaydet'}
      </button>
      <button
        type="button"
        style={CLOSE_BTN}
        onClick={onClose}
        title="Kapat"
        aria-label="Kapat"
      >
        ✕
      </button>
    </div>
  );
}
