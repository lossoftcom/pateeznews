import React, { useCallback, useEffect, useMemo, useState } from 'react';
import styled from 'styled-components';
import { __, sprintf, _n } from '@googleforcreators/i18n';
import { trackEvent } from '@googleforcreators/tracking';
import {
  Button,
  ButtonVariant,
  ButtonType,
  ButtonSize,
  Icons,
  Text,
  TextSize,
} from '@googleforcreators/design-system';
import { useStory } from '@googleforcreators/story-editor';
import { LOCAL_MEDIA_TYPE_ALL } from '@googleforcreators/story-editor/dist-module/app/media/local/types.js';
import useConfig from '@googleforcreators/story-editor/dist-module/app/config/useConfig.js';
import useLocalMedia from '@googleforcreators/story-editor/dist-module/app/media/local/useLocalMedia.js';
import MediaUploadButton from '@googleforcreators/story-editor/dist-module/components/form/mediaUploadButton.js';
import {
  StyledPane,
  PaneInner,
  PaneHeader,
  SearchInputContainer,
  MediaGalleryMessage,
} from '@googleforcreators/story-editor/dist-module/components/library/panes/media/common/styles.js';
import PaginatedMediaGallery from '@googleforcreators/story-editor/dist-module/components/library/panes/media/common/paginatedMediaGallery.js';
import { PANE_PADDING } from '@googleforcreators/story-editor/dist-module/components/library/panes/shared/index.js';
import { focusStyle } from '@googleforcreators/story-editor/dist-module/components/panels/shared/styles.js';
import Tooltip from '@googleforcreators/story-editor/dist-module/components/tooltip/tooltip.js';
import useOnMediaSelect from '@googleforcreators/story-editor/dist-module/components/library/panes/media/local/useOnMediaSelect.js';
import paneId from '@googleforcreators/story-editor/dist-module/components/library/panes/media/local/paneId.js';
import VideoOptimizationDialog from '@googleforcreators/story-editor/dist-module/components/library/panes/media/local/videoOptimizationDialog.js';
import Hotlink from '@googleforcreators/story-editor/dist-module/components/library/panes/media/local/hotlink/hotlink.js';
import MediaRecording from '@googleforcreators/story-editor/dist-module/components/library/panes/media/local/mediaRecording/mediaRecording.js';
import SearchInput from '@googleforcreators/story-editor/dist-module/components/library/common/searchInput.js';

import MediaPickerButtons from './MediaPickerButtons.jsx';

const UploadButton = styled(Button)`
  ${({ theme }) => focusStyle(theme.colors.border.focus, theme.colors.bg.secondary)};
`;

const FilterArea = styled.div`
  display: flex;
  justify-content: space-between;
  gap: 8px;
  margin-top: 24px;
  padding: 0 ${PANE_PADDING} 0 ${PANE_PADDING};
`;

const SearchCount = styled(Text.Paragraph).attrs({ size: TextSize.Medium })`
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
`;

const ButtonsWrapper = styled.div`
  display: flex;
  flex: 0 0 auto;
  justify-content: flex-end;
  gap: 6px;
`;

const MediaTypeTabs = styled.div`
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 6px;
  padding: 12px ${PANE_PADDING} 0 ${PANE_PADDING};
`;

const MediaTypeTab = styled.button`
  min-width: 0;
  height: 28px;
  border: 1px solid
    ${({ $active, theme }) =>
      $active ? theme.colors.border.focus : theme.colors.border.defaultNormal};
  border-radius: 999px;
  background: ${({ $active, theme }) =>
    $active ? theme.colors.interactiveBg.primaryNormal : theme.colors.bg.secondary};
  color: ${({ $active, theme }) =>
    $active ? theme.colors.fg.primary : theme.colors.fg.secondary};
  cursor: pointer;
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
  padding: 0 8px;
  text-align: center;

  &:hover,
  &:focus {
    border-color: ${({ theme }) => theme.colors.border.focus};
    color: ${({ theme }) => theme.colors.fg.primary};
  }
`;

const AudioGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  flex: ${({ $standalone }) => ($standalone ? '1 1 auto' : '0 0 auto')};
  min-height: ${({ $standalone }) => ($standalone ? '100px' : '0')};
  max-height: ${({ $standalone }) => ($standalone ? 'none' : '190px')};
  overflow-y: auto;
  padding: 0 ${PANE_PADDING} 14px ${PANE_PADDING};
`;

const AudioTile = styled.button`
  min-width: 0;
  min-height: 88px;
  border: 1px solid ${({ theme }) => theme.colors.border.defaultNormal};
  border-radius: 4px;
  background: ${({ theme }) => theme.colors.bg.secondary};
  color: ${({ theme }) => theme.colors.fg.primary};
  cursor: pointer;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 7px;
  padding: 10px;
  text-align: left;

  &:hover,
  &:focus {
    border-color: ${({ theme }) => theme.colors.border.focus};
  }
