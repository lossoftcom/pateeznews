import React from 'react';

interface AdminErrorBoundaryProps {
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

interface AdminErrorBoundaryState {
  hasError: boolean;
}

class AdminErrorBoundary extends React.Component<AdminErrorBoundaryProps, AdminErrorBoundaryState> {
  state: AdminErrorBoundaryState = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: unknown, info: unknown) {
    console.error('[AdminErrorBoundary] Caught error:', error, info);
  }

  render() {
    if (!this.state.hasError) return this.props.children;
    return this.props.fallback || null;
  }
}

export default AdminErrorBoundary;

