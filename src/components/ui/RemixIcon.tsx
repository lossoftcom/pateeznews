import React from 'react';

interface RemixIconProps {
  name: string;
  size?: number | string;
  className?: string;
  style?: React.CSSProperties;
}

const RemixIcon: React.FC<RemixIconProps> = ({ name, size = 20, className = '', style }) => (
  <i
    className={`${name} inline-flex items-center justify-center leading-none ${className}`.trim()}
    aria-hidden="true"
    style={{ fontSize: size, lineHeight: 1, ...style }}
  />
);

export default RemixIcon;