`;

const AudioBadge = styled.span`
  align-self: flex-start;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.08);
  color: ${({ theme }) => theme.colors.fg.secondary};
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
  padding: 5px 7px;
`;

const AudioName = styled.span`
  color: ${({ theme }) => theme.colors.fg.primary};
  font-size: 12px;
  font-weight: 700;
  line-height: 1.25;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
`;

const MEDIA_TYPE_FILTERS = [
  { value: LOCAL_MEDIA_TYPE_ALL, label: 'T\u00fcm\u00fc' },
  { value: 'image', label: 'Resim' },
  { value: 'video', label: 'Video' },
  { value: 'audio', label: 'Ses' },
];

function mergeResources(pinned, media) {
  const seen = new Set();
  return [...pinned, ...media].filter((resource) => {
    if (!resource || !resource.id || seen.has(resource.id)) return false;
    seen.add(resource.id);
    return true;
  });
}

function resourceName(resource) {
  const value = resource.alt || resource.title || resource.src || '';
  const raw = value.split('?')[0].split('/').filter(Boolean).pop() || value;
  try {
    return decodeURIComponent(raw);
  } catch (_) {
    return raw;
  }
}

function isVisualResource(resource) {
  return resource.type === 'image' || resource.type === 'video' || resource.type === 'gif';
}

function normalizeMediaType(mediaType) {
  return mediaType && mediaType !== LOCAL_MEDIA_TYPE_ALL
    ? mediaType
    : LOCAL_MEDIA_TYPE_ALL;
}

function resourceFilterType(resource) {
  if (resource.type === 'audio') return 'audio';
  if (resource.type === 'video') return 'video';
  return 'image';
}

function resourceMatchesType(resource, mediaType) {
  const normalized = normalizeMediaType(mediaType);
  return normalized === LOCAL_MEDIA_TYPE_ALL || resourceFilterType(resource) === normalized;
}

function resourceMatchesSearch(resource, searchTerm) {
  const term = String(searchTerm || '').trim().toLowerCase();
  if (!term) return true;
  return String(resource.alt || resource.title || resource.src || resourceName(resource))
    .toLowerCase()
    .includes(term);
}

function MediaTypeFilter({ activeType, onChange }) {
  return (
    <MediaTypeTabs aria-label="Medya turu filtresi">
      {MEDIA_TYPE_FILTERS.map(({ value, label }) => {
        const active = activeType === value;
        return (
          <MediaTypeTab
            key={value}
            type="button"
            $active={active}
            aria-pressed={active}
            onClick={() => onChange(value)}
          >
            {label}
          </MediaTypeTab>
        );
      })}
    </MediaTypeTabs>
  );
}

function AudioResources({ resources, onSelect, standalone = false }) {
  if (!resources.length) return null;
  return (
    <AudioGrid $standalone={standalone}>
      {resources.map((resource) => (
        <AudioTile
          key={resource.id}
          type="button"
          title={resourceName(resource)}
          onClick={() => onSelect(resource)}
        >
          <AudioBadge>Ses</AudioBadge>
          <AudioName>{resourceName(resource)}</AudioName>
        </AudioTile>
      ))}
    </AudioGrid>
  );
}

export default function CustomMediaPane(props) {
  const {
    hasMore,
    media,
    uploadingMedia,
    isMediaLoading,
    isMediaLoaded,
    mediaType,
    searchTerm,
    setNextPage,
    setMediaType,
    setSearchTerm,
    totalItems,
  } = useLocalMedia(
    ({
      state: {
        hasMore,
        media,
        uploadingMedia,
        isMediaLoading,
        isMediaLoaded,
        mediaType,
        searchTerm,
        totalItems,
      },
      actions: { setNextPage, setMediaType, setSearchTerm },
    }) => ({
      hasMore,
      media,
      uploadingMedia: !media.length && isMediaLoading ? [] : uploadingMedia,
      isMediaLoading,
      isMediaLoaded,
      mediaType,
      searchTerm,
      totalItems,
      setNextPage,
      setMediaType,
      setSearchTerm,
    })
  );
  const {
    capabilities: { hasUploadMediaAction },
  } = useConfig();
  const [pinnedMedia, setPinnedMedia] = useState([]);
  const hasSearchTerm = searchTerm.length > 0;
  const activeMediaType = normalizeMediaType(mediaType);
  const visiblePinnedMedia = useMemo(
    () =>
      pinnedMedia.filter(
        (resource) =>
          resourceMatchesType(resource, activeMediaType) &&
          resourceMatchesSearch(resource, searchTerm)
      ),
    [activeMediaType, pinnedMedia, searchTerm]
  );
  const allMedia = useMemo(
    () => mergeResources(visiblePinnedMedia, media),
    [media, visiblePinnedMedia]
  );
  const visualMedia = useMemo(
    () => allMedia.filter(isVisualResource),
    [allMedia]
  );
  const audioMedia = useMemo(
    () => allMedia.filter((resource) => resource.type === 'audio'),
    [allMedia]
  );
  const uploadingVisualMedia = useMemo(
    () => uploadingMedia.filter(isVisualResource),
    [uploadingMedia]
  );
  const { onSelect, insertMediaElement } = useOnMediaSelect();
  const updateCurrentPageProperties = useStory(
    ({ actions }) => actions.updateCurrentPageProperties
  );
  const resultCount = allMedia.length;

  useEffect(() => {
    if (searchTerm.length > 0) {
      trackEvent('search', {
        search_type: 'media',
        search_term: searchTerm,
        search_filter: mediaType,
      });
    }
  }, [searchTerm, mediaType]);

  const pinResource = useCallback((resource) => {
    if (!resource) return;
    setPinnedMedia((current) => [
      resource,
      ...current.filter((item) => item.id !== resource.id),
    ]);
  }, []);

  const handleMediaTypeChange = useCallback(
    (nextMediaType) => {
      if (nextMediaType === activeMediaType) return;
      setMediaType({ mediaType: nextMediaType });
    },
    [activeMediaType, setMediaType]
  );

  const handlePickedResource = useCallback(
    (resource) => {
      pinResource(resource);
      if (activeMediaType !== LOCAL_MEDIA_TYPE_ALL) {
        const nextMediaType = resourceFilterType(resource);
        if (nextMediaType !== activeMediaType) {
          setMediaType({ mediaType: nextMediaType });
        }
      }
    },
    [activeMediaType, pinResource, setMediaType]
  );

  const handleUploadInsert = useCallback(
    (resource, insertUrl) => {
      handlePickedResource(resource);
      onSelect(resource, insertUrl);
    },
    [handlePickedResource, onSelect]
  );

  const handleAudioSelect = useCallback(
    (resource) => {
      updateCurrentPageProperties({
        properties: { backgroundAudio: { resource, loop: false, tracks: [] } },
      });
    },
    [updateCurrentPageProperties]
  );

  const renderUploadButton = useCallback(
    (onClick) => (
      <UploadButton
        variant={ButtonVariant.Square}
        type={ButtonType.Secondary}
        size={ButtonSize.Small}
        onClick={onClick}
        aria-label={__('Upload', 'web-stories')}
      >
        <Icons.ArrowCloud />
      </UploadButton>
    ),
    []
  );

  const showVisualGallery =
    !isMediaLoaded || visualMedia.length > 0 || uploadingVisualMedia.length > 0;
  const showEmpty =
    isMediaLoaded &&
    visualMedia.length === 0 &&
    audioMedia.length === 0 &&
    uploadingVisualMedia.length === 0;

  return (
    <StyledPane id={paneId} {...props}>
      <PaneInner>
        <PaneHeader>
          <SearchInputContainer>
            <SearchInput
              initialValue={searchTerm}
              placeholder={__('Search', 'web-stories')}
              onSearch={(value) => {
                const next = value.trim();
                if (next !== searchTerm) setSearchTerm({ searchTerm: next });
              }}
            />
          </SearchInputContainer>
          <FilterArea>
            <MediaPickerButtons
              placement="sidebar"
              onPickedResource={handlePickedResource}
            />
            {hasSearchTerm && allMedia.length > 0 && (
              <SearchCount>
                {sprintf(
                  _n(
                    '%s result found.',
                    '%s results found.',
                    resultCount,
                    'web-stories'
                  ),
                  resultCount
                )}
              </SearchCount>
            )}
            {!hasSearchTerm && (
              <ButtonsWrapper>
                <MediaRecording />
                <Hotlink />
                {hasUploadMediaAction && (
                  <Tooltip title={__('Upload', 'web-stories')}>
                    <MediaUploadButton
                      renderButton={renderUploadButton}
                      onInsert={handleUploadInsert}
                    />
                  </Tooltip>
                )}
              </ButtonsWrapper>
            )}
          </FilterArea>
          <MediaTypeFilter
            activeType={activeMediaType}
            onChange={handleMediaTypeChange}
          />
        </PaneHeader>
        {showVisualGallery && (
          <PaginatedMediaGallery
            providerType="local"
            canEditMedia={hasUploadMediaAction}
            resources={visualMedia}
            uploadingResources={uploadingVisualMedia}
            isMediaLoading={isMediaLoading}
            isMediaLoaded={isMediaLoaded}
            hasMore={hasMore}
            onInsert={insertMediaElement}
            setNextPage={setNextPage}
            searchTerm={searchTerm}
          />
        )}
        <AudioResources
          resources={audioMedia}
          onSelect={handleAudioSelect}
          standalone={!showVisualGallery}
        />
        {showEmpty && (
          <MediaGalleryMessage>
            {__(hasSearchTerm ? 'No results found.' : 'No media found.', 'web-stories')}
          </MediaGalleryMessage>
        )}
        <VideoOptimizationDialog />
      </PaneInner>
    </StyledPane>
  );
}
