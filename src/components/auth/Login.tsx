import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { ArrowRight, Eye, EyeOff, Loader2, X } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useLanguage } from '@/context/LanguageContext';
import { accountAction } from '@/services/appActions';
import type { SiteSettings } from '@/types';
import RemixIcon from '@/components/ui/RemixIcon';

type AccountMode = 'signIn' | 'signUp';
type SocialProvider = 'google' | 'apple' | 'facebook' | 'x';
type AuthFieldName = 'identifier' | 'password' | 'fullName' | 'email' | 'city' | 'newPassword' | 'newPasswordAgain';
type AuthFieldErrors = Partial<Record<AuthFieldName, string>>;

type SocialAuthSettings = {
  googleEnabled: boolean;
  appleEnabled: boolean;
  facebookEnabled: boolean;
  xEnabled: boolean;
};

type AppAuthResult = {
  user?: unknown;
  session?: {
    access_token?: string;
    refresh_token?: string;
  } | null;
  profile?: unknown;
};

interface LoginProps {
  onSuccess: () => void;
  onClose?: () => void;
  siteSettings?: SiteSettings | null;
}

const DEFAULT_CITY = 'Niğde';
const DEFAULT_LOGO_URL = '/local-upload/logo/tr/pateezlogoson.png';
const AUTH_API_PATH = '/api/app/auth';

const turkeyCities = [
  'Adana',
  'Adıyaman',
  'Afyonkarahisar',
  'Ağrı',
  'Amasya',
  'Ankara',
  'Antalya',
  'Artvin',
  'Aydın',
  'Balıkesir',
  'Bilecik',
  'Bingöl',
  'Bitlis',
  'Bolu',
  'Burdur',
  'Bursa',
  'Çanakkale',
  'Çankırı',
  'Çorum',
  'Denizli',
  'Diyarbakır',
  'Edirne',
  'Elazığ',
  'Erzincan',
  'Erzurum',
  'Eskişehir',
  'Gaziantep',
  'Giresun',
  'Gümüşhane',
  'Hakkari',
  'Hatay',
  'Isparta',
  'Mersin',
  'İstanbul',
  'İzmir',
  'Kars',
  'Kastamonu',
  'Kayseri',
  'Kırklareli',
  'Kırşehir',
  'Kocaeli',
  'Konya',
  'Kütahya',
  'Malatya',
  'Manisa',
  'Kahramanmaraş',
  'Mardin',
  'Muğla',
  'Muş',
  'Nevşehir',
  'Niğde',
  'Ordu',
  'Rize',
  'Sakarya',
  'Samsun',
  'Siirt',
  'Sinop',
  'Sivas',
  'Tekirdağ',
  'Tokat',
  'Trabzon',
  'Tunceli',
  'Şanlıurfa',
  'Uşak',
  'Van',
  'Yozgat',
  'Zonguldak',
  'Aksaray',
  'Bayburt',
  'Karaman',
  'Kırıkkale',
  'Batman',
  'Şırnak',
  'Bartın',
  'Ardahan',
  'Iğdır',
  'Yalova',
  'Karabük',
  'Kilis',
  'Osmaniye',
  'Düzce',
];

const cleanMessage = (value: unknown, fallback: string) => {
  const message = String(value || '').trim();
  if (!message) return fallback;
  return message === 'Invalid login credentials' ? 'Geçersiz giriş bilgileri' : message;
};

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const looksLikeEmailAddress = (value: string) => EMAIL_PATTERN.test(value.trim().toLowerCase());

const hasFieldErrors = (errors: AuthFieldErrors) => Object.values(errors).some(Boolean);

const fieldForAuthError = (message: string, mode: AccountMode): AuthFieldName | null => {
  const normalized = message.toLocaleLowerCase('tr-TR');
  if (normalized.includes('e-posta') || normalized.includes('email')) return mode === 'signUp' ? 'email' : 'identifier';
  if (normalized.includes('eşleş') || normalized.includes('şifreler')) return mode === 'signUp' ? 'newPasswordAgain' : 'password';
  if (normalized.includes('şifre') || normalized.includes('password')) return mode === 'signUp' ? 'newPassword' : 'password';
  if (normalized.includes('geçersiz giriş') || normalized.includes('giriş bilgileri') || normalized.includes('invalid login')) return 'password';
  if (normalized.includes('ad soyad')) return 'fullName';
  if (normalized.includes('şehir')) return 'city';
  return null;
};

