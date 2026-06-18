import { navigate, transitionEnabledOnThisPage } from 'astro:transitions/client';

type NavigateOptions = {
  history?: 'auto' | 'push' | 'replace';
  info?: unknown;
  state?: Record<string, unknown>;
  formData?: FormData;
  sourceElement?: Element;
};

const isObjectState = (value: unknown): value is Record<string, unknown> => (
  !!value && typeof value === 'object'
);

const getHistoryIndex = (state: Record<string, unknown>) => (
  typeof state.index === 'number' ? state.index : 0
);

const writeUrlState = (href: string, historyMode: 'push' | 'replace' = 'push', extraState?: Record<string, unknown>) => {
  const currentState = isObjectState(window.history.state) ? window.history.state : {};
  const currentIndex = getHistoryIndex(currentState);
  if (historyMode === 'push') {
    window.history.replaceState({
      ...currentState,
      index: currentIndex,
      scrollX: window.scrollX,
      scrollY: window.scrollY,
    }, '', window.location.href);
  }

  const nextState = {
    ...extraState,
    index: historyMode === 'replace' ? currentIndex : currentIndex + 1,
    scrollX: historyMode === 'replace' && typeof currentState.scrollX === 'number' ? currentState.scrollX : 0,
    scrollY: historyMode === 'replace' && typeof currentState.scrollY === 'number' ? currentState.scrollY : 0,
  };

  if (historyMode === 'replace') {
    window.history.replaceState(nextState, '', href);
  } else {
    window.history.pushState(nextState, '', href);
  }

  return nextState;
};

const waitForAstroPageLoad = () => new Promise<void>((resolve) => {
  let timer = 0;
  const finish = () => {
    document.removeEventListener('astro:page-load', finish);
    window.clearTimeout(timer);
    resolve();
  };
  document.addEventListener('astro:page-load', finish, { once: true });
  timer = window.setTimeout(finish, 15000);
});

export const updateUrlImmediately = (
  href: string,
  historyMode: 'push' | 'replace' = 'push',
  extraState?: Record<string, unknown>
) => {
  if (typeof window === 'undefined') return null;
  const target = new URL(href, window.location.href);
  if (target.origin !== window.location.origin || target.href === window.location.href) return null;
  return writeUrlState(target.href, historyMode, extraState);
};

export const navigateImmediately = async (href: string, options: NavigateOptions = {}) => {
  if (typeof window === 'undefined') {
    return navigate(href, options);
  }

  const target = new URL(href, window.location.href);
  if (
    target.origin !== window.location.origin ||
    options.formData ||
    !transitionEnabledOnThisPage()
  ) {
    return navigate(target.href, options);
  }

  const current = new URL(window.location.href);
  const isSamePageHash = (
    target.pathname === current.pathname &&
    target.search === current.search &&
    target.hash !== current.hash
  );
  if (target.href === current.href || isSamePageHash) {
    return navigate(target.href, options);
  }

  document.getElementById('route-loading')?.classList.add('is-active');
  const historyMode = options.history === 'replace' ? 'replace' : 'push';
  const nextState = writeUrlState(target.href, historyMode, options.state);
  const completion = waitForAstroPageLoad();
  window.dispatchEvent(new PopStateEvent('popstate', { state: nextState }));
  return completion;
};
