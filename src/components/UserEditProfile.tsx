
import React, { useState, useEffect, useRef } from 'react';
import { ArrowLeft, Camera, Check, ChevronDown, Eye, EyeOff, Globe, Link as LinkIcon, Save, Sparkles, User, Mail, MapPin, Briefcase, Calendar, Shield, Lock, Trash2, Smartphone } from 'lucide-react';
import { clearSupabaseAuthStorage, supabase } from '@/lib/supabase';
import { useLanguage } from '@/context/LanguageContext';
import { accountAction } from '@/services/appActions';
import RemixIcon from '@/components/ui/RemixIcon';

interface UserEditProfileProps {
  userId?: string;
  name: string;
  onBack: () => void;
}

type TabType = 'update_profile' | 'social_accounts' | 'preferences' | 'change_password' | 'delete_account';
type IdentityField = 'username' | 'email' | 'phone';

const emptyIdentityValidation = () => ({
  username: { checking: false, error: '' },
  email: { checking: false, error: '' },
  phone: { checking: false, error: '' },
});

const roleLabelFor = (role: unknown) => {
  const key = String(role || '').trim().toLowerCase();
  if (key === 'admin' || key === 'super_admin') return 'Yönetici';
  if (key === 'editor') return 'Editör';
  if (key === 'publisher') return 'Yayıncı';
  if (key === 'member' || key === 'user') return 'Üye';
  return '';
};

const TURKEY_CITY_OPTIONS = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin', 'Aydın',
  'Balıkesir', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı',
  'Çorum', 'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir',
  'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Isparta', 'Mersin', 'İstanbul',
  'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya',
  'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir',
  'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ',
  'Tokat', 'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak',
  'Aksaray', 'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan',
  'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce',
];

const MOBILE_SOCIAL_PLATFORMS = [
  'twitter', 'instagram', 'facebook', 'youtube', 'whatsapp', 'linkedin', 'tiktok',
  'pinterest', 'snapchat', 'telegram', 'discord', 'reddit', 'bluesky', 'twitch',
  'personal_website_url',
];

const MOBILE_SOCIAL_META: Record<string, { label: string; icon: string; color: string }> = {
  twitter: { label: 'X (Twitter)', icon: 'ri-twitter-x-fill', color: '#000000' },
  instagram: { label: 'Instagram', icon: 'ri-instagram-fill', color: '#E4405F' },
  facebook: { label: 'Facebook', icon: 'ri-facebook-fill', color: '#1877F2' },
  youtube: { label: 'YouTube', icon: 'ri-youtube-fill', color: '#FF0000' },
  whatsapp: { label: 'WhatsApp', icon: 'ri-whatsapp-fill', color: '#25D366' },
  linkedin: { label: 'LinkedIn', icon: 'ri-linkedin-fill', color: '#0A66C2' },
  tiktok: { label: 'TikTok', icon: 'ri-tiktok-fill', color: '#000000' },
  pinterest: { label: 'Pinterest', icon: 'ri-pinterest-fill', color: '#E60023' },
  snapchat: { label: 'Snapchat', icon: 'ri-snapchat-fill', color: '#FFC400' },
  telegram: { label: 'Telegram', icon: 'ri-telegram-fill', color: '#26A5E4' },
  discord: { label: 'Discord', icon: 'ri-discord-fill', color: '#5865F2' },
  reddit: { label: 'Reddit', icon: 'ri-reddit-fill', color: '#FF4500' },
  bluesky: { label: 'Bluesky', icon: 'ri-bluesky-fill', color: '#1185FE' },
  twitch: { label: 'Twitch', icon: 'ri-twitch-fill', color: '#9146FF' },
  personal_website_url: { label: 'Personal Website URL', icon: 'ri-global-line', color: '#8A949B' },
};

const identityConflictMessage: Record<IdentityField, string> = {
  username: 'Bu kullanıcı adı başka bir hesapta kullanılıyor.',
  email: 'Bu e-posta başka bir hesapta kullanılıyor.',
  phone: 'Bu telefon başka bir hesapta kullanılıyor.',
};

const usernameFormatError = (username: string) => {
  const clean = username.trim().replace(/^@+/, '');
  if (!clean) return '';
  if (clean.length < 3 || /\s/.test(clean)) {
    return 'Kullanıcı adı en az 3 karakter olmalı ve boşluk içermemeli.';
  }
  return '';
};

const emailFormatError = (email: string) => {
  const clean = email.trim();
  if (!clean) return '';
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(clean) ? '' : 'Geçerli bir e-posta girin.';
};

