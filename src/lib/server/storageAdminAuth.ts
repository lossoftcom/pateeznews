import { requireAdminRequest } from './adminAuth';
import type { StorageType } from './supabaseStorage';

export function storagePermissionForType(type: StorageType | null | undefined) {
  if (type === 'logo') return 'settings_access';
  if (type === 'profile') return 'users_access';
  return 'manage_content';
}

export function requireStorageAdminRequest(
  request: Request,
  type: StorageType | null | undefined,
) {
  return requireAdminRequest(request, storagePermissionForType(type));
}
