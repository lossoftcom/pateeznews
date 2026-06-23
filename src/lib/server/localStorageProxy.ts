const LOCAL_STORAGE_ORIGIN =
  process.env.PATEEZ_LOCAL_STORAGE_ORIGIN || 'http://127.0.0.1:4322';

function localStorageUrl(path: string) {
  return new URL(path, LOCAL_STORAGE_ORIGIN);
}

export async function listLocalStorageFiles(type: string) {
  const url = localStorageUrl('/api/local-storage/list');
  url.searchParams.set('type', type);
  const response = await fetch(url);
  if (!response.ok) throw new Error(await response.text());
  return response.json();
}

export async function uploadLocalStorageFile(formData: FormData) {
  const response = await fetch(localStorageUrl('/api/local-storage/upload'), {
    method: 'POST',
    body: formData,
  });
  const text = await response.text();
  let data: Record<string, any> | null = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      const preview = text.length > 180 ? `${text.slice(0, 177)}...` : text;
      throw new Error(`Local storage upload returned invalid response: ${preview}`);
    }
  }
  if (!response.ok) {
    throw new Error(data?.error || text || 'Local storage upload failed');
  }
  if (!data) {
    throw new Error('Local storage upload returned empty response');
  }
  return data;
}

export async function readLocalStorageFile(input: { type: string; id: string }) {
  const url = localStorageUrl('/api/local-storage/file');
  url.searchParams.set('type', input.type);
  url.searchParams.set('id', input.id);
  const response = await fetch(url);
  const body = new Uint8Array(await response.arrayBuffer());
  if (!response.ok) {
    const text = new TextDecoder().decode(body);
    let message = text || 'Local storage file read failed';
    try {
      const data = JSON.parse(text);
      message = data?.error || message;
    } catch {}
    throw new Error(message);
  }
  return {
    body,
    contentType: response.headers.get('content-type') || '',
  };
}

export async function resolveLocalStorageVideoThumb(body: unknown) {
  const response = await fetch(localStorageUrl('/api/local-storage/video-thumb'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(data?.error || text || 'Local video thumbnail failed');
  }
  return data;
}

export async function renameLocalStorageFile(body: unknown) {
  const response = await fetch(localStorageUrl('/api/local-storage/rename'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(data?.error || text || 'Local storage rename failed');
  }
  return data;
}

export async function deleteLocalStorageFile(body: unknown) {
  const response = await fetch(localStorageUrl('/api/local-storage/delete'), {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(data?.error || text || 'Local storage delete failed');
  }
  return data;
}