const socialAuthFromSiteSettings = (settings?: SiteSettings | null): SocialAuthSettings => ({
  googleEnabled: settings?.social_auth_google_enabled !== false,
  appleEnabled: settings?.social_auth_apple_enabled !== false,
  facebookEnabled: settings?.social_auth_facebook_enabled !== false,
  xEnabled: settings?.social_auth_x_enabled !== false,
});

const providerLabel = (provider: SocialProvider, mode: AccountMode) => {
  const action = mode === 'signUp' ? 'kayıt ol' : 'giriş';
  if (provider === 'google') return `Google ile ${action}`;
  if (provider === 'apple') return `Apple ile ${action}`;
  if (provider === 'facebook') return `Facebook ile ${action}`;
  return `X ile ${action}`;
};

const providerIcon = (provider: SocialProvider) => {
  if (provider === 'google') return <RemixIcon name="ri-google-fill" size={18} className="text-[#EA4335]" />;
  if (provider === 'apple') return <RemixIcon name="ri-apple-fill" size={19} className="text-black" />;
  if (provider === 'facebook') return <RemixIcon name="ri-facebook-circle-fill" size={19} className="text-black" />;
  return <RemixIcon name="ri-twitter-x-fill" size={18} className="text-black" />;
};

async function appAuthRequest(body: Record<string, unknown>): Promise<AppAuthResult> {
  const response = await fetch(AUTH_API_PATH, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify(body),
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok || result?.error) {
    throw new Error(cleanMessage(result?.error?.message, 'İşlem tamamlanamadı'));
  }
  return (result?.data || {}) as AppAuthResult;
}

async function applySupabaseSession(session: AppAuthResult['session']) {
  const accessToken = String(session?.access_token || '').trim();
  const refreshToken = String(session?.refresh_token || '').trim();
  if (!accessToken || !refreshToken) {
    throw new Error('Giriş oturumu alınamadı');
  }
  const { error } = await supabase.auth.setSession({
    access_token: accessToken,
    refresh_token: refreshToken,
  });
  if (error) throw error;
}

