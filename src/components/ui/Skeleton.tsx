import React from 'react';

interface SkeletonProps {
    className?: string;
    variant?: 'rectangular' | 'circular';
}

const Skeleton: React.FC<SkeletonProps> = ({ className = '', variant = 'rectangular' }) => {
    const baseClasses = "animate-pulse bg-palette-beige/20";
    const variantClasses = variant === 'circular' ? "rounded-full" : "rounded-[5px]";

    return (
        <div className={`${baseClasses} ${variantClasses} ${className}`} />
    );
};

export default Skeleton;