const UserEditProfile: React.FC<UserEditProfileProps> = ({ userId, name, onBack }) => {
  const { t } = useLanguage();
  const [activeTab, setActiveTab] = useState<TabType>('update_profile');
  const avatarInputRef = useRef<HTMLInputElement>(null);
  const coverInputRef = useRef<HTMLInputElement>(null);
  const prefColumnsRef = useRef<{ show_email: boolean; rss_feeds: boolean }>({ show_email: false, rss_feeds: false });

  const [formData, setFormData] = useState<any>({
    full_name: '',
    username: '',
    email: '',
    phone: '',
    about_me: '',
    expertise: '',
    foundation_date: '',
    address: '',
    website: '',
    slug: '',
    social_links: {},
    reward_system: false,
    meta_title: '',
    meta_keywords: '',
    meta_description: '',
    canonical_url: '',
    avatar_url: '',
    cover_url: '',
    role: '',
    role_label: '',
    city: '',
    show_email: true,
    rss_feeds: true
  });

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saveStatus, setSaveStatus] = useState<'idle' | 'success'>('idle');
  const [uploadingImage, setUploadingImage] = useState<'avatar' | 'cover' | null>(null);
  const [passwords, setPasswords] = useState({ current: '', next: '', confirm: '' });
  const [visiblePasswords, setVisiblePasswords] = useState({ current: false, next: false, confirm: false });
  const [deletePassword, setDeletePassword] = useState('');
  const [formMessage, setFormMessage] = useState<string | null>(null);
  const [identityValidation, setIdentityValidation] = useState<ReturnType<typeof emptyIdentityValidation>>(emptyIdentityValidation);
  const validationRequestRef = useRef(0);

  const normalizeProfileMediaUrl = (input: any): string => {
    if (!input) return '';
    const url = String(input).trim();
    if (!url) return '';
    if (
      url.startsWith('http://') ||
      url.startsWith('https://') ||
      url.startsWith('data:') ||
      url.startsWith('/')
    ) {
      return url;
    }
    if (url.startsWith('api/storage/file/')) return `/${url}`;
    if (url.startsWith('profile/')) return `/api/storage/file/${url}`;
    return `/api/storage/file/profile/${url}`;
  };

  const authHeaders = async (): Promise<Record<string, string>> => {
    const { data: { session } } = await supabase.auth.getSession();
    return session?.access_token ? { Authorization: `Bearer ${session.access_token}` } : {};
  };

  const checkProfileFields = async (payload: { username: string; email: string; phone: string }) => {
    const response = await fetch('/api/app/profile', {
      method: 'POST',
      headers: {
        ...(await authHeaders()),
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        action: 'check-profile-fields',
        username: payload.username,
        email: payload.email,
        phone: payload.phone,
      }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || result?.error) {
      throw new Error(result?.error?.message || 'Profil alanları kontrol edilemedi');
    }
    return {
      username: result?.conflicts?.username === true,
      email: result?.conflicts?.email === true,
      phone: result?.conflicts?.phone === true,
    };
  };

  const fieldError = (field: IdentityField) => {
    const state = identityValidation[field];
    if (state.error) {
      return <p className="mt-1 text-[11px] font-semibold text-palette-red">{state.error}</p>;
    }
    if (state.checking) {
      return <p className="mt-1 text-[11px] font-semibold text-gray-400">Kontrol ediliyor...</p>;
    }
    return null;
  };

  useEffect(() => {
    if (!userId) return;

    const fetchProfile = async () => {
      setLoading(true);
      try {
        await accountAction('ensure-schema').catch(() => null);
        const { data, error } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();

        if (error) throw error;
        if (data) {
          prefColumnsRef.current = {
            show_email: Object.prototype.hasOwnProperty.call(data, 'show_email'),
            rss_feeds: Object.prototype.hasOwnProperty.call(data, 'rss_feeds')
          };
          const socialLinks = typeof data.social_links === 'string' ? JSON.parse(data.social_links) : (data.social_links || {});
          setFormData({
            full_name: data.full_name || '',
            username: data.username || '',
            email: data.email || '',
            phone: data.phone || '',
            about_me: data.about_me || '',
            expertise: data.expertise || '',
            foundation_date: data.foundation_date || '',
            address: data.address || '',
            website: data.website || '',
            slug: data.slug || '',
            social_links: socialLinks,
            reward_system: data.reward_system || false,
            meta_title: data.meta_title || '',
            meta_keywords: data.meta_keywords || '',
            meta_description: data.meta_description || '',
            canonical_url: data.canonical_url || '',
            avatar_url: normalizeProfileMediaUrl(data.avatar_url),
            cover_url: normalizeProfileMediaUrl(data.cover_url || socialLinks.cover_url),
            role: data.role || '',
            role_label: roleLabelFor(data.role) || data.expertise || '',
            city: data.city || '',
            show_email: data.show_email !== undefined ? data.show_email : true,
            rss_feeds: data.rss_feeds !== undefined ? data.rss_feeds : true
          });
        }
      } catch (err) {
        console.error('Error fetching profile:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchProfile();
  }, [userId]);

  useEffect(() => {
    setFormMessage(null);
  }, [activeTab]);

  useEffect(() => {
    if (!userId || loading) return;

    const username = String(formData.username || '').trim().replace(/^@+/, '');
    const email = String(formData.email || '').trim().toLowerCase();
    const phone = String(formData.phone || '').trim();
    const usernameError = usernameFormatError(username);
    const emailError = emailFormatError(email);

    setIdentityValidation({
      username: { checking: false, error: usernameError },
      email: { checking: false, error: emailError },
      phone: { checking: false, error: '' },
    });

    if (usernameError || emailError || (!username && !email && !phone)) return;

    const requestId = validationRequestRef.current + 1;
    validationRequestRef.current = requestId;
    const timer = window.setTimeout(async () => {
      setIdentityValidation((prev) => ({
        username: { ...prev.username, checking: Boolean(username) },
        email: { ...prev.email, checking: Boolean(email) },
        phone: { ...prev.phone, checking: Boolean(phone) },
      }));
      try {
        const conflicts = await checkProfileFields({ username, email, phone });
        if (validationRequestRef.current !== requestId) return;
        setIdentityValidation({
          username: { checking: false, error: conflicts.username ? identityConflictMessage.username : '' },
          email: { checking: false, error: conflicts.email ? identityConflictMessage.email : '' },
          phone: { checking: false, error: conflicts.phone ? identityConflictMessage.phone : '' },
        });
      } catch (error) {
        if (validationRequestRef.current !== requestId) return;
        setIdentityValidation((prev) => ({
          username: { ...prev.username, checking: false },
          email: { ...prev.email, checking: false },
          phone: { ...prev.phone, checking: false },
        }));
      }
    }, 350);

    return () => window.clearTimeout(timer);
  }, [formData.email, formData.phone, formData.username, loading, userId]);

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>, type: 'avatar' | 'cover') => {
    const file = e.target.files?.[0];
    if (!file || !userId) return;

    setUploadingImage(type);
    try {
      const uploadFormData = new FormData();
      uploadFormData.set('file', file);
      uploadFormData.set('kind', type);
      uploadFormData.set('languageCode', 'tr');
      const response = await fetch('/api/app/profile-upload', {
        method: 'POST',
        headers: await authHeaders(),
        body: uploadFormData,
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok || result?.error) {
        throw new Error(result?.error?.message || 'Görsel yüklenemedi');
      }

      const finalUrl = normalizeProfileMediaUrl(result.publicSrc || result.src);
      if (!finalUrl) throw new Error('Görsel yolu alınamadı');

      if (type === 'avatar') {
        setFormData((prev: any) => ({ ...prev, avatar_url: finalUrl }));
      } else {
        setFormData((prev: any) => ({ ...prev, cover_url: finalUrl }));
      }
    } catch (err) {
      console.error(`Error uploading ${type}:`, err);
    } finally {
      setUploadingImage(null);
    }
  };

  const handleSave = async () => {
    if (!userId) return;
    setSaving(true);
    setFormMessage(null);

    try {
      const baseSocialLinks =
        ((typeof formData.social_links === 'string' ? JSON.parse(formData.social_links) : formData.social_links) || {});
      const { cover_url: _legacyCoverUrl, ...cleanSocialLinks } = baseSocialLinks;
      const username = String(formData.username || '').trim().replace(/^@+/, '');
      const email = String(formData.email || '').trim().toLowerCase();
      const phone = String(formData.phone || '').trim();
      const formatErrors = {
        username: usernameFormatError(username),
        email: emailFormatError(email),
        phone: '',
      };
      if (formatErrors.username || formatErrors.email) {
        setIdentityValidation({
          username: { checking: false, error: formatErrors.username },
          email: { checking: false, error: formatErrors.email },
          phone: { checking: false, error: '' },
        });
        return;
      }
      const conflicts = await checkProfileFields({ username, email, phone });
      const nextValidation = {
        username: { checking: false, error: conflicts.username ? identityConflictMessage.username : '' },
        email: { checking: false, error: conflicts.email ? identityConflictMessage.email : '' },
        phone: { checking: false, error: conflicts.phone ? identityConflictMessage.phone : '' },
      };
      setIdentityValidation(nextValidation);
      if (nextValidation.username.error || nextValidation.email.error || nextValidation.phone.error) {
        return;
      }

      const updatePayload: Record<string, any> = {
        full_name: formData.full_name,
        username,
        email,
        phone,
        about_me: formData.about_me,
        foundation_date: formData.foundation_date,
        address: formData.address,
        website: formData.website,
        slug: formData.slug,
        social_links: cleanSocialLinks,
        reward_system: formData.reward_system,
        meta_title: formData.meta_title,
        meta_keywords: formData.meta_keywords,
        meta_description: formData.meta_description,
        canonical_url: formData.canonical_url,
        avatar_url: normalizeProfileMediaUrl(formData.avatar_url),
        cover_url: normalizeProfileMediaUrl(formData.cover_url),
        city: formData.city || 'Niğde',
        updated_at: new Date().toISOString()
      };

      if (prefColumnsRef.current.show_email) updatePayload.show_email = formData.show_email;
      if (prefColumnsRef.current.rss_feeds) updatePayload.rss_feeds = formData.rss_feeds;

      const { error } = await supabase
        .from('profiles')
        .update(updatePayload)
        .eq('id', userId);

      if (error) throw error;

      setSaveStatus('success');
      setTimeout(() => setSaveStatus('idle'), 1000);
    } catch (err) {
      console.error('Error saving profile:', err);
    } finally {
      setSaving(false);
    }
  };

  const handleUpdatePassword = async () => {
    if (!passwords.current || !passwords.next || passwords.next !== passwords.confirm) {
      setFormMessage(t('profile.passwords_not_match'));
      return;
    }

    setSaving(true);
    setFormMessage(null);
    try {
      await accountAction('update-password', {
        currentPassword: passwords.current,
        newPassword: passwords.next,
      });
      setPasswords({ current: '', next: '', confirm: '' });
      setSaveStatus('success');
      setTimeout(() => setSaveStatus('idle'), 1200);
    } catch (error: any) {
      setFormMessage(error.message || t('common.action_failed'));
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteAccount = async () => {
    const confirmedPassword = deletePassword || window.prompt(t('profile.enter_password_confirm')) || '';
    if (!confirmedPassword) {
      setFormMessage(t('profile.enter_password_confirm'));
      return;
    }
    if (!window.confirm(t('profile.delete_confirm_title'))) return;

    setSaving(true);
    setFormMessage(null);
    try {
      await accountAction('delete-self', { currentPassword: confirmedPassword });
      await supabase.auth.signOut();
      clearSupabaseAuthStorage();
      window.location.href = '/';
    } catch (error: any) {
      setFormMessage(error.message || t('common.action_failed'));
    } finally {
      setSaving(false);
    }
  };

  const tabs = [
    { id: 'update_profile', label: t('profile.tab.info'), icon: <User size={18} /> },
    { id: 'social_accounts', label: t('profile.tab.social'), icon: <Globe size={18} /> },
    { id: 'preferences', label: t('profile.tab.preferences'), icon: <Shield size={18} /> },
    { id: 'change_password', label: t('profile.tab.password'), icon: <Lock size={18} /> },
    { id: 'delete_account', label: t('profile.tab.delete'), icon: <Trash2 size={18} /> }
  ];
  if (loading) return (
    <div className="flex justify-center items-center min-h-[400px]">
      <div className="animate-spin rounded-[5px] h-12 w-12 border-b-2 border-blue-600"></div>
    </div>
  );

  return (
    <>
      {/* Hidden Inputs */}
      <input
        type="file"
        ref={avatarInputRef}
        className="hidden"
        accept="image/*"
        onChange={(e) => handleImageUpload(e, 'avatar')}
      />
      <input
        type="file"
        ref={coverInputRef}
        className="hidden"
        accept="image/*"
        onChange={(e) => handleImageUpload(e, 'cover')}
      />

      <div className="profile-edit-mobile-shell">
        <header className="profile-edit-mobile-appbar">
          <button type="button" onClick={handleSave} disabled={saving}>
            {saving ? t('common.saving') : 'Kaydet'}
          </button>
          <strong>Profili Düzenle</strong>
          <button type="button" onClick={onBack} aria-label={t('admin.post.go_back')}>
            <ArrowLeft size={20} strokeWidth={2.2} />
          </button>
        </header>

        <main className="profile-edit-mobile-content">
          <section className="profile-edit-mobile-card">
            <h2><span aria-hidden="true" />Fotoğraflar</h2>
            <div className="profile-edit-mobile-cover">
              {formData.cover_url ? (
                <img src={formData.cover_url} alt={t('user_edit_profile.cover_alt')} loading="eager" decoding="async" />
              ) : (
                <div><Sparkles size={34} /></div>
              )}
              <button
                type="button"
                onClick={() => coverInputRef.current?.click()}
                disabled={uploadingImage === 'cover'}
              >
                <Camera size={14} />
                <span>{uploadingImage === 'cover' ? 'Yükleniyor' : 'Kapak'}</span>
              </button>
            </div>

            <div className="profile-edit-mobile-photo-row">
              <div className="profile-edit-mobile-avatar">
                {formData.avatar_url ? (
                  <img src={formData.avatar_url} alt={t('user_edit_profile.avatar_alt')} loading="eager" decoding="async" />
                ) : (
                  <User size={30} />
                )}
              </div>
              <div>
                <strong>Profil fotoğrafı</strong>
                <span>JPG veya PNG · en fazla 5 MB</span>
              </div>
              <button
                type="button"
                onClick={() => avatarInputRef.current?.click()}
                disabled={uploadingImage === 'avatar'}
              >
                <Camera size={14} />
                <span>{uploadingImage === 'avatar' ? 'Yükleniyor' : 'Değiştir'}</span>
              </button>
            </div>
          </section>

          <section className="profile-edit-mobile-card">
            <h2><span aria-hidden="true" />Hesap Bilgileri</h2>
            <label className="profile-edit-mobile-field">
              <span>Ad Soyad</span>
              <div>
                <User size={17} />
                <input
                  type="text"
                  value={formData.full_name}
                  onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
                />
              </div>
            </label>
            <label className="profile-edit-mobile-field">
              <span>Kullanıcı Adı</span>
              <div>
                <b>@</b>
                <input
                  type="text"
                  value={formData.username}
                  onChange={(e) => setFormData({ ...formData, username: e.target.value })}
                />
              </div>
              {fieldError('username')}
            </label>
            <label className="profile-edit-mobile-field">
              <span>E-posta</span>
              <div>
                <Mail size={17} />
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                />
              </div>
              {fieldError('email')}
            </label>
          </section>

          <section className="profile-edit-mobile-card">
            <h2><span aria-hidden="true" />Profil</h2>
            <label className="profile-edit-mobile-field">
              <span>Uzmanlık / Unvan</span>
              <div>
                <Sparkles size={17} />
                <input
                  type="text"
                  value={formData.role_label || roleLabelFor(formData.role) || formData.expertise}
                  readOnly
                  aria-readonly="true"
                />
              </div>
            </label>
            <label className="profile-edit-mobile-field">
              <span>Şehir</span>
              <div className="profile-edit-mobile-select-field">
                <MapPin size={17} />
                <select
                  value={formData.city || 'Niğde'}
                  onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                >
                  {TURKEY_CITY_OPTIONS.map((city) => (
                    <option key={city} value={city}>{city}</option>
                  ))}
                </select>
                <ChevronDown size={17} />
              </div>
            </label>
            <label className="profile-edit-mobile-field">
              <span>Hakkında</span>
              <div className="is-textarea">
                <Briefcase size={17} />
                <textarea
                  value={formData.about_me}
                  onChange={(e) => setFormData({ ...formData, about_me: e.target.value })}
                  rows={4}
                />
              </div>
            </label>
            <label className="profile-edit-mobile-field">
              <span>Adres</span>
              <div>
                <MapPin size={17} />
                <input
                  type="text"
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                />
              </div>
            </label>
          </section>

          <section className="profile-edit-mobile-card">
            <h2><span aria-hidden="true" />Sosyal Bağlantılar</h2>
            <div className="profile-edit-mobile-social-fields">
              {MOBILE_SOCIAL_PLATFORMS.map((platformKey) => {
                const meta = MOBILE_SOCIAL_META[platformKey];
                const value = platformKey === 'personal_website_url'
                  ? formData.website || ''
                  : formData.social_links[platformKey] || '';

                return (
                <label key={platformKey} className={`profile-edit-mobile-field${value ? ' has-value' : ''}`}>
                  <span>{meta.label}</span>
                  <div>
                    <RemixIcon name={meta.icon} size={18} style={{ color: meta.color }} />
                    <input
                      type="text"
                      placeholder={meta.label}
                      value={value}
                      onChange={(e) => {
                        if (platformKey === 'personal_website_url') {
                          setFormData({ ...formData, website: e.target.value });
                          return;
                        }
                        setFormData({
                          ...formData,
                          social_links: {
                            ...formData.social_links,
                            [platformKey]: e.target.value
                          }
                        });
                      }}
                    />
                  </div>
                </label>
                );
              })}
            </div>
          </section>

          <section className="profile-edit-mobile-card">
            <h2><span aria-hidden="true" />Tercihler</h2>
            <label className="profile-edit-mobile-toggle">
              <span>E-postamı profilimde göster</span>
              <input
                type="checkbox"
                checked={formData.show_email === true}
                onChange={(e) => setFormData({ ...formData, show_email: e.target.checked })}
              />
              <i aria-hidden="true" />
            </label>
            <label className="profile-edit-mobile-toggle">
              <span>RSS akışlarına izin ver</span>
              <input
                type="checkbox"
                checked={formData.rss_feeds === true}
                onChange={(e) => setFormData({ ...formData, rss_feeds: e.target.checked })}
              />
              <i aria-hidden="true" />
            </label>
          </section>

          <button
            type="button"
            className={`profile-edit-mobile-save${saveStatus === 'success' ? ' is-success' : ''}`}
            onClick={handleSave}
            disabled={saving}
          >
            {saving ? `${t('common.saving')}...` : saveStatus === 'success' ? t('profile.saved_success') : t('common.save_changes')}
          </button>

          <section className="profile-edit-mobile-card">
            <h2><span aria-hidden="true" />Şifre Değiştir</h2>
            {formMessage && (
              <p className="profile-edit-mobile-message">{formMessage}</p>
            )}
            <label className="profile-edit-mobile-field profile-edit-mobile-password-field">
              <div>
                <Lock size={17} />
                <input
                  type={visiblePasswords.current ? 'text' : 'password'}
                  value={passwords.current}
                  onChange={(e) => setPasswords({ ...passwords, current: e.target.value })}
                  placeholder={t('user_edit_profile.password.current')}
                />
                <button
                  type="button"
                  onClick={() => setVisiblePasswords((prev) => ({ ...prev, current: !prev.current }))}
                  aria-label={t('user_edit_profile.password.current')}
                >
                  {visiblePasswords.current ? <EyeOff size={17} /> : <Eye size={17} />}
                </button>
              </div>
            </label>
            <label className="profile-edit-mobile-field profile-edit-mobile-password-field">
              <div>
                <Lock size={17} />
                <input
                  type={visiblePasswords.next ? 'text' : 'password'}
                  value={passwords.next}
                  onChange={(e) => setPasswords({ ...passwords, next: e.target.value })}
                  placeholder={t('user_edit_profile.password.new')}
                />
                <button
                  type="button"
                  onClick={() => setVisiblePasswords((prev) => ({ ...prev, next: !prev.next }))}
                  aria-label={t('user_edit_profile.password.new')}
                >
                  {visiblePasswords.next ? <EyeOff size={17} /> : <Eye size={17} />}
                </button>
              </div>
            </label>
            <label className="profile-edit-mobile-field profile-edit-mobile-password-field">
              <div>
                <Lock size={17} />
                <input
                  type={visiblePasswords.confirm ? 'text' : 'password'}
                  value={passwords.confirm}
                  onChange={(e) => setPasswords({ ...passwords, confirm: e.target.value })}
                  placeholder={t('user_edit_profile.password.confirm')}
                />
                <button
                  type="button"
                  onClick={() => setVisiblePasswords((prev) => ({ ...prev, confirm: !prev.confirm }))}
                  aria-label={t('user_edit_profile.password.confirm')}
                >
                  {visiblePasswords.confirm ? <EyeOff size={17} /> : <Eye size={17} />}
                </button>
              </div>
            </label>
            <button type="button" className="profile-edit-mobile-secondary" onClick={handleUpdatePassword} disabled={saving}>
              <Lock size={17} />
              {t('profile.update_password')}
            </button>
          </section>

          <section className="profile-edit-mobile-danger">
            <h2>Tehlikeli Alan</h2>
            <p>Hesabını silersen profilin, gönderilerin ve tüm verilerin kalıcı olarak kaldırılır.</p>
            <button type="button" onClick={handleDeleteAccount} disabled={saving}>
              <Trash2 size={16} />
              Hesabı Sil
            </button>
          </section>
        </main>
      </div>

    <div className="profile-edit-desktop-shell animate-in bg-white rounded-[4px] border border-gray-200 shadow-sm overflow-hidden mb-10">

      {/* HEADER: Cover */}
      <div
        className="relative h-44 md:h-52 overflow-hidden bg-gray-100 group"
      >
        {formData.cover_url ? (
          <img src={formData.cover_url} className="w-full h-full object-cover" alt={t('user_edit_profile.cover_alt')} />
        ) : (
          <div className="w-full h-full bg-gray-200 flex items-center justify-center">
            <Sparkles className="text-gray-300" size={40} />
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-black/0 to-black/10" />

        <div className="absolute right-5 bottom-5 z-10">
          <button
            onClick={() => coverInputRef.current?.click()}
            disabled={uploadingImage === 'cover'}
            className="flex h-10 w-10 items-center justify-center rounded-full border border-white/35 bg-white/20 text-white shadow-sm backdrop-blur-md transition-all hover:bg-white/35 active:scale-95 disabled:cursor-wait"
            aria-label={t('publishers.change_cover')}
          >
            {uploadingImage === 'cover' ? (
              <div className="h-5 w-5 animate-spin rounded-full border-2 border-white/30 border-t-white" />
            ) : (
              <Camera size={18} />
            )}
          </button>
        </div>

        <div className="absolute top-4 left-4 right-4 flex justify-between items-start z-20">
          <button
            onClick={onBack}
            className="flex h-9 w-9 items-center justify-center rounded-[4px] border border-white/25 bg-white/75 text-gray-900 shadow-sm backdrop-blur-xl transition-all hover:bg-white active:scale-95"
            aria-label={t('admin.post.go_back')}
          >
            <ArrowLeft size={18} />
          </button>
        </div>
      </div>

      {/* PROFILE INFO AREA */}
      <div className="relative border-b border-gray-100 px-5 pb-6 md:px-7">
        <div className="absolute -top-10 left-5 z-10 h-[92px] w-[92px] overflow-hidden rounded-full border-[3px] border-white bg-gray-100 shadow-[0_10px_24px_rgba(15,23,42,0.14)] md:left-7 md:h-24 md:w-24">
          {formData.avatar_url ? (
            <img src={formData.avatar_url} className="w-full h-full object-cover" alt={t('user_edit_profile.avatar_alt')} />
          ) : (
            <div className="w-full h-full flex items-center justify-center bg-gray-50">
              <User className="text-gray-300" size={30} />
            </div>
          )}
          <button
            type="button"
            onClick={() => avatarInputRef.current?.click()}
            disabled={uploadingImage === 'avatar'}
            className="absolute bottom-0 right-0 flex h-8 w-8 items-center justify-center rounded-full border-2 border-white bg-gray-900/90 text-white shadow-sm transition-all hover:bg-gray-900 active:scale-95 disabled:cursor-wait"
            aria-label={t('user_edit_profile.avatar_alt')}
          >
            {uploadingImage === 'avatar' ? (
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
            ) : (
              <Camera size={15} className="text-white" />
            )}
          </button>
        </div>

        <div className="min-h-[104px] pt-14 md:min-h-[92px] md:pt-5 md:pl-[118px]">
          <div className="max-w-2xl">
            <h1 className="mb-1 truncate text-[22px] font-bold leading-tight text-gray-900 md:text-2xl">{formData.full_name || t('users.form.username')}</h1>
            <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1.5">
              <span className="text-sm font-semibold text-palette-accent">@{formData.username}</span>
              <span className="hidden h-1 w-1 rounded-full bg-gray-300 md:inline-block" />
              <span className="text-xs font-semibold text-gray-500">{formData.role_label || t('profile.settings_title')}</span>
            </div>
          </div>
        </div>
      </div>

      <div className="flex flex-col md:flex-row min-h-[500px]">
        {/* Left Sidebar Tabs */}
        <div className="w-full md:w-64 bg-gray-50/50 border-r border-gray-100 p-4">
          <div className="flex flex-col gap-1">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as TabType)}
                className={`flex items-center gap-3 px-4 py-3.5 rounded-[5px] text-[13px] font-bold transition-all ${activeTab === tab.id
                  ? 'bg-white text-blue-600 shadow-sm border border-gray-100'
                  : 'text-gray-500 hover:bg-gray-100 hover:text-gray-900'
                  }`}
              >
                <span className={activeTab === tab.id ? 'text-blue-600' : 'text-gray-400'}>
                  {tab.icon}
                </span>
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {/* Right Content Form */}
        <div className="flex-1 p-6 md:p-10">
          <div className="animate-in fade-in duration-500">

            {activeTab === 'update_profile' && (
              <div className="space-y-8">
                <div>
                  <h2 className="text-lg font-black text-gray-900 mb-1">{t('profile.tab.info')}</h2>
                  <p className="text-xs text-gray-500 font-semibold tracking-normal">{t('user_edit_profile.section.update_profile_subtitle')}</p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-1.5">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('users.form.full_name')}</label>
                    <div className="relative">
                      <User className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                      <input
                        type="text"
                        value={formData.full_name}
                        onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
                        className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold focus:bg-white focus:border-blue-500 outline-none transition-all"
                      />
                    </div>
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('users.form.username')}</label>
                    <div className="relative">
                      <span className="absolute left-4 top-1/2 -translate-y-1/2 text-blue-500 font-black">@</span>
                      <input
                        type="text"
                        value={formData.username}
                        onChange={(e) => setFormData({ ...formData, username: e.target.value })}
                        className={`w-full pl-11 pr-4 py-3 bg-gray-50 border rounded-[5px] text-sm font-bold focus:bg-white outline-none transition-all ${identityValidation.username.error ? 'border-palette-red focus:border-palette-red' : 'border-gray-100 focus:border-blue-500'}`}
                      />
                    </div>
                    {fieldError('username')}
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('publishers.form.email')}</label>
                    <div className="relative">
                      <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                      <input
                        type="email"
                        value={formData.email}
                        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                        className={`w-full pl-11 pr-4 py-3 bg-gray-50 border rounded-[5px] text-sm font-bold focus:bg-white outline-none transition-all ${identityValidation.email.error ? 'border-palette-red focus:border-palette-red' : 'border-gray-100 focus:border-blue-500'}`}
                      />
                    </div>
                    {fieldError('email')}
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('profile.phone')}</label>
                    <div className="relative">
                      <Smartphone className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                      <input
                        type="text"
                        value={formData.phone}
                        onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                        className={`w-full pl-11 pr-4 py-3 bg-gray-50 border rounded-[5px] text-sm font-bold focus:bg-white outline-none transition-all ${identityValidation.phone.error ? 'border-palette-red focus:border-palette-red' : 'border-gray-100 focus:border-blue-500'}`}
                      />
                    </div>
                    {fieldError('phone')}
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('profile.expertise')}</label>
                    <div className="relative">
                      <Briefcase className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                      <input
                        type="text"
                        value={formData.role_label || roleLabelFor(formData.role) || formData.expertise}
                        readOnly
                        aria-readonly="true"
                        className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold text-gray-500 outline-none cursor-not-allowed"
                      />
                    </div>
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('profile.foundation_date')}</label>
                    <div className="relative">
                      <Calendar className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                      <input
                        type="text"
                        value={formData.foundation_date}
                        onChange={(e) => setFormData({ ...formData, foundation_date: e.target.value })}
                        className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold focus:bg-white focus:border-blue-500 outline-none transition-all"
                      />
                    </div>
                  </div>

                  <div className="space-y-1.5 md:col-span-2">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('profile.address')}</label>
                    <div className="relative">
                      <MapPin className="absolute left-4 top-4 text-gray-400" size={16} />
                      <textarea
                        value={formData.address}
                        onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                        rows={2}
                        className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold focus:bg-white focus:border-blue-500 outline-none transition-all resize-none"
                      />
                    </div>
                  </div>

                  <div className="space-y-1.5 md:col-span-2">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('profile.website')}</label>
                    <div className="relative">
                      <Globe className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                      <input
                        type="text"
                        value={formData.website}
                        onChange={(e) => setFormData({ ...formData, website: e.target.value })}
                        className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold focus:bg-white focus:border-blue-500 outline-none transition-all"
                      />
                    </div>
                  </div>

                  <div className="space-y-1.5 md:col-span-2">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('profile.about_me')}</label>
                    <textarea
                      value={formData.about_me}
                      onChange={(e) => setFormData({ ...formData, about_me: e.target.value })}
                      rows={4}
                      className="w-full p-4 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold focus:bg-white focus:border-blue-500 outline-none transition-all resize-none"
                    />
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'social_accounts' && (
              <div className="space-y-8">
                <div>
                  <h2 className="text-lg font-black text-gray-900 mb-1">{t('profile.tab.social')}</h2>
                  <p className="text-xs text-gray-500 font-semibold tracking-normal">{t('user_edit_profile.section.social_subtitle')}</p>
                </div>

                <div className="space-y-4">
                  {[
                    'facebook', 'twitter', 'instagram', 'tiktok', 'whatsapp',
                    'youtube', 'discord', 'telegram', 'pinterest', 'linkedin',
                    'twitch', 'vk', 'nsosyal', 'personal_website_url'
                  ].map((platformKey) => (
                    <div key={platformKey} className="space-y-1.5">
                      <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t(`user_edit_profile.platform.${platformKey}`)}</label>
                      <div className="relative">
                        <LinkIcon className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                        <input
                          type="text"
                          placeholder={t('user_edit_profile.social_placeholder').replace('{platform}', t(`user_edit_profile.platform.${platformKey}`))}
                          value={formData.social_links[platformKey] || ''}
                          onChange={(e) => setFormData({
                            ...formData,
                            social_links: {
                              ...formData.social_links,
                              [platformKey]: e.target.value
                            }
                          })}
                          className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold focus:bg-white focus:border-blue-500 outline-none transition-all"
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {activeTab === 'preferences' && (
              <div className="space-y-12">
                <div>
                  <h2 className="text-lg font-black text-gray-900 mb-1">{t('profile.tab.preferences')}</h2>
                  <p className="text-xs text-gray-500 font-semibold tracking-normal">{t('profile.account_preferences')}</p>
                </div>

                <div className="space-y-10">
                  <div className="space-y-4">
                    <label className="text-[13px] font-black text-gray-900 tracking-tight">{t('profile.show_email_on_profile')}</label>
                    <div className="flex items-center gap-12">
                      <label className="flex items-center gap-2 cursor-pointer group">
                        <div className="relative flex items-center justify-center">
                          <input
                            type="radio"
                            name="show_email"
                            checked={formData.show_email === true}
                            onChange={() => setFormData({ ...formData, show_email: true })}
                            className="peer appearance-none w-5 h-5 border-2 border-gray-300 rounded-full checked:border-blue-600 transition-all"
                          />
                          <div className="absolute w-2.5 h-2.5 bg-blue-600 rounded-full opacity-0 peer-checked:opacity-100 transition-all" />
                        </div>
                        <span className="text-sm font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('common.yes')}</span>
                      </label>
                      <label className="flex items-center gap-2 cursor-pointer group">
                        <div className="relative flex items-center justify-center">
                          <input
                            type="radio"
                            name="show_email"
                            checked={formData.show_email === false}
                            onChange={() => setFormData({ ...formData, show_email: false })}
                            className="peer appearance-none w-5 h-5 border-2 border-gray-300 rounded-full checked:border-blue-600 transition-all"
                          />
                          <div className="absolute w-2.5 h-2.5 bg-blue-600 rounded-full opacity-0 peer-checked:opacity-100 transition-all" />
                        </div>
                        <span className="text-sm font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('common.no')}</span>
                      </label>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <label className="text-[13px] font-black text-gray-900 tracking-tight">{t('profile.rss_feeds')}</label>
                    <div className="flex items-center gap-12">
                      <label className="flex items-center gap-2 cursor-pointer group">
                        <div className="relative flex items-center justify-center">
                          <input
                            type="radio"
                            name="rss_feeds"
                            checked={formData.rss_feeds === true}
                            onChange={() => setFormData({ ...formData, rss_feeds: true })}
                            className="peer appearance-none w-5 h-5 border-2 border-gray-300 rounded-full checked:border-blue-600 transition-all"
                          />
                          <div className="absolute w-2.5 h-2.5 bg-blue-600 rounded-full opacity-0 peer-checked:opacity-100 transition-all" />
                        </div>
                        <span className="text-sm font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('common.yes')}</span>
                      </label>
                      <label className="flex items-center gap-2 cursor-pointer group">
                        <div className="relative flex items-center justify-center">
                          <input
                            type="radio"
                            name="rss_feeds"
                            checked={formData.rss_feeds === false}
                            onChange={() => setFormData({ ...formData, rss_feeds: false })}
                            className="peer appearance-none w-5 h-5 border-2 border-gray-300 rounded-full checked:border-blue-600 transition-all"
                          />
                          <div className="absolute w-2.5 h-2.5 bg-blue-600 rounded-full opacity-0 peer-checked:opacity-100 transition-all" />
                        </div>
                        <span className="text-sm font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('common.no')}</span>
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'change_password' && (
              <div className="space-y-8">
                <div>
                  <h2 className="text-lg font-black text-gray-900 mb-1">{t('profile.tab.password')}</h2>
                  <p className="text-xs text-gray-500 font-semibold tracking-normal">{t('user_edit_profile.section.password_subtitle')}</p>
                </div>

                <div className="space-y-4 max-w-sm">
                  {formMessage && (
                    <div className="px-4 py-3 rounded-[5px] bg-palette-red/5 border border-palette-red/20 text-[12px] font-bold text-palette-red">
                      {formMessage}
                    </div>
                  )}
                  <div className="space-y-1.5">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('user_edit_profile.password.current')}</label>
                    <input type="password" value={passwords.current} onChange={(e) => setPasswords({ ...passwords, current: e.target.value })} placeholder="••••••••" className="w-full px-4 py-3 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold focus:bg-white focus:border-blue-500 outline-none transition-all" />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('user_edit_profile.password.new')}</label>
                    <input type="password" value={passwords.next} onChange={(e) => setPasswords({ ...passwords, next: e.target.value })} placeholder="••••••••" className="w-full px-4 py-3 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold focus:bg-white focus:border-blue-500 outline-none transition-all" />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-[11px] font-bold text-gray-500 tracking-normal">{t('user_edit_profile.password.confirm')}</label>
                    <input type="password" value={passwords.confirm} onChange={(e) => setPasswords({ ...passwords, confirm: e.target.value })} placeholder="••••••••" className="w-full px-4 py-3 bg-gray-50 border border-gray-100 rounded-[5px] text-sm font-bold focus:bg-white focus:border-blue-500 outline-none transition-all" />
                  </div>
                  <button onClick={handleUpdatePassword} disabled={saving} className="w-full py-3 bg-gray-900 text-white rounded-[5px] text-[12px] font-bold tracking-normal hover:bg-blue-600 transition-all shadow-md active:scale-95 disabled:opacity-60">
                    {saving ? `${t('common.saving')}...` : t('profile.update_password')}
                  </button>
                </div>
              </div>
            )}

            {activeTab === 'delete_account' && (
              <div className="space-y-8">
                <div>
                  <h2 className="text-lg font-black text-palette-red mb-1">{t('profile.tab.delete')}</h2>
                  <p className="text-xs text-gray-500 font-semibold tracking-normal">{t('user_edit_profile.section.danger_subtitle')}</p>
                </div>

                <div className="p-6 bg-red-50 rounded-[5px] border border-red-100 space-y-4">
                  <div className="flex items-start gap-4">
                    <div className="p-2 bg-palette-red rounded-[5px] text-white">
                      <Trash2 size={24} />
                    </div>
                    <div>
                      <h4 className="text-sm font-black text-red-900 mb-1">{t('profile.delete_confirm_title')}</h4>
                      <p className="text-[12px] text-red-700 font-medium leading-relaxed">
                        {t('profile.delete_warning')}
                      </p>
                    </div>
                  </div>

                  <div className="flex flex-col gap-3 pt-2">
                    {formMessage && (
                      <div className="px-4 py-3 rounded-[5px] bg-white border border-red-200 text-[12px] font-bold text-palette-red">
                        {formMessage}
                      </div>
                    )}
                    <div className="space-y-1.5">
                      <label className="text-[11px] font-bold text-red-900 tracking-normal">{t('profile.enter_password_confirm')}</label>
                      <input type="password" value={deletePassword} onChange={(e) => setDeletePassword(e.target.value)} placeholder="••••••••" className="w-full px-4 py-3 bg-white border border-red-200 rounded-[5px] text-sm font-bold focus:border-red-500 outline-none transition-all" />
                    </div>
                    <button onClick={handleDeleteAccount} disabled={saving} className="flex items-center justify-center gap-2 py-4 bg-palette-red text-white rounded-[5px] text-[12px] font-bold tracking-normal hover:bg-red-700 transition-all shadow-xl active:scale-95 disabled:opacity-60">
                      <Trash2 size={16} />
                      {t('profile.delete_permanently')}
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* SAVE BUTTON AT THE BOTTOM */}
            {activeTab !== 'change_password' && activeTab !== 'delete_account' && (
            <div className="mt-10 pt-8 border-t border-gray-100 flex justify-end">
              <button
                onClick={handleSave}
                disabled={saving}
                className={`flex items-center justify-center gap-2 px-6 py-3 rounded-[5px] font-bold text-[12px] tracking-normal transition-all shadow-lg active:scale-95 ${saveStatus === 'success' ? 'bg-emerald-500 text-white' : 'bg-palette-red text-white hover:bg-red-700'
                  }`}
              >
                {saving ? (
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : saveStatus === 'success' ? (
                  <Check size={18} />
                ) : (
                  <Save size={18} />
                )}
                <span>{saving ? `${t('common.saving')}...` : saveStatus === 'success' ? t('profile.saved_success') : t('common.save_changes')}</span>
              </button>
            </div>
            )}

          </div>
        </div>
      </div>

    </div>
    </>
  );
};

export default UserEditProfile;