const Login: React.FC<LoginProps> = ({ onSuccess, onClose, siteSettings }) => {
  const { currentLang } = useLanguage();
  const [mode, setMode] = useState<AccountMode>('signIn');
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newPasswordAgain, setNewPasswordAgain] = useState('');
  const [city, setCity] = useState(DEFAULT_CITY);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<AuthFieldErrors>({});
  const [showPassword, setShowPassword] = useState(false);
  const [showPasswordAgain, setShowPasswordAgain] = useState(false);
  const [shellSocialAuth, setShellSocialAuth] = useState<SocialAuthSettings | null>(null);
  const [shellLogoUrl, setShellLogoUrl] = useState('');
  const [logoFailed, setLogoFailed] = useState(false);

  const siteSocialAuth = useMemo(() => socialAuthFromSiteSettings(siteSettings), [siteSettings]);
  const socialAuth = shellSocialAuth || siteSocialAuth;
  const isSignUp = mode === 'signUp';
  const logoUrl = (
    String(siteSettings?.logo_url || '').trim() ||
    shellLogoUrl ||
    String(siteSettings?.dark_logo_url || '').trim() ||
    DEFAULT_LOGO_URL
  );
  const siteName = String(siteSettings?.site_name || 'Pateez').trim() || 'Pateez';

  useEffect(() => {
    setLogoFailed(false);
  }, [logoUrl]);

  useEffect(() => {
    let cancelled = false;
    const lang = encodeURIComponent(currentLang?.code || 'tr');
    fetch(`/api/app/shell?lang=${lang}`, { headers: { Accept: 'application/json' } })
      .then((response) => (response.ok ? response.json() : null))
      .then((payload) => {
        if (cancelled || !payload?.siteSettings) return;
        const settings = payload.siteSettings;
        const auth = settings.socialAuth || {};
        setShellLogoUrl(String(settings.logoUrl || '').trim());
        setShellSocialAuth({
          googleEnabled: auth.googleEnabled !== false,
          appleEnabled: auth.appleEnabled !== false,
          facebookEnabled: auth.facebookEnabled !== false,
          xEnabled: auth.xEnabled !== false,
        });
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [currentLang?.code]);

  const handleKeyDown = useCallback((event: KeyboardEvent) => {
    if (event.key === 'Escape') onClose?.();
  }, [onClose]);

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    const scrollbarWidth = window.innerWidth - document.documentElement.clientWidth;
    const navbar = document.querySelector('header') as HTMLElement | null;

    document.body.style.overflow = 'hidden';
    if (scrollbarWidth > 0) {
      document.body.style.paddingRight = `${scrollbarWidth}px`;
      if (navbar) navbar.style.paddingRight = `${scrollbarWidth}px`;
    }

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      document.body.style.overflow = '';
      document.body.style.paddingRight = '';
      if (navbar) navbar.style.paddingRight = '';
    };
  }, [handleKeyDown]);

  const setModeSafely = (nextMode: AccountMode) => {
    if (loading) return;
    setMode(nextMode);
    setError(null);
    setFieldErrors({});
  };

  const clearFieldError = (field: AuthFieldName) => {
    setFieldErrors((current) => {
      if (!current[field]) return current;
      const next = { ...current };
      delete next[field];
      return next;
    });
  };

  const validateSignInFields = (): AuthFieldErrors => {
    const nextErrors: AuthFieldErrors = {};
    const cleanIdentifier = identifier.trim();
    if (!password) {
      nextErrors.password = 'Şifre zorunlu';
    }
    if (!cleanIdentifier) {
      nextErrors.identifier = 'Kullanıcı adı veya e-posta zorunlu';
    } else if (!nextErrors.password && cleanIdentifier.includes('@') && !looksLikeEmailAddress(cleanIdentifier)) {
      nextErrors.identifier = 'Geçerli bir e-posta girin';
    }
    return nextErrors;
  };

  const validateSignUpFields = (): AuthFieldErrors => {
    const nextErrors: AuthFieldErrors = {};
    const cleanName = fullName.trim();
    const cleanEmail = email.trim();
    if (!cleanName) {
      nextErrors.fullName = 'Ad soyad zorunlu';
    }
    if (!cleanEmail) {
      nextErrors.email = 'E-posta zorunlu';
    } else if (!looksLikeEmailAddress(cleanEmail)) {
      nextErrors.email = 'Geçerli bir e-posta girin';
    }
    if (!city.trim()) {
      nextErrors.city = 'Şehir seçimi zorunlu';
    }
    if (!newPassword) {
      nextErrors.newPassword = 'Şifre zorunlu';
    }
    if (!newPasswordAgain) {
      nextErrors.newPasswordAgain = 'Şifre tekrarı zorunlu';
    } else if (newPassword && newPassword !== newPasswordAgain) {
      nextErrors.newPasswordAgain = 'Şifreler eşleşmiyor';
    }
    return nextErrors;
  };

  const handleAuth = async (event: React.FormEvent) => {
    event.preventDefault();
    if (loading) return;
    const validationErrors = isSignUp ? validateSignUpFields() : validateSignInFields();
    if (hasFieldErrors(validationErrors)) {
      setFieldErrors(validationErrors);
      setError(null);
      return;
    }
    setLoading(true);
    setError(null);
    setFieldErrors({});

    try {
      if (isSignUp) {
        const cleanName = fullName.trim();
        const cleanEmail = email.trim().toLowerCase();
        const data = await appAuthRequest({
          action: 'signUpWithPassword',
          fullName: cleanName,
          email: cleanEmail,
          password: newPassword,
          passwordAgain: newPasswordAgain,
          city,
        });
        await applySupabaseSession(data.session);
      } else {
        const cleanIdentifier = identifier.trim();
        const data = await appAuthRequest({
          action: 'signInWithPassword',
          identifier: cleanIdentifier,
          password,
        });
        await applySupabaseSession(data.session);
      }
      onSuccess();
    } catch (authError: any) {
      const message = cleanMessage(authError?.message, isSignUp ? 'Kayıt oluşturulamadı.' : 'Giriş yapılamadı.');
      const field = fieldForAuthError(message, mode);
      if (field) {
        setFieldErrors({ [field]: message });
        setError(null);
      } else {
        setFieldErrors({});
        setError(message);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleForgotPassword = async () => {
    const emailForReset = identifier.trim().toLowerCase();
    if (!emailForReset || !looksLikeEmailAddress(emailForReset)) {
      setFieldErrors({ identifier: 'Şifre sıfırlama için e-posta adresini yaz' });
      setError(null);
      return;
    }
    setLoading(true);
    setError(null);
    setFieldErrors({});
    try {
      await accountAction('request-password-reset', { email: emailForReset });
      setError('Şifre sıfırlama talebi alındı.');
    } catch (resetError: any) {
      setError(cleanMessage(resetError?.message, 'Şifre sıfırlama başlatılamadı.'));
    } finally {
      setLoading(false);
    }
  };

  const handleSocialAuth = async (provider: SocialProvider) => {
    if (loading) return;
    setLoading(true);
    setError(null);
    setFieldErrors({});
    try {
      const { error: oauthError } = await supabase.auth.signInWithOAuth({
        provider,
        options: {
          redirectTo: window.location.origin,
        },
      });
      if (oauthError) throw oauthError;
    } catch (socialError: any) {
      setError(cleanMessage(socialError?.message, 'Sosyal giriş başlatılamadı.'));
      setLoading(false);
    }
  };

  const providers = [
    socialAuth.googleEnabled ? 'google' : null,
    socialAuth.appleEnabled ? 'apple' : null,
    socialAuth.facebookEnabled ? 'facebook' : null,
    socialAuth.xEnabled ? 'x' : null,
  ].filter(Boolean) as SocialProvider[];

  return (
    <div className="fixed inset-0 z-[9999] flex items-stretch justify-center bg-white animate-backdrop-entry md:items-center md:bg-[#eef3f2]/80 md:p-4 md:backdrop-blur-[2px] motion-reduce:animate-none">
      <button
        type="button"
        aria-label="Kapat"
        className="absolute inset-0 hidden md:block"
        onClick={onClose}
      />

      <section
        role="dialog"
        aria-modal="true"
        aria-label={isSignUp ? 'Hesabını oluştur' : 'Hesabına giriş yap'}
        className="relative flex h-full w-full transform-gpu flex-col overflow-hidden bg-white text-[#172332] animate-modal-entry md:h-auto md:max-h-[92vh] md:max-w-[430px] md:overflow-visible md:rounded-[10px] md:shadow-[0_24px_80px_rgba(23,35,50,0.16)] md:ring-1 md:ring-[#dfe8eb] motion-reduce:animate-none"
      >
        <header className="relative flex h-[86px] shrink-0 items-center justify-center border-b border-[#edf1f2] bg-white px-8 md:h-[76px] md:rounded-t-[10px]">
          <div className="flex min-w-0 justify-center">
            {!logoFailed && logoUrl ? (
              <img
                src={logoUrl}
                alt={siteName}
                className="h-[38px] w-[154px] object-contain"
                decoding="async"
                onError={() => setLogoFailed(true)}
              />
            ) : (
              <span className="font-display text-[30px] font-black leading-none text-[#73787d]">
                pateez
              </span>
            )}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="absolute right-3 top-3 z-20 flex h-9 w-9 items-center justify-center rounded-full border border-[#e6ecef] bg-[#f8fafb] text-[#314257] shadow-[0_8px_24px_rgba(23,35,50,0.08)] transition hover:border-[#d9e2e7] hover:bg-white focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e8eff3] md:-right-5 md:-top-5 md:h-10 md:w-10"
            aria-label="Kapat"
          >
            <X size={18} strokeWidth={2.2} />
          </button>
        </header>

        <div className="min-h-0 flex-1 overflow-y-auto px-8 py-8 md:px-10 md:py-7">
          <div className="mx-auto flex min-h-full max-w-[352px] flex-col justify-center">
            <form onSubmit={handleAuth} noValidate className="space-y-3">
              <div className="pb-1 text-center text-[20px] font-[900] leading-none text-[#172332] md:text-[21px]">
                {isSignUp ? 'Kayıt Ol' : 'Giriş Yap'}
              </div>

              {providers.length > 0 && (
                <>
                  <div className="grid grid-cols-1 gap-2 min-[420px]:grid-cols-2 md:grid-cols-2">
                    {providers.map((provider) => (
                      <button
                        key={provider}
                        type="button"
                        disabled={loading}
                        onClick={() => void handleSocialAuth(provider)}
                        className="flex h-[46px] min-w-0 items-center justify-center gap-1.5 rounded-[4px] border border-[#e2e9ed] bg-white px-2 text-[12px] font-[800] text-[#263545] transition hover:border-[#d2dde3] hover:bg-[#fbfcfd] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e8eff3] disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        <span className="flex w-[18px] justify-center">{providerIcon(provider)}</span>
                        <span className="whitespace-nowrap">{providerLabel(provider, mode)}</span>
                      </button>
                    ))}
                  </div>

                  <div className="flex items-center gap-3 py-1">
                    <span className="h-px flex-1 bg-[#edf1f2]" />
                    <span className="text-[11px] font-medium text-[#9aa6af]">veya</span>
                    <span className="h-px flex-1 bg-[#edf1f2]" />
                  </div>
                </>
              )}

              {isSignUp ? (
                <>
                  <TextInput
                    ariaLabel="Ad soyad"
                    icon="ri-user-3-fill"
                    value={fullName}
                    onChange={(value) => {
                      setFullName(value);
                      clearFieldError('fullName');
                    }}
                    placeholder="Ad soyad"
                    autoComplete="name"
                    disabled={loading}
                    error={fieldErrors.fullName}
                  />
                  <TextInput
                    ariaLabel="E-posta"
                    icon="ri-at-line"
                    value={email}
                    onChange={(value) => {
                      setEmail(value);
                      clearFieldError('email');
                    }}
                    placeholder="E-posta"
                    type="email"
                    autoComplete="email"
                    disabled={loading}
                    error={fieldErrors.email}
                  />
                  <CitySelect
                    value={city}
                    onChange={(value) => {
                      setCity(value);
                      clearFieldError('city');
                    }}
                    disabled={loading}
                    error={fieldErrors.city}
                  />
                  <div className="grid grid-cols-2 gap-2">
                    <PasswordInput
                      value={newPassword}
                      onChange={(value) => {
                        setNewPassword(value);
                        clearFieldError('newPassword');
                        clearFieldError('newPasswordAgain');
                      }}
                      placeholder="Şifre"
                      autoComplete="new-password"
                      disabled={loading}
                      showPassword={showPassword}
                      onTogglePassword={() => setShowPassword((value) => !value)}
                      error={fieldErrors.newPassword}
                      compact
                    />
                    <PasswordInput
                      value={newPasswordAgain}
                      onChange={(value) => {
                        setNewPasswordAgain(value);
                        clearFieldError('newPasswordAgain');
                      }}
                      placeholder="Şifre tekrar"
                      autoComplete="new-password"
                      disabled={loading}
                      showPassword={showPasswordAgain}
                      onTogglePassword={() => setShowPasswordAgain((value) => !value)}
                      error={fieldErrors.newPasswordAgain}
                      compact
                    />
                  </div>
                </>
              ) : (
                <>
                  <TextInput
                    ariaLabel="Kullanıcı adı veya e-posta"
                    icon="ri-at-line"
                    value={identifier}
                    onChange={(value) => {
                      setIdentifier(value);
                      clearFieldError('identifier');
                    }}
                    placeholder="Kullanıcı adı veya e-posta"
                    autoComplete="username"
                    disabled={loading}
                    error={fieldErrors.identifier}
                  />
                  <PasswordInput
                    value={password}
                    onChange={(value) => {
                      setPassword(value);
                      clearFieldError('password');
                    }}
                    placeholder="Şifre"
                    autoComplete="current-password"
                    disabled={loading}
                    showPassword={showPassword}
                    onTogglePassword={() => setShowPassword((value) => !value)}
                    error={fieldErrors.password}
                  />
                  <div className="flex justify-end">
                    <button
                      type="button"
                      onClick={handleForgotPassword}
                      disabled={loading}
                      className="text-[11.5px] font-[800] text-[#314257] transition hover:text-[#f54138] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e8eff3] disabled:opacity-60"
                    >
                      Şifremi unuttum
                    </button>
                  </div>
                </>
              )}

              {error && (
                <p className="rounded-[4px] border border-[#ffd7d4] bg-[#fff4f3] px-3 py-2 text-[11.5px] font-[800] leading-snug text-[#e23d35]">
                  {error}
                </p>
              )}

              <button
                type="submit"
                disabled={loading}
                className="mt-2 flex h-12 w-full items-center justify-center gap-2 rounded-[4px] bg-[#f54138] px-5 text-[14px] font-[800] text-white shadow-[0_12px_24px_rgba(245,65,56,0.18)] transition hover:bg-[#ec352d] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#ffc9c5] active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-75"
              >
                {loading ? (
                  <>
                    <Loader2 size={17} className="animate-spin" />
                    <span>{isSignUp ? 'Bekleniyor' : 'Giriş yapılıyor'}</span>
                  </>
                ) : (
                  <>
                    <span>{isSignUp ? 'Kayıt ol' : 'Giriş yap'}</span>
                    <ArrowRight size={18} strokeWidth={2.4} />
                  </>
                )}
              </button>

              <button
                type="button"
                disabled={loading}
                onClick={() => setModeSafely(isSignUp ? 'signIn' : 'signUp')}
                className="flex w-full justify-center px-4 py-3 text-[13.5px] font-[800] text-[#f54138] transition hover:text-[#df2f28] focus:outline-none disabled:opacity-60"
              >
                {isSignUp ? 'Giriş yap' : 'Üye ol'}
              </button>
            </form>
          </div>
        </div>
      </section>
    </div>
  );
};

interface TextInputProps {
  ariaLabel: string;
  icon: string;
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  disabled: boolean;
  type?: string;
  autoComplete?: string;
  error?: string;
}

const TextInput: React.FC<TextInputProps> = ({
  ariaLabel,
  icon,
  value,
  onChange,
  placeholder,
  disabled,
  type = 'text',
  autoComplete,
  error,
}) => {
  const hasError = Boolean(error);
  return (
    <label className="block">
      <span className="sr-only">{ariaLabel}</span>
      <span className="relative block">
        <span className="pointer-events-none absolute left-4 top-1/2 flex -translate-y-1/2 text-[#9aa6af]">
          <RemixIcon name={icon} size={18} />
        </span>
        <input
          type={type}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder={placeholder}
          autoComplete={autoComplete}
          disabled={disabled}
          aria-invalid={hasError}
          className={`h-[47px] w-full rounded-[4px] border bg-white pl-[50px] pr-4 text-[14px] font-[700] text-[#263545] outline-none transition placeholder:text-[#9aa6af] disabled:cursor-not-allowed disabled:bg-[#fbfcfd] ${hasError ? 'border-[#f54138] focus:border-[#f54138] focus:ring-2 focus:ring-[#ffe1df]' : 'border-[#e8eef1] focus:border-[#cfdde4] focus:ring-2 focus:ring-[#e8eff3]'}`}
        />
      </span>
      {error && (
        <span className="mt-1.5 block break-words text-[11px] font-[800] leading-snug text-[#f54138]">
          {error}
        </span>
      )}
    </label>
  );
};

interface PasswordInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  autoComplete: string;
  disabled: boolean;
  showPassword: boolean;
  onTogglePassword: () => void;
  error?: string;
  compact?: boolean;
}

const PasswordInput: React.FC<PasswordInputProps> = ({
  value,
  onChange,
  placeholder,
  autoComplete,
  disabled,
  showPassword,
  onTogglePassword,
  error,
  compact = false,
}) => {
  const hasError = Boolean(error);
  return (
    <label className="block">
      <span className="sr-only">{placeholder}</span>
      <span className="relative block">
        <span className={`pointer-events-none absolute ${compact ? 'left-3' : 'left-4'} top-1/2 flex -translate-y-1/2 text-[#9aa6af]`}>
          <RemixIcon name="ri-lock-line" size={18} />
        </span>
        <input
          type={showPassword ? 'text' : 'password'}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder={placeholder}
          autoComplete={autoComplete}
          disabled={disabled}
          aria-invalid={hasError}
          className={`h-[47px] w-full rounded-[4px] border bg-white ${compact ? 'pl-[42px] pr-10 text-[13px]' : 'pl-[50px] pr-12 text-[14px]'} font-[700] text-[#263545] outline-none transition placeholder:text-[#9aa6af] disabled:cursor-not-allowed disabled:bg-[#fbfcfd] ${hasError ? 'border-[#f54138] focus:border-[#f54138] focus:ring-2 focus:ring-[#ffe1df]' : 'border-[#e8eef1] focus:border-[#cfdde4] focus:ring-2 focus:ring-[#e8eff3]'}`}
        />
        <button
          type="button"
          onClick={onTogglePassword}
          disabled={disabled}
          className={`absolute ${compact ? 'right-1.5' : 'right-3'} top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full text-[#8c9aa4] transition hover:bg-[#f4f7f8] hover:text-[#314257] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e8eff3] disabled:cursor-not-allowed disabled:opacity-60`}
          aria-label={showPassword ? 'Şifreyi gizle' : 'Şifreyi göster'}
        >
          {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
        </button>
      </span>
      {error && (
        <span className="mt-1.5 block break-words text-[11px] font-[800] leading-snug text-[#f54138]">
          {error}
        </span>
      )}
    </label>
  );
};

interface CitySelectProps {
  value: string;
  onChange: (value: string) => void;
  disabled: boolean;
  error?: string;
}

const CitySelect: React.FC<CitySelectProps> = ({ value, onChange, disabled, error }) => {
  const hasError = Boolean(error);
  return (
    <label className="block">
      <span className="relative block">
        <span className="absolute -top-[7px] left-[50px] z-10 bg-white px-1 text-[10px] font-[600] leading-none text-[#8b98a2]">
          Şehir
        </span>
        <span className="pointer-events-none absolute left-4 top-1/2 flex -translate-y-1/2 text-[#9aa6af]">
          <RemixIcon name="ri-map-pin-2-fill" size={18} />
        </span>
        <select
          value={value}
          onChange={(event) => onChange(event.target.value)}
          disabled={disabled}
          aria-invalid={hasError}
          className={`h-[47px] w-full appearance-none rounded-[4px] border bg-white pl-[50px] pr-12 text-[14px] font-[800] text-[#263545] outline-none transition disabled:cursor-not-allowed disabled:bg-[#fbfcfd] ${hasError ? 'border-[#f54138] focus:border-[#f54138] focus:ring-2 focus:ring-[#ffe1df]' : 'border-[#e8eef1] focus:border-[#cfdde4] focus:ring-2 focus:ring-[#e8eff3]'}`}
        >
          {turkeyCities.map((item) => (
            <option key={item} value={item}>
              {item}
            </option>
          ))}
        </select>
        <span className="pointer-events-none absolute right-4 top-1/2 flex -translate-y-1/2 text-[#9aa6af]">
          <RemixIcon name="ri-arrow-down-s-line" size={18} />
        </span>
      </span>
      {error && (
        <span className="mt-1.5 block break-words text-[11px] font-[800] leading-snug text-[#f54138]">
          {error}
        </span>
      )}
    </label>
  );
};

export default Login;
