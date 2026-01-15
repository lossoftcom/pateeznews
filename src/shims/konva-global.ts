import GlobalModule from 'konva/lib/Global';

const mod: any = (GlobalModule as any)?.default ?? GlobalModule;

export const Konva = mod?.Konva ?? mod;
export const glob = mod?.glob;
export const _registerNode = mod?._registerNode;

export default mod;
