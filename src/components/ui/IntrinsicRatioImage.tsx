import React, { useCallback, useMemo, useState } from 'react';

type ImageFit = 'contain' | 'cover';

type RatioFrameProps = {
  src: string;
  width?: number | string;
  height?: number | string;
  className?: string;
  style?: React.CSSProperties;
  sizerClassName?: string;
  sizerLoading?: 'eager' | 'lazy';
  children: React.ReactNode;
  onRatioChange?: (width: number, height: number) => void;
};

type IntrinsicRatioImageProps = Omit<
  React.ImgHTMLAttributes<HTMLImageElement>,
  'src' | 'alt' | 'className' | 'style' | 'onLoad'
> & {
  src: string;
  alt: string;
  frameClassName?: string;
  frameStyle?: React.CSSProperties;
  imageClassName?: string;
  imageStyle?: React.CSSProperties;
  sizerClassName?: string;
  fit?: ImageFit;
  onLoad?: React.ReactEventHandler<HTMLImageElement>;
};

const validRatio = (width: number | string | undefined, height: number | string | undefined) => {
  const parsedWidth = Number(width || 0);
  const parsedHeight = Number(height || 0);
  if (
    !Number.isFinite(parsedWidth) ||
    !Number.isFinite(parsedHeight) ||
    parsedWidth <= 0 ||
    parsedHeight <= 0
  ) {
    return undefined;
  }
  return parsedWidth / parsedHeight;
};

export const IntrinsicRatioFrame: React.FC<RatioFrameProps> = ({
  src,
  width,
  height,
  className = '',
  style,
  sizerClassName = '',
  sizerLoading = 'eager',
  children,
  onRatioChange,
}) => {
  const [measuredRatio, setMeasuredRatio] = useState<number | undefined>(() => validRatio(width, height));

  const handleSizerLoad = useCallback<React.ReactEventHandler<HTMLImageElement>>((event) => {
    const image = event.currentTarget;
    const naturalWidth = image.naturalWidth;
    const naturalHeight = image.naturalHeight;
    if (naturalWidth <= 0 || naturalHeight <= 0) return;
    const nextRatio = naturalWidth / naturalHeight;
    setMeasuredRatio((current) => {
      if (current && Math.abs(current - nextRatio) < 0.001) return current;
      return nextRatio;
    });
    onRatioChange?.(naturalWidth, naturalHeight);
  }, [onRatioChange]);

  const frameStyle = useMemo<React.CSSProperties | undefined>(() => {
    if (!measuredRatio) return style;
    return { aspectRatio: measuredRatio, ...style };
  }, [measuredRatio, style]);

  return (
    <div className={`intrinsic-ratio-frame relative w-full overflow-hidden ${className}`.trim()} style={frameStyle}>
      <img
        src={src}
        alt=""
        aria-hidden="true"
        loading={sizerLoading}
        decoding="async"
        draggable={false}
        onLoad={handleSizerLoad}
        className={`intrinsic-ratio-sizer block w-full select-none ${sizerClassName}`.trim()}
        style={{
          height: 'auto',
          maxHeight: 'none',
          opacity: 0,
          pointerEvents: 'none',
          userSelect: 'none',
        }}
      />
      {children}
    </div>
  );
};

const IntrinsicRatioImage: React.FC<IntrinsicRatioImageProps> = ({
  src,
  alt,
  width,
  height,
  frameClassName = '',
  frameStyle,
  imageClassName = '',
  imageStyle,
  sizerClassName = '',
  fit = 'contain',
  loading = 'lazy',
  decoding = 'async',
  onLoad,
  ...imageProps
}) => {
  const objectFit = fit === 'cover' ? 'cover' : 'contain';

  return (
    <IntrinsicRatioFrame
      src={src}
      width={width}
      height={height}
      className={frameClassName}
      style={frameStyle}
      sizerClassName={sizerClassName}
      sizerLoading={loading === 'lazy' ? 'lazy' : 'eager'}
    >
      <img
        {...imageProps}
        src={src}
        alt={alt}
        width={width}
        height={height}
        loading={loading}
        decoding={decoding}
        draggable={imageProps.draggable}
        onLoad={onLoad}
        className={`intrinsic-ratio-image absolute inset-0 z-10 h-full w-full ${imageClassName}`.trim()}
        style={{
          objectFit,
          height: '100%',
          maxHeight: 'none',
          width: '100%',
          ...imageStyle,
        }}
      />
    </IntrinsicRatioFrame>
  );
};

export default IntrinsicRatioImage;
