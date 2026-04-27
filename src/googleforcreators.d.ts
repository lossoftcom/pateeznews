declare module '@googleforcreators/story-editor' {
  import type { ComponentType, ReactNode } from 'react';

  export const StoryEditor: ComponentType<{
    config?: any;
    initialEdits?: any;
    children?: ReactNode;
  }>;

  export const InterfaceSkeleton: ComponentType<any>;
}
