// Bridge between the embedded Google Web Stories editor and its Flutter host.
//
// Two transports are supported, mirroring the posta_builder (LOSPOSTA_*) bridge
// but on an isolated PATEEZ_WS_* namespace:
//   - native (flutter_inappwebview): window.flutter_inappwebview.callHandler +
//     window.__pateezWsReceive(rawJson)
//   - web (iframe): window.parent.postMessage / window 'message' events
//
// On top of the original fire-and-forget messaging we add a small
// request/response layer (hostRequest) so the editor can ask the host to do
// work that returns a value (media list/upload, save acknowledgement).

export const HOST_SOURCE = 'PATEEZ_WS_HOST'; // messages coming FROM the host
export const EDITOR_SOURCE = 'PATEEZ_WS_EDITOR'; // messages going TO the host
const NATIVE_HANDLER = 'PateezWebStories'; // flutter_inappwebview JS handler
const HOST_EVENT = 'pateez-ws-host'; // internal CustomEvent re-broadcast

export function isNativeHost() {
  return typeof window !== 'undefined' && Boolean(window.flutter_inappwebview);
}

// Fire-and-forget message to the host.
export function postToHost(type, extra) {
  const message = { source: EDITOR_SOURCE, ...(extra || {}), type };
  try {
    if (isNativeHost()) {
      window.flutter_inappwebview.callHandler(NATIVE_HANDLER, message);
    } else if (window.parent && window.parent !== window) {
      window.parent.postMessage(message, '*');
    }
  } catch (_) {
    /* no-op: the host may have detached */
  }
}

// Install a single host->editor receiver (web postMessage + native
// __pateezWsReceive) that re-broadcasts as a CustomEvent so multiple listeners
// can react to the same host messages on either transport.
let receiverInstalled = false;
export function installHostReceiver() {
  if (receiverInstalled || typeof window === 'undefined') return;
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

// Subscribe to a specific host message type. Returns an unsubscribe function.
export function onHostEvent(type, handler) {
  const listener = (event) => {
    if (event.detail && event.detail.type === type) handler(event.detail);
  };
  window.addEventListener(HOST_EVENT, listener);
  return () => window.removeEventListener(HOST_EVENT, listener);
}

let requestSeq = 0;

// Send a request to the host and resolve with the matching `${type}_RESULT`.
// Never rejects: on timeout it resolves with { ok: false, timeout: true } so
// callers can degrade gracefully instead of surfacing an unhandled rejection.
export function hostRequest(type, payload, { timeout = 30000 } = {}) {
  const requestId = `ws_${Date.now()}_${++requestSeq}`;
  const resultType = `${type}_RESULT`;
  return new Promise((resolve) => {
    let settled = false;
    const finish = (value) => {
      if (settled) return;
      settled = true;
      unsubscribe();
      clearTimeout(timer);
      resolve(value);
    };
    const unsubscribe = onHostEvent(resultType, (detail) => {
      if (detail.requestId === requestId) finish(detail);
    });
    const timer = setTimeout(() => finish({ ok: false, timeout: true }), timeout);
    postToHost(type, { requestId, ...(payload || {}) });
  });
}
