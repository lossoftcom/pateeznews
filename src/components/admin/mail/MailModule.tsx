import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import ReactQuill from 'react-quill-new';
import 'react-quill-new/dist/quill.snow.css';
import type { MailAccount, MailCampaign, MailContactList, MailInboxItem, MailOutboxItem, MailTab, MailTemplate } from '@/lib/mail/types';
import { useToast } from '@/context/ToastContext';
import { mailClient } from './mailClient';

type MailModuleProps = {
  activeTab: MailTab;
  onNavigate: (tab: string, id?: string) => void;
  onUnreadCountChange?: (count: number) => void;
};

type DrawerSize = 'compose' | 'detail' | 'template';

const folderItems = [
  { id: 'all', label: 'Tümü', icon: 'all_inbox' },
  { id: 'inbox', label: 'Gelen Kutusu', icon: 'inbox' },
  { id: 'unread', label: 'Okunmamış', icon: 'mark_email_unread' },
  { id: 'starred', label: 'Yıldızlı', icon: 'star' },
  { id: 'attachments', label: 'Ekli', icon: 'attach_file' },
  { id: 'invoice', label: 'Fatura', icon: 'receipt_long' },
  { id: 'outbox', label: 'Giden Kutusu', icon: 'outbox' },
  { id: 'spam', label: 'Spam', icon: 'report' },
  { id: 'trash', label: 'Çöp', icon: 'delete' },
];

const providerLabels: Record<string, string> = {
  amazon_ses: 'Amazon SES',
  sendgrid: 'SendGrid',
  mailgun: 'Mailgun',
  postmark: 'Postmark',
  resend: 'Resend',
  mailtrap: 'Mailtrap',
  brevo: 'Brevo',
  mailersend: 'MailerSend',
  elastic_email: 'Elastic Email',
  sparkpost: 'SparkPost',
  mailchimp: 'Mailchimp',
  mailerlite: 'MailerLite',
  purelymail: 'Purelymail',
  gmail_oauth: 'Gmail OAuth',
  sendmail: 'Sendmail',
  smtp_generic: 'Özel SMTP',
};

const providerOptions = Object.entries(providerLabels).map(([id, label]) => ({ id, label }));
const templateCategories = ['kampanya', 'bilgi', 'davet', 'siparis', 'teklif'];

const emptyStats = { total: 0 };

const formatDate = (value?: string | null) => {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleDateString('tr-TR', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
};

const formatMailDateParts = (value?: string | null) => {
  if (!value) return { date: '-', time: '' };
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return { date: '-', time: '' };
  return {
    date: date.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric', weekday: 'long' }),
    time: `Saat : ${date.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })}`,
  };
};

const firstLetter = (value?: string | null) => String(value || '?').trim().charAt(0).toLocaleUpperCase('tr-TR') || '?';

const plainText = (html?: string | null) =>
  String(html || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const pct = (part?: number, total?: number) => {
  const denominator = Number(total || 0);
  if (!denominator) return 0;
  return Math.min(Math.round((Number(part || 0) / denominator) * 100), 100);
};

const statusLabel = (status?: string | null) => {
  const labels: Record<string, string> = {
    draft: 'Taslak',
    scheduled: 'Zamanlandı',
    sending: 'Gönderiliyor',
    paused: 'Duraklatıldı',
    completed: 'Tamamlandı',
    cancelled: 'İptal',
    queued: 'Kuyrukta',
    sent: 'Gönderildi',
    delivered: 'Teslim',
    opened: 'Açıldı',
    clicked: 'Tıklandı',
    bounce: 'Bounce',
    failed: 'Başarısız',
    ok: 'Hazır',
    not_tested: 'Test Yok',
    partial_error: 'Kısmi Hata',
  };
  return labels[String(status || '')] || status || '-';
};

const statusClasses = (status?: string | null) => {
  const key = String(status || '');
  if (['completed', 'sent', 'delivered', 'opened', 'clicked', 'ok'].includes(key)) return 'bg-emerald-50 text-emerald-700 border-emerald-100';
  if (['failed', 'cancelled', 'bounce', 'partial_error'].includes(key)) return 'bg-red-50 text-red-700 border-red-100';
  if (['sending', 'scheduled', 'queued'].includes(key)) return 'bg-amber-50 text-amber-700 border-amber-100';
  if (key === 'paused') return 'bg-sky-50 text-sky-700 border-sky-100';
  return 'bg-palette-beige/50 text-palette-tan border-palette-tan/15';
};

const Icon = ({ name, size = 18, className = '' }: { name: string; size?: number; className?: string }) => (
  <span className={`material-symbols-rounded ${className}`} style={{ fontSize: `${size}px` }}>{name}</span>
);

const StatusBadge = ({ status }: { status?: string | null }) => (
  <span className={`inline-flex items-center justify-center px-2.5 h-7 rounded-[5px] border text-[10px] font-black uppercase tracking-widest whitespace-nowrap ${statusClasses(status)}`}>
    {statusLabel(status)}
  </span>
);

const MailRowStatus = ({ isRead, status }: { isRead?: boolean; status?: string | null }) => {
  if (status) return <StatusBadge status={status} />;
  return (
    <span className={`inline-flex items-center gap-1.5 h-7 px-2.5 rounded-[5px] text-[11px] font-black ${isRead ? 'bg-palette-beige/45 text-palette-tan' : 'bg-emerald-50 text-emerald-700'}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${isRead ? 'bg-palette-tan' : 'bg-emerald-500'}`} />
      {isRead ? 'Okundu' : 'Yeni'}
    </span>
  );
};

const PrimaryButton = ({ children, icon, onClick, disabled, type = 'button' }: { children: React.ReactNode; icon?: string; onClick?: () => void; disabled?: boolean; type?: 'button' | 'submit' }) => (
  <button
    type={type}
    onClick={onClick}
    disabled={disabled}
    className="h-10 px-5 bg-palette-red text-white rounded-[5px] text-[12px] font-black tracking-widest hover:bg-palette-maroon transition-all shadow-lg shadow-palette-red/15 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
  >
    {icon ? <Icon name={icon} size={16} /> : null}
    {children}
  </button>
);

const GhostButton = ({ children, icon, onClick, disabled, className = '' }: { children: React.ReactNode; icon?: string; onClick?: () => void; disabled?: boolean; className?: string }) => (
  <button
    type="button"
    onClick={onClick}
    disabled={disabled}
    className={`h-10 px-4 bg-white text-palette-tan rounded-[5px] border border-palette-tan/20 text-[12px] font-black tracking-widest hover:bg-palette-beige/40 hover:text-palette-maroon transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2 ${className}`}
  >
    {icon ? <Icon name={icon} size={16} /> : null}
    {children}
  </button>
);

const IconButton = ({ icon, onClick, title, danger }: { icon: string; onClick: () => void; title?: string; danger?: boolean }) => (
  <button
    type="button"
    title={title}
    onClick={(event) => {
      event.stopPropagation();
      onClick();
    }}
    className={`w-9 h-9 rounded-[5px] flex items-center justify-center transition-all active:scale-90 ${danger ? 'text-red-500 hover:bg-red-50' : 'text-palette-tan/50 hover:bg-palette-beige hover:text-palette-maroon'}`}
  >
    <Icon name={icon} size={19} />
  </button>
);

const Field = ({ label, children }: { label: string; children: React.ReactNode }) => (
  <label className="space-y-2 block">
    <span className="text-[11px] font-black text-palette-tan/60 uppercase tracking-widest">{label}</span>
    {children}
  </label>
);

const inputClass = 'w-full h-11 px-4 bg-white border border-palette-tan/20 rounded-[5px] text-[14px] font-bold text-palette-maroon outline-none focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all placeholder:text-palette-tan/30';
const textareaClass = 'w-full min-h-[130px] p-4 bg-white border border-palette-tan/20 rounded-[5px] text-[14px] font-semibold text-palette-maroon outline-none focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all placeholder:text-palette-tan/30 resize-y';

const Drawer = ({ open, title, icon, size, onClose, children }: { open: boolean; title: string; icon: string; size: DrawerSize; onClose: () => void; children: React.ReactNode }) => {
  useEffect(() => {
    if (!open || typeof document === 'undefined') return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [open]);

  if (!open || typeof document === 'undefined') return null;
  const width = size === 'compose' ? 'w-[min(900px,calc(100vw-24px))]' : size === 'template' ? 'w-[min(780px,calc(100vw-24px))]' : 'w-[min(550px,calc(100vw-24px))]';
  return createPortal(
    <div className="fixed inset-0 z-[100000] flex justify-end">
      <div className="absolute inset-0 bg-palette-maroon/50 backdrop-blur-[2px] animate-in fade-in" onClick={onClose} />
      <aside className={`relative h-full ${width} bg-white border-l border-palette-tan/20 shadow-2xl animate-in slide-in-from-right duration-300 flex flex-col`}>
        <div className="h-16 px-6 border-b border-palette-tan/20 flex items-center justify-between bg-white">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-palette-beige/40 border border-palette-tan/20 rounded-[5px] flex items-center justify-center text-palette-red">
              <Icon name={icon} size={21} />
            </div>
            <div>
              <h3 className="text-[19px] font-black text-palette-maroon tracking-tight">{title}</h3>
            </div>
          </div>
          <IconButton icon="close" onClick={onClose} title="Kapat" />
        </div>
        <div className="flex-1 overflow-y-auto bg-palette-beige/20">{children}</div>
      </aside>
    </div>,
    document.body
  );
};

const TableShell = ({
  title,
  icon,
  actions,
  search,
  onSearch,
  stats,
  children,
}: {
  title: string;
  icon: string;
  actions?: React.ReactNode;
  search?: string;
  onSearch?: (value: string) => void;
  stats?: Array<{ label: string; value: React.ReactNode; icon: string }>;
  children: React.ReactNode;
}) => (
  <section className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm overflow-visible">
    <div className="px-7 py-6 border-b border-palette-tan/20 flex flex-col xl:flex-row xl:items-center justify-between gap-5">
      <div className="flex items-center gap-4">
        <div className="w-11 h-11 bg-palette-beige/35 border border-palette-tan/20 rounded-[5px] flex items-center justify-center text-palette-red">
          <Icon name={icon} size={22} />
        </div>
        <div>
          <h2 className="text-[22px] font-black text-palette-maroon tracking-tight">{title}</h2>
        </div>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        {onSearch ? (
          <div className="h-10 w-64 bg-palette-beige/30 border border-palette-tan/20 rounded-[5px] px-3 flex items-center gap-2 focus-within:bg-white focus-within:border-palette-red transition-all">
            <Icon name="search" size={18} className="text-palette-tan/40" />
            <input
              value={search || ''}
              onChange={(event) => onSearch(event.target.value)}
              placeholder="Ara..."
              className="w-full bg-transparent outline-none text-[13px] font-bold text-palette-maroon placeholder:text-palette-tan/30"
            />
          </div>
        ) : null}
        {actions}
      </div>
    </div>
    {stats?.length ? (
      <div className="px-7 py-4 bg-palette-beige/20 border-b border-palette-tan/20 grid grid-cols-2 md:grid-cols-4 gap-3">
        {stats.map((stat) => (
          <div key={stat.label} className="h-16 rounded-[5px] bg-white border border-palette-tan/15 px-4 flex items-center gap-3">
            <div className="w-9 h-9 rounded-[5px] bg-palette-beige/35 flex items-center justify-center text-palette-tan">
              <Icon name={stat.icon} size={18} />
            </div>
            <div>
              <p className="text-[18px] font-black text-palette-maroon leading-none">{stat.value}</p>
              <p className="text-[10px] font-black text-palette-tan/50 uppercase tracking-widest mt-1">{stat.label}</p>
            </div>
          </div>
        ))}
      </div>
    ) : null}
    <div className="overflow-x-auto">{children}</div>
  </section>
);

const EmptyState = ({ icon, title, description }: { icon: string; title: string; description: string }) => (
  <div className="p-14 text-center">
    <div className="w-16 h-16 mx-auto bg-palette-beige/35 border border-palette-tan/20 rounded-[5px] flex items-center justify-center text-palette-tan/50 mb-5">
      <Icon name={icon} size={30} />
    </div>
    <h3 className="text-[18px] font-black text-palette-maroon mb-2">{title}</h3>
    <p className="text-[13px] font-bold text-palette-tan/55 max-w-sm mx-auto">{description}</p>
  </div>
);

const MailModule: React.FC<MailModuleProps> = ({ activeTab, onNavigate, onUnreadCountChange }) => {
  const { showToast } = useToast();
  const [accounts, setAccounts] = useState<MailAccount[]>([]);
  const [templates, setTemplates] = useState<MailTemplate[]>([]);
  const [lists, setLists] = useState<MailContactList[]>([]);
  const [sharedLoading, setSharedLoading] = useState(true);
  const [composeOpen, setComposeOpen] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);

  const loadShared = useCallback(async () => {
    setSharedLoading(true);
    try {
      const [accountPayload, templatePayload, listPayload] = await Promise.all([
        mailClient.getAccounts(),
        mailClient.getTemplates(new URLSearchParams({ limit: '200' })),
        mailClient.getContactLists(new URLSearchParams({ limit: '200' })),
      ]);
      setAccounts(accountPayload.accounts || []);
      setTemplates(templatePayload.items || []);
      setLists(listPayload.items || []);
    } catch (error: any) {
      showToast(error.message || 'Posta verileri yüklenemedi', 'error');
    } finally {
      setSharedLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    loadShared();
  }, [loadShared, reloadKey]);

  useEffect(() => {
    setComposeOpen(activeTab === 'mail_send');
  }, [activeTab]);

  const refresh = () => setReloadKey((value) => value + 1);

  const shared = { accounts, templates, lists, refresh, sharedLoading };

  return (
    <div className="animate-in fade-in duration-500 admin-font text-palette-tan space-y-8 pb-16">
      {activeTab === 'mail_inbox' && (
        <InboxPage
          {...shared}
          onCompose={() => setComposeOpen(true)}
          onUnreadCountChange={onUnreadCountChange}
        />
      )}
      {activeTab === 'mail_send' && (
        <div className="bg-white rounded-[5px] border border-palette-tan/20 p-10 min-h-[420px] flex items-center justify-center text-center">
          <div>
            <div className="w-16 h-16 mx-auto bg-palette-beige/35 rounded-[5px] border border-palette-tan/20 flex items-center justify-center text-palette-red mb-5">
              <Icon name="outgoing_mail" size={30} />
            </div>
            <h2 className="text-[24px] font-black text-palette-maroon mb-2">Posta Gönder</h2>
            <PrimaryButton icon="open_in_full" onClick={() => setComposeOpen(true)}>Kartı Aç</PrimaryButton>
          </div>
        </div>
      )}
      {activeTab === 'mail_campaigns' && <CampaignsPage {...shared} />}
      {activeTab === 'mail_templates' && <TemplatesPage {...shared} />}
      {activeTab === 'mail_contacts' && <ContactListsPage {...shared} />}
      {activeTab === 'mail_settings' && <MailSettingsPage {...shared} />}

      <ComposeDrawer
        open={composeOpen}
        onClose={() => {
          setComposeOpen(false);
          if (activeTab === 'mail_send') onNavigate('mail_inbox');
        }}
        accounts={accounts}
        templates={templates}
        lists={lists}
        onSent={() => {
          setComposeOpen(false);
          refresh();
          if (activeTab === 'mail_send') onNavigate('mail_inbox');
        }}
      />
    </div>
  );
};

const InboxPage = ({
  accounts,
  onCompose,
  onUnreadCountChange,
}: {
  accounts: MailAccount[];
  onCompose: () => void;
  onUnreadCountChange?: (count: number) => void;
}) => {
  const { showToast } = useToast();
  const [folder, setFolder] = useState('inbox');
  const [items, setItems] = useState<MailInboxItem[]>([]);
  const [outboxItems, setOutboxItems] = useState<MailOutboxItem[]>([]);
  const [stats, setStats] = useState<any>(emptyStats);
  const [folderCounts, setFolderCounts] = useState<Record<string, number>>({});
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<string[]>([]);
  const [detail, setDetail] = useState<MailInboxItem | MailOutboxItem | null>(null);
  const [accountFilter, setAccountFilter] = useState('all');
  const [tagFilter, setTagFilter] = useState('all');
  const [pageSize, setPageSize] = useState(25);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);

  const isOutbox = folder === 'outbox';

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ limit: String(pageSize), offset: String((page - 1) * pageSize), search });
      if (accountFilter !== 'all') params.set('accountId', accountFilter);
      if (folder === 'unread' || folder === 'starred' || folder === 'attachments') params.set('status', folder);
      else if (folder !== 'all' && folder !== 'outbox') params.set('folder', folder);

      if (isOutbox) {
        const payload = await mailClient.getOutbox(params);
        setOutboxItems(payload.items || []);
        setStats(payload.stats || emptyStats);
        setTotal(Number(payload.total || 0));
      } else {
        const payload = await mailClient.getInbox(params);
        setItems(payload.items || []);
        setStats(payload.stats || emptyStats);
        setFolderCounts(payload.folderCounts || {});
        setTotal(Number(payload.total || 0));
        const unread = Number(payload.stats?.unread || 0);
        onUnreadCountChange?.(unread);
        window.dispatchEvent(new CustomEvent('pateez:mail-unread-count', { detail: { count: unread } }));
      }
    } catch (error: any) {
      showToast(error.message || 'Gelen kutusu yüklenemedi', 'error');
    } finally {
      setLoading(false);
    }
  }, [accountFilter, folder, isOutbox, onUnreadCountChange, page, pageSize, search, showToast]);

  useEffect(() => {
    const timer = window.setTimeout(load, 180);
    return () => window.clearTimeout(timer);
  }, [load]);

  const runAction = async (action: string, id?: string) => {
    const ids = id ? [id] : selected;
    if (!ids.length) return;
    try {
      const payload = await mailClient.updateInbox({ ids, action });
      const unread = Number(payload.unreadCount || 0);
      onUnreadCountChange?.(unread);
      window.dispatchEvent(new CustomEvent('pateez:mail-unread-count', { detail: { count: unread } }));
      setSelected([]);
      load();
    } catch (error: any) {
      showToast(error.message || 'İşlem yapılamadı', 'error');
    }
  };

  const rawTableItems = isOutbox ? outboxItems : items;
  const tableItems = tagFilter === 'all'
    ? rawTableItems
    : rawTableItems.filter((raw: any) => Array.isArray(raw.labels) && raw.labels.includes(tagFilter));
  const totalPages = Math.max(1, Math.ceil(Math.max(total, tableItems.length) / pageSize));
  const rangeStart = tableItems.length ? ((page - 1) * pageSize) + 1 : 0;
  const rangeEnd = tableItems.length ? ((page - 1) * pageSize) + tableItems.length : 0;
  const tagOptions = Array.from(new Set(items.flatMap((item: any) => Array.isArray(item.labels) ? item.labels : []).filter(Boolean)));

  const setFolderFilter = (value: string) => {
    setFolder(value);
    setSelected([]);
    setPage(1);
  };

  const statCards = [
    { label: isOutbox ? 'Toplam Giden' : 'Toplam Mail', value: stats.total || 0, icon: isOutbox ? 'outbox' : 'mail', tone: 'neutral' },
    { label: isOutbox ? 'Başarılı' : 'Okunmamış', value: isOutbox ? stats.successful || 0 : stats.unread || 0, icon: isOutbox ? 'task_alt' : 'mark_email_unread', tone: 'amber' },
    { label: isOutbox ? 'Kuyruk' : 'Arşiv', value: isOutbox ? stats.queued || 0 : stats.archived || 0, icon: isOutbox ? 'pending_actions' : 'archive', tone: 'blue' },
    { label: isOutbox ? 'Hatalı' : 'Ek Dosyalı', value: isOutbox ? stats.failed || 0 : stats.withAttachments || 0, icon: isOutbox ? 'error' : 'attach_file', tone: 'green' },
  ];

  const iconToneClass = (tone: string) => {
    if (tone === 'amber') return 'bg-palette-accent/15 text-palette-accent';
    if (tone === 'blue') return 'bg-blue-50 text-palette-maroon';
    if (tone === 'green') return 'bg-emerald-50 text-emerald-600';
    return 'bg-palette-beige/70 text-palette-maroon';
  };

  return (
    <div className="grid grid-cols-1 xl:grid-cols-[190px_minmax(0,1fr)] gap-4 bg-white rounded-[5px] border border-palette-tan/15 p-4 shadow-sm">
      <aside className="bg-white p-2 h-fit">
        {folderItems.map((item) => {
          const active = folder === item.id;
          const count = item.id === 'unread' ? stats.unread : item.id === 'outbox' ? stats.total : item.id === 'attachments' ? stats.withAttachments : folderCounts[item.id];
          return (
            <button
              key={item.id}
              onClick={() => {
                setFolderFilter(item.id);
              }}
              className={`w-full h-10 rounded-[8px] px-3 flex items-center gap-3 text-left transition-all ${active ? 'bg-palette-beige/60 text-palette-maroon' : 'text-palette-maroon/80 hover:bg-palette-beige/35 hover:text-palette-maroon'}`}
            >
              <Icon name={item.icon} size={18} className={active ? 'text-palette-maroon' : 'text-palette-maroon/70'} />
              <span className="flex-1 text-[13px] font-black truncate">{item.label}</span>
              {Number(count || 0) > 0 ? (
                <span className={`min-w-5 h-5 px-1.5 rounded-full text-[11px] font-black leading-5 text-center ${item.id === 'unread' ? 'bg-palette-accent text-white' : item.id === 'outbox' ? 'bg-palette-maroon text-white' : item.id === 'trash' ? 'bg-palette-red text-white' : 'bg-palette-beige text-palette-maroon'}`}>
                  {count}
                </span>
              ) : null}
            </button>
          );
        })}
      </aside>

      <section className="min-w-0 bg-white">
        <div className="mb-5">
          <h2 className="text-[25px] font-black text-palette-maroon tracking-tight">{isOutbox ? 'Giden Kutusu' : 'Mail Kutusu'}</h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3 mb-5">
          {statCards.map((stat) => (
            <div key={stat.label} className="h-[72px] rounded-[10px] bg-white border border-palette-tan/20 px-4 flex items-center gap-4">
              <div className={`w-11 h-11 rounded-[10px] flex items-center justify-center ${iconToneClass(stat.tone)}`}>
                <Icon name={stat.icon} size={21} />
              </div>
              <div>
                <p className="text-[13px] font-black text-palette-tan leading-none mb-2">{stat.label}</p>
                <p className="text-[22px] font-black text-palette-maroon leading-none">{stat.value}</p>
              </div>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-x-5 gap-y-3 mb-4">
          <div className="h-10 border-b border-palette-tan/25 flex items-center gap-2 min-w-0">
            <Icon name="folder" size={20} className="text-palette-tan" />
            <select
              value={folder}
              onChange={(event) => setFolderFilter(event.target.value)}
              className="flex-1 min-w-0 bg-transparent outline-none border-none text-[14px] font-black text-palette-tan"
            >
              {folderItems.map((item) => <option key={item.id} value={item.id}>{item.label} ({item.id === 'all' ? stats.total || total : item.id === 'unread' ? stats.unread || 0 : item.id === 'attachments' ? stats.withAttachments || 0 : item.id === 'outbox' ? stats.total || 0 : folderCounts[item.id] || 0})</option>)}
            </select>
            <button type="button" onClick={() => setFolderFilter('all')} className="text-palette-tan/60 hover:text-palette-maroon"><Icon name="close" size={17} /></button>
            <Icon name="expand_more" size={18} className="text-palette-tan/60" />
          </div>

          <div className="h-10 border-b border-palette-tan/25 flex items-center gap-2 min-w-0">
            <Icon name="alternate_email" size={20} className="text-palette-tan" />
            <select
              value={accountFilter}
              onChange={(event) => {
                setAccountFilter(event.target.value);
                setPage(1);
              }}
              className="flex-1 min-w-0 bg-transparent outline-none border-none text-[14px] font-black text-palette-tan"
            >
              <option value="all">Tümü ({stats.total || total || 0})</option>
              {accounts.map((account) => <option key={account.id} value={account.id}>{account.account_name}</option>)}
            </select>
            <button type="button" onClick={() => { setAccountFilter('all'); setPage(1); }} className="text-palette-tan/60 hover:text-palette-maroon"><Icon name="close" size={17} /></button>
            <Icon name="expand_more" size={18} className="text-palette-tan/60" />
          </div>

          <div className="h-10 border-b border-palette-tan/25 flex items-center gap-2 min-w-0">
            <Icon name="sell" size={20} className="text-palette-tan" />
            <select
              value={tagFilter}
              onChange={(event) => {
                setTagFilter(event.target.value);
                setPage(1);
              }}
              className="flex-1 min-w-0 bg-transparent outline-none border-none text-[14px] font-black text-palette-tan"
            >
              <option value="all">Tümü ({stats.total || total || 0})</option>
              {tagOptions.map((tag) => <option key={tag} value={tag}>{tag}</option>)}
            </select>
            <button type="button" onClick={() => { setTagFilter('all'); setPage(1); }} className="text-palette-tan/60 hover:text-palette-maroon"><Icon name="close" size={17} /></button>
            <Icon name="expand_more" size={18} className="text-palette-tan/60" />
          </div>
        </div>

        <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-3 mb-5">
          <select
            value={pageSize}
            onChange={(event) => {
              setPageSize(Number(event.target.value));
              setPage(1);
            }}
            className="w-20 h-10 rounded-[8px] bg-white border border-palette-tan/20 px-3 text-[15px] font-black text-palette-maroon outline-none focus:border-palette-red"
          >
            {[25, 50, 100].map((size) => <option key={size} value={size}>{size}</option>)}
          </select>

          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-end gap-3 xl:ml-auto">
            <div className="h-10 w-full sm:w-72 border-b border-palette-tan/25 px-2 flex items-center gap-2">
              <Icon name="search" size={22} className="text-palette-tan/70" />
              <input
                value={search}
                onChange={(event) => {
                  setSearch(event.target.value);
                  setPage(1);
                }}
                placeholder="Ara..."
                className="w-full bg-transparent outline-none text-[15px] font-bold text-palette-maroon placeholder:text-palette-tan/55"
              />
            </div>
            <div className="flex items-center justify-end gap-3">
              <GhostButton icon="refresh" onClick={load}>Yenile</GhostButton>
              {!isOutbox && selected.length ? <GhostButton icon="mark_email_read" onClick={() => runAction('read')}>Okundu</GhostButton> : null}
              <PrimaryButton icon="send" onClick={onCompose}>Posta Gönder</PrimaryButton>
            </div>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full min-w-[1040px]">
            <thead>
              <tr className="h-11 border-b border-palette-tan/15 text-[14px] font-bold text-palette-maroon">
                <th className="w-[48px] px-4 text-left">{!isOutbox ? '' : ''}</th>
                <th className="w-[210px] px-3 text-left">{isOutbox ? 'Alıcı' : 'Gönderen'}</th>
                <th className="px-3 text-left">Konu</th>
                <th className="w-[100px] px-3 text-left">Etiket</th>
                <th className="w-[70px] px-3 text-left">Ekler</th>
                <th className="w-[160px] px-3 text-left">Hesap</th>
                <th className="w-[170px] px-3 text-left">Tarih</th>
                <th className="w-[105px] px-3 text-left">Durum</th>
                <th className="w-[80px] px-4 text-right">İşlemler</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-palette-tan/10">
              {loading ? (
                <tr><td colSpan={9}><EmptyState icon="progress_activity" title="Posta eşitleniyor" description="Kayıtlar hazırlanıyor." /></td></tr>
              ) : !tableItems.length ? (
                <tr><td colSpan={9}><EmptyState icon="inbox" title="Kayıt yok" description="Bu görünüm için posta kaydı bulunamadı." /></td></tr>
              ) : tableItems.map((raw) => {
                const item: any = raw;
                const checked = selected.includes(item.id);
                const title = isOutbox ? item.recipient_email : item.sender_name || item.sender_email;
                const date = isOutbox ? item.sent_at || item.created_at : item.mail_date || item.created_at;
                const dateParts = formatMailDateParts(date);
                const labels = Array.isArray(item.labels) ? item.labels : [];
                const label = isOutbox ? 'Giden' : labels[0] || item.folder || 'Gelen';
                return (
                  <tr key={item.id} onClick={() => setDetail(item)} className="h-[62px] cursor-pointer bg-white hover:bg-palette-beige/20 transition-all">
                    <td className="px-4 align-middle">
                      {!isOutbox ? (
                        <input
                          type="checkbox"
                          checked={checked}
                          onClick={(event) => event.stopPropagation()}
                          onChange={() => setSelected((prev) => prev.includes(item.id) ? prev.filter((id) => id !== item.id) : [...prev, item.id])}
                          className="w-4 h-4 rounded-[5px] border-palette-tan/30 text-palette-red focus:ring-palette-red"
                        />
                      ) : null}
                    </td>
                    <td className="px-3 align-middle">
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="relative w-10 h-10 rounded-full bg-palette-beige/70 flex items-center justify-center text-palette-maroon font-black shrink-0">
                          {firstLetter(title)}
                          {!isOutbox && !item.is_read ? <span className="absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full bg-palette-maroon" /> : null}
                        </div>
                        <div className="min-w-0">
                          <p className="text-[14px] font-black text-palette-maroon truncate">{title}</p>
                          <p className="text-[12px] font-bold text-palette-tan truncate">{isOutbox ? item.recipient_name || 'Alıcı' : item.sender_email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-3 align-middle">
                      <p className="text-[14px] font-black text-palette-maroon truncate">{item.subject || '-'}</p>
                      <p className="text-[12px] font-medium text-palette-tan truncate">{plainText(item.content_html || item.content_text)}</p>
                    </td>
                    <td className="px-3 align-middle text-[12px] font-bold text-palette-tan">{label}</td>
                    <td className="px-3 align-middle">
                      {Array.isArray(item.attachments) && item.attachments.length ? <Icon name="attach_file" size={18} className="text-palette-red" /> : <span className="text-palette-tan/25">-</span>}
                    </td>
                    <td className="px-3 align-middle text-[14px] font-black text-palette-maroon truncate">{item.account_name || accounts.find((account) => account.id === item.account_id)?.account_name || '-'}</td>
                    <td className="px-3 align-middle text-[11px] font-semibold text-palette-maroon">
                      <div>{dateParts.date}</div>
                      <div>{dateParts.time}</div>
                    </td>
                    <td className="px-3 align-middle">{isOutbox ? <StatusBadge status={item.status} /> : <MailRowStatus isRead={item.is_read} />}</td>
                    <td className="px-4 align-middle">
                      <div className="flex justify-end">
                        <IconButton icon="more_horiz" onClick={() => setDetail(item)} />
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="h-16 border-t border-palette-tan/10 flex items-center justify-between">
          <p className="text-[14px] font-semibold text-palette-maroon">{rangeStart} - {rangeEnd} / {total || tableItems.length} kayıt gösteriliyor</p>
          <div className="flex items-center gap-2">
            <button type="button" disabled={page <= 1} onClick={() => setPage(1)} className="w-9 h-9 rounded-[6px] border border-palette-tan/15 flex items-center justify-center text-palette-tan disabled:opacity-35"><Icon name="keyboard_double_arrow_left" size={18} /></button>
            <button type="button" disabled={page <= 1} onClick={() => setPage((value) => Math.max(1, value - 1))} className="w-9 h-9 rounded-[6px] border border-palette-tan/15 flex items-center justify-center text-palette-tan disabled:opacity-35"><Icon name="chevron_left" size={18} /></button>
            <span className="w-9 h-9 rounded-[6px] bg-palette-maroon text-white flex items-center justify-center text-[14px] font-black">{page}</span>
            <button type="button" disabled={page >= totalPages} onClick={() => setPage((value) => Math.min(totalPages, value + 1))} className="w-9 h-9 rounded-[6px] border border-palette-tan/15 flex items-center justify-center text-palette-tan disabled:opacity-35"><Icon name="chevron_right" size={18} /></button>
            <button type="button" disabled={page >= totalPages} onClick={() => setPage(totalPages)} className="w-9 h-9 rounded-[6px] border border-palette-tan/15 flex items-center justify-center text-palette-tan disabled:opacity-35"><Icon name="keyboard_double_arrow_right" size={18} /></button>
          </div>
        </div>
      </section>

      <Drawer open={!!detail} title={isOutbox ? 'Giden Posta Detayı' : 'Mail Detayı'} icon="drafts" size="detail" onClose={() => setDetail(null)}>
        {detail ? <MailDetail item={detail as any} isOutbox={isOutbox} /> : null}
      </Drawer>
    </div>
  );
};

const MailDetail = ({ item, isOutbox }: { item: any; isOutbox?: boolean }) => (
  <div className="p-7 space-y-6">
    <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6">
      <div className="flex items-start gap-4">
        <div className="w-12 h-12 rounded-[5px] bg-palette-beige/45 flex items-center justify-center text-palette-maroon font-black">
          {firstLetter(isOutbox ? item.recipient_email : item.sender_name || item.sender_email)}
        </div>
        <div className="min-w-0 flex-1">
          <h3 className="text-[20px] font-black text-palette-maroon leading-tight">{item.subject || '-'}</h3>
          <p className="text-[13px] font-bold text-palette-tan/60 mt-1">
            {isOutbox ? item.recipient_email : item.sender_name || item.sender_email} · {formatDate(isOutbox ? item.sent_at || item.created_at : item.mail_date || item.created_at)}
          </p>
        </div>
      </div>
    </div>
    <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 min-h-[240px]">
      {item.content_html ? (
        <div className="prose prose-sm max-w-none text-palette-maroon" dangerouslySetInnerHTML={{ __html: item.content_html }} />
      ) : (
        <p className="text-[14px] font-semibold text-palette-maroon whitespace-pre-wrap">{item.content_text || 'İçerik yok.'}</p>
      )}
    </div>
    {Array.isArray(item.attachments) && item.attachments.length ? (
      <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6">
        <h4 className="text-[12px] font-black text-palette-tan/60 uppercase tracking-widest mb-4">Ek Dosyalar</h4>
        <div className="space-y-2">
          {item.attachments.map((attachment: any, index: number) => (
            <div key={index} className="h-11 px-4 bg-palette-beige/20 border border-palette-tan/15 rounded-[5px] flex items-center gap-3">
              <Icon name="attach_file" size={18} className="text-palette-red" />
              <span className="text-[13px] font-bold text-palette-maroon">{attachment.filename || `Ek ${index + 1}`}</span>
            </div>
          ))}
        </div>
      </div>
    ) : null}
  </div>
);

const MAIL_COMPOSE_STYLE = `
  .mail-compose-drawer .ql-toolbar.ql-snow {
    border: 0 !important;
    border-bottom: 1px solid rgba(149, 165, 166, 0.22) !important;
    background: #f8fafc !important;
    padding: 5px 8px !important;
    border-radius: 9px 9px 0 0 !important;
  }
  .mail-compose-drawer .ql-toolbar.ql-snow .ql-formats {
    margin-right: 8px !important;
    padding-right: 8px !important;
    border-right: 1px solid rgba(149, 165, 166, 0.18);
  }
  .mail-compose-drawer .ql-toolbar.ql-snow button {
    width: 25px !important;
    height: 25px !important;
    padding: 4px !important;
    border-radius: 6px !important;
  }
  .mail-compose-drawer .ql-toolbar.ql-snow button:hover,
  .mail-compose-drawer .ql-toolbar.ql-snow .ql-picker-label:hover,
  .mail-compose-drawer .mail-toolbar-preview:hover {
    background: rgba(44, 62, 80, 0.07) !important;
    color: #2C3E50 !important;
  }
  .mail-compose-drawer .ql-toolbar.ql-snow .ql-picker {
    color: #2C3E50 !important;
    font-weight: 800 !important;
  }
  .mail-compose-drawer .ql-toolbar.ql-snow .ql-stroke {
    stroke: #2C3E50 !important;
  }
  .mail-compose-drawer .ql-toolbar.ql-snow .ql-fill {
    fill: #2C3E50 !important;
  }
  .mail-compose-drawer .ql-container.ql-snow {
    border: 0 !important;
    height: clamp(240px, 34vh, 305px) !important;
    min-height: clamp(240px, 34vh, 305px) !important;
    font-family: Inter, system-ui, sans-serif !important;
    font-size: 15px !important;
    color: #2C3E50 !important;
  }
  .mail-compose-drawer .ql-editor {
    height: clamp(240px, 34vh, 305px) !important;
    min-height: clamp(240px, 34vh, 305px) !important;
    padding: 18px 22px !important;
    line-height: 1.65 !important;
  }
  .mail-compose-drawer .ql-editor.ql-blank:before {
    color: rgba(149, 165, 166, 0.72) !important;
    font-style: normal !important;
    font-weight: 700 !important;
    left: 22px !important;
  }
  .mail-compose-drawer .mail-toolbar-preview {
    width: 25px;
    height: 25px;
    border-radius: 6px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    color: #2C3E50;
    vertical-align: middle;
  }
`;

const fileToAttachment = (file: File) => new Promise<Record<string, string | undefined>>((resolve, reject) => {
  const reader = new FileReader();
  reader.onload = () => {
    const dataUrl = String(reader.result || '');
    resolve({
      filename: file.name,
      content: dataUrl.includes(',') ? dataUrl.split(',')[1] : dataUrl,
      contentType: file.type || undefined,
      encoding: 'base64',
    });
  };
  reader.onerror = () => reject(reader.error || new Error('Dosya okunamadı'));
  reader.readAsDataURL(file);
});

const MailPreviewModal = ({ open, html, onClose }: { open: boolean; html: string; onClose: () => void }) => {
  useEffect(() => {
    if (!open) return;
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [onClose, open]);

  if (!open || typeof document === 'undefined') return null;

  return createPortal(
    <div className="fixed inset-0 z-[100002] flex items-center justify-center p-6">
      <div className="absolute inset-0 bg-palette-maroon/75 backdrop-blur-[1px]" onClick={onClose} />
      <section className="relative w-[min(720px,calc(100vw-32px))] h-[min(800px,calc(100vh-64px))] bg-white rounded-[16px] shadow-2xl flex flex-col overflow-hidden">
        <div className="h-[68px] px-6 border-b border-palette-tan/15 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Icon name="preview" size={19} className="text-palette-maroon" />
            <h3 className="text-[20px] font-black text-palette-maroon tracking-tight">Mail Önizleme</h3>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-[10px] font-black text-palette-tan/55 uppercase tracking-widest">ESC</span>
            <IconButton icon="close" onClick={onClose} title="Kapat" />
          </div>
        </div>
        <div className="flex-1 bg-slate-50 p-4">
          <div className="h-full rounded-[10px] border border-palette-tan/15 bg-slate-100 p-3 overflow-y-auto">
            <div className="mx-auto w-[min(580px,100%)] min-h-[86px] bg-white px-12 py-9 text-[14px] font-semibold text-palette-maroon">
              {html ? <div className="prose prose-sm max-w-none" dangerouslySetInnerHTML={{ __html: html }} /> : <p>Önizlenecek şablon içeriği yok.</p>}
            </div>
          </div>
        </div>
      </section>
    </div>,
    document.body
  );
};

type ComposeDrawerProps = {
  open: boolean;
  accounts: MailAccount[];
  templates: MailTemplate[];
  lists: MailContactList[];
  onClose: () => void;
  onSent: () => void;
};

const ComposeDrawer: React.FC<ComposeDrawerProps> = ({
  open,
  accounts,
  templates,
  lists,
  onClose,
  onSent,
}) => {
  const { showToast } = useToast();
  const [saving, setSaving] = useState(false);
  const [previewOpen, setPreviewOpen] = useState(false);
  const [files, setFiles] = useState<File[]>([]);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const toolbarId = useRef(`mail-compose-toolbar-${Math.random().toString(36).slice(2)}`).current;
  const [form, setForm] = useState({
    account_id: '',
    template_id: '',
    recipients: '',
    subject: '',
    content_html: '',
    scheduled_at: '',
  });

  const quillModules = useMemo(() => ({
    toolbar: {
      container: `#${toolbarId}`,
    },
  }), [toolbarId]);

  useEffect(() => {
    setForm((prev) => ({ ...prev, account_id: prev.account_id || accounts[0]?.id || '' }));
  }, [accounts]);

  useEffect(() => {
    if (!open || typeof document === 'undefined') return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [open]);

  const applyTemplate = (templateId: string) => {
    const template = templates.find((item) => item.id === templateId);
    setForm((prev) => ({
      ...prev,
      template_id: templateId,
      subject: prev.subject || template?.template_name || '',
      content_html: template?.content_html || prev.content_html,
    }));
  };

  const addListRecipients = (listId: string) => {
    const list = lists.find((item) => item.id === listId);
    if (!list) return;
    setForm((prev) => ({ ...prev, recipients: `${prev.recipients}${prev.recipients ? '\n' : ''}#${list.list_name}` }));
    showToast('Kişi listesi kampanya ekranında alıcıya dönüştürülür; manuel alıcılar korunur.', 'info');
  };

  const addContactList = () => {
    if (!lists.length) {
      showToast('Kişi listesi bulunamadı', 'info');
      return;
    }
    const requested = window.prompt('Eklenecek liste adı', lists[0]?.list_name || '');
    const list = lists.find((item) => item.list_name.toLocaleLowerCase('tr-TR') === String(requested || '').toLocaleLowerCase('tr-TR')) || lists[0];
    addListRecipients(list.id);
  };

  const applyAiDraft = () => {
    setForm((prev) => ({
      ...prev,
      content_html: prev.content_html || '<h1>Merhaba</h1><p>Mesajınızı buraya yazın.</p>',
    }));
  };

  const scheduleSend = () => {
    const current = form.scheduled_at ? form.scheduled_at.replace('T', ' ') : '';
    const value = window.prompt('Zamanlama tarihi (YYYY-MM-DD HH:mm)', current);
    if (!value) return;
    setForm((prev) => ({ ...prev, scheduled_at: value.includes('T') ? value : value.replace(' ', 'T') }));
    showToast('Zaman ayarlandı. Gönder butonu kuyruk kaydı oluşturacak.', 'info');
  };

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    setSaving(true);
    try {
      const attachments = files.length ? await Promise.all(files.map(fileToAttachment)) : [];
      const payload = await mailClient.send({
        ...form,
        attachments,
        recipients: form.recipients
          .split(/[\n,;]+/g)
          .map((value) => value.trim())
          .filter((value) => value && !value.startsWith('#')),
      });
      showToast(payload.failed?.length ? 'Posta kısmi hatayla tamamlandı' : 'Posta gönderildi', payload.failed?.length ? 'warning' : 'success');
      onSent();
    } catch (error: any) {
      showToast(error.message || 'Posta gönderilemedi', 'error');
    } finally {
      setSaving(false);
    }
  };

  if (!open || typeof document === 'undefined') return null;

  return createPortal(
    <div className="fixed inset-0 z-[100001] flex justify-end">
      <style>{MAIL_COMPOSE_STYLE}</style>
      <div className="absolute inset-0 bg-palette-maroon/58 backdrop-blur-[1px]" onClick={onClose} />
      <aside className="mail-compose-drawer relative h-full w-[min(900px,calc(100vw-24px))] bg-white shadow-2xl flex flex-col overflow-hidden">
        <header className="h-[64px] px-4 border-b border-palette-tan/15 flex items-center justify-between bg-white shrink-0">
          <h3 className="text-[25px] font-black text-palette-maroon tracking-tight">Posta Gönder</h3>
          <div className="flex items-center gap-5">
            <button type="button" onClick={applyAiDraft} className="h-10 px-2 inline-flex items-center gap-2 text-[13px] font-black text-palette-maroon hover:text-palette-red transition-colors">
              <Icon name="auto_awesome" size={17} />
              Yapay Zeka ile Yaz
            </button>
            <button type="button" onClick={onClose} className="w-9 h-9 rounded-[6px] flex items-center justify-center text-palette-tan hover:bg-palette-beige/60 hover:text-palette-maroon transition-all" title="Kapat">
              <Icon name="close" size={24} />
            </button>
          </div>
        </header>

        <form onSubmit={submit} className="min-h-0 flex-1 flex flex-col bg-white">
          <div className="flex-1 min-h-0 overflow-hidden px-4 pb-3">
            <section className="rounded-[10px] border border-palette-tan/18 bg-white overflow-hidden">
              <div className="px-5 pt-4 pb-2 space-y-3">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-3">
                  <label className="block">
                    <span className="block text-[13px] font-black text-palette-maroon mb-1">Hesap</span>
                    <span className="block text-[13px] font-semibold text-palette-tan mb-1">Hesap</span>
                    <select className="w-full h-8 bg-transparent border-0 border-b border-palette-tan/30 px-0 text-[16px] font-bold text-palette-maroon outline-none focus:border-palette-red" value={form.account_id} onChange={(event) => setForm({ ...form, account_id: event.target.value })}>
                      <option value="">Hesap seçin</option>
                      {accounts.map((account) => <option key={account.id} value={account.id}>{account.account_name}</option>)}
                    </select>
                  </label>
                  <label className="block">
                    <span className="block text-[13px] font-black text-palette-maroon mb-6">Şablon</span>
                    <select className="w-full h-8 bg-transparent border-0 border-b border-palette-tan/30 px-0 text-[16px] font-bold text-palette-maroon outline-none focus:border-palette-red" value={form.template_id} onChange={(event) => applyTemplate(event.target.value)}>
                      <option value="">Şablon</option>
                      {templates.map((template) => <option key={template.id} value={template.id}>{template.template_name}</option>)}
                    </select>
                  </label>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-3">
                  <label className="block">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-[13px] font-black text-palette-maroon">Kime</span>
                      <button type="button" onClick={addContactList} className="inline-flex items-center gap-1.5 text-[13px] font-black text-palette-maroon hover:text-palette-red">
                        <Icon name="person_add" size={16} />
                        + Kişi Ekle
                      </button>
                    </div>
                    <textarea
                      className="w-full h-[46px] bg-transparent border-0 border-b border-palette-tan/30 px-0 pt-1 text-[16px] font-bold text-palette-maroon outline-none resize-none focus:border-palette-red placeholder:text-palette-tan/55"
                      value={form.recipients}
                      onChange={(event) => setForm({ ...form, recipients: event.target.value })}
                      placeholder="Alıcılar"
                    />
                  </label>
                  <label className="block">
                    <span className="block text-[13px] font-black text-palette-maroon mb-1">Konu</span>
                    <input className="w-full h-[46px] bg-transparent border-0 border-b border-palette-tan/30 px-0 pt-1 text-[16px] font-bold text-palette-maroon outline-none focus:border-palette-red placeholder:text-palette-tan/55" value={form.subject} onChange={(event) => setForm({ ...form, subject: event.target.value })} placeholder="Posta konusu" />
                  </label>
                </div>
              </div>

              <div className="px-5 pb-0">
                <h4 className="text-[13px] font-black text-palette-maroon mb-1.5">İçerik</h4>
                <div className="rounded-[10px] border border-palette-tan/18 overflow-hidden bg-white">
                  <div id={toolbarId}>
                    <span className="ql-formats">
                      <select className="ql-font" defaultValue="">
                        <option value="">Inter</option>
                        <option value="serif">Serif</option>
                        <option value="monospace">Mono</option>
                      </select>
                      <select className="ql-size" defaultValue="">
                        <option value="small">12</option>
                        <option value="">13</option>
                        <option value="large">18</option>
                        <option value="huge">24</option>
                      </select>
                    </span>
                    <span className="ql-formats">
                      <button type="button" className="ql-bold" />
                      <button type="button" className="ql-italic" />
                      <button type="button" className="ql-underline" />
                      <button type="button" className="ql-strike" />
                    </span>
                    <span className="ql-formats">
                      <button type="button" className="ql-align" value="" />
                      <button type="button" className="ql-align" value="center" />
                      <button type="button" className="ql-align" value="right" />
                      <button type="button" className="ql-list" value="bullet" />
                      <button type="button" className="ql-list" value="ordered" />
                      <button type="button" className="ql-indent" value="-1" />
                      <button type="button" className="ql-indent" value="+1" />
                    </span>
                    <span className="ql-formats">
                      <button type="button" className="ql-link" />
                      <button type="button" className="ql-image" />
                      <button type="button" className="ql-blockquote" />
                      <button type="button" className="ql-code-block" />
                      <button type="button" className="ql-clean" />
                      <button type="button" className="mail-toolbar-preview" onClick={() => setPreviewOpen(true)} title="Önizleme">
                        <Icon name="preview" size={17} />
                      </button>
                    </span>
                  </div>
                  <ReactQuill
                    theme="snow"
                    modules={quillModules}
                    value={form.content_html}
                    onChange={(value) => setForm({ ...form, content_html: value })}
                    placeholder="Mail içeriğini buraya yazın..."
                  />
                </div>
              </div>

              <div className="px-5 py-3 flex flex-wrap items-center gap-3">
                <span className="text-[16px] font-black text-palette-maroon">Ek Dosyalar</span>
                <input
                  ref={fileInputRef}
                  type="file"
                  multiple
                  className="hidden"
                  onChange={(event) => setFiles(Array.from(event.target.files || []))}
                />
                <button type="button" onClick={() => fileInputRef.current?.click()} className="h-8 px-4 rounded-full border border-palette-tan/20 bg-white text-[14px] font-bold text-palette-maroon inline-flex items-center gap-2 hover:border-palette-maroon/40 transition-all">
                  <Icon name="attach_file" size={17} />
                  Dosya Ekle
                </button>
                {files.map((file) => (
                  <span key={`${file.name}-${file.size}`} className="h-8 px-3 rounded-full bg-palette-beige/45 text-[12px] font-black text-palette-tan inline-flex items-center gap-2">
                    {file.name}
                    <button type="button" onClick={() => setFiles((prev) => prev.filter((item) => item !== file))} className="text-palette-tan hover:text-palette-red">
                      <Icon name="close" size={14} />
                    </button>
                  </span>
                ))}
              </div>
            </section>
          </div>

          <footer className="h-[56px] px-4 border-t border-palette-tan/15 bg-white flex items-center justify-end gap-3 shrink-0">
            <button type="button" onClick={() => showToast('Taslak kaydı giden kutusu kuyruk mantığıyla korunur.', 'info')} className="h-9 px-5 rounded-full border border-palette-maroon/35 text-[14px] font-black text-palette-maroon inline-flex items-center gap-2 hover:bg-palette-beige/40 transition-all">
              <Icon name="draft" size={17} />
              Taslak Kaydet
            </button>
            <button type="button" onClick={scheduleSend} className="h-9 px-5 rounded-full border border-palette-maroon/35 text-[14px] font-black text-palette-maroon inline-flex items-center gap-2 hover:bg-palette-beige/40 transition-all">
              <Icon name="schedule" size={17} />
              Zamanla
            </button>
            <button type="submit" disabled={saving} className="h-10 px-7 rounded-full bg-palette-red text-white text-[14px] font-black inline-flex items-center gap-2 shadow-lg shadow-palette-red/20 hover:bg-palette-maroon transition-all disabled:opacity-50 disabled:cursor-not-allowed">
              <Icon name="send" size={20} />
              {saving ? 'Gönderiliyor' : 'Gönder'}
            </button>
          </footer>
        </form>
        <MailPreviewModal open={previewOpen} html={form.content_html} onClose={() => setPreviewOpen(false)} />
      </aside>
    </div>,
    document.body
  );
};

const CampaignsPage = ({ accounts, lists, templates, refresh }: { accounts: MailAccount[]; lists: MailContactList[]; templates: MailTemplate[]; refresh: () => void }) => {
  const { showToast } = useToast();
  const [items, setItems] = useState<MailCampaign[]>([]);
  const [stats, setStats] = useState<any>(emptyStats);
  const [search, setSearch] = useState('');
  const [dialog, setDialog] = useState<MailCampaign | null | 'new'>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const payload = await mailClient.getCampaigns(new URLSearchParams({ limit: '50', search }));
      setItems(payload.items || []);
      setStats(payload.stats || emptyStats);
    } catch (error: any) {
      showToast(error.message || 'Kampanyalar yüklenemedi', 'error');
    } finally {
      setLoading(false);
    }
  }, [search, showToast]);

  useEffect(() => {
    const timer = window.setTimeout(load, 200);
    return () => window.clearTimeout(timer);
  }, [load]);

  const action = async (campaign: MailCampaign, actionName: string) => {
    try {
      const extra = actionName === 'schedule'
        ? { scheduled_start_at: window.prompt('Zamanlama tarihi (YYYY-MM-DD HH:mm)', campaign.scheduled_start_at || '') || '' }
        : {};
      await mailClient.campaignAction(campaign.id, actionName, extra);
      showToast('Kampanya güncellendi', 'success');
      load();
    } catch (error: any) {
      showToast(error.message || 'Kampanya güncellenemedi', 'error');
    }
  };

  const remove = async (id: string) => {
    if (!window.confirm('Kampanya silinsin mi?')) return;
    await mailClient.deleteCampaign(id);
    load();
  };

  return (
    <>
      <TableShell
        title="Kampanyalar"
        icon="campaign"
        search={search}
        onSearch={setSearch}
        stats={[
          { label: 'Toplam', value: stats.total || 0, icon: 'campaign' },
          { label: 'Gönderiliyor', value: stats.sending || 0, icon: 'send' },
          { label: 'Zamanlı', value: stats.scheduled || 0, icon: 'schedule' },
          { label: 'Tamamlanan', value: stats.completed || 0, icon: 'task_alt' },
        ]}
        actions={<PrimaryButton icon="add" onClick={() => setDialog('new')}>Yeni Kampanya</PrimaryButton>}
      >
        {loading ? <EmptyState icon="progress_activity" title="Kampanyalar yükleniyor" description="Kayıtlar hazırlanıyor." /> : !items.length ? <EmptyState icon="campaign" title="Kampanya yok" description="Yeni kampanya oluşturarak başlayın." /> : (
          <table className="w-full min-w-[1180px]">
            <thead className="bg-palette-beige/30 border-b border-palette-tan/20">
              <tr className="text-[10px] font-black text-palette-tan/50 uppercase tracking-widest">
                <th className="w-[50px] px-4 py-4 text-left">Seç</th>
                <th className="w-[250px] px-3 py-4 text-left">Bulk Mail</th>
                <th className="w-[95px] px-3 py-4 text-center">Alıcı</th>
                <th className="w-[110px] px-3 py-4 text-center">Gönderilen</th>
                <th className="w-[95px] px-3 py-4 text-center">Açılma</th>
                <th className="w-[95px] px-3 py-4 text-center">Tıklama</th>
                <th className="w-[85px] px-3 py-4 text-center">Bounce</th>
                <th className="w-[130px] px-3 py-4 text-center">Durum</th>
                <th className="w-[128px] px-3 py-4 text-center">Kontrol</th>
                <th className="w-[150px] px-3 py-4 text-right">Başlangıç</th>
                <th className="w-[120px] px-4 py-4 text-right">İşlem</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-palette-tan/10">
              {items.map((campaign) => (
                <tr key={campaign.id} className="h-[78px] hover:bg-palette-beige/20 transition-all">
                  <td className="px-4"><input type="checkbox" className="w-4 h-4 rounded-[5px] border-palette-tan/30 text-palette-red focus:ring-palette-red" /></td>
                  <td className="px-3">
                    <p className="text-[14px] font-black text-palette-maroon truncate">{campaign.campaign_name}</p>
                    <p className="text-[11px] font-bold text-palette-tan/50 truncate">{campaign.subject}</p>
                  </td>
                  <td className="px-3 text-center text-[14px] font-black text-palette-maroon">{campaign.recipient_count || 0}</td>
                  <td className="px-3 text-center">
                    <div className="text-[14px] font-black text-palette-maroon">{campaign.sent_count || 0}</div>
                    <div className="h-1.5 bg-palette-beige rounded-full overflow-hidden"><div className="h-full bg-palette-red" style={{ width: `${pct(campaign.sent_count, campaign.recipient_count)}%` }} /></div>
                  </td>
                  <td className="px-3 text-center text-[13px] font-black text-palette-tan">{pct(campaign.opened_count, campaign.sent_count)}%</td>
                  <td className="px-3 text-center text-[13px] font-black text-palette-tan">{pct(campaign.clicked_count, campaign.sent_count)}%</td>
                  <td className="px-3 text-center text-[13px] font-black text-palette-tan">{campaign.bounce_count || 0}</td>
                  <td className="px-3 text-center"><StatusBadge status={campaign.status} /></td>
                  <td className="px-3">
                    <div className="flex items-center justify-center gap-1">
                      {campaign.status === 'draft' && <IconButton icon="play_arrow" onClick={() => action(campaign, 'start')} />}
                      {campaign.status === 'sending' && <IconButton icon="pause" onClick={() => action(campaign, 'pause')} />}
                      {campaign.status === 'paused' && <IconButton icon="play_arrow" onClick={() => action(campaign, 'resume')} />}
                      <IconButton icon="event" onClick={() => action(campaign, 'schedule')} />
                      {!['completed', 'cancelled'].includes(campaign.status) && <IconButton icon="cancel" danger onClick={() => action(campaign, 'cancel')} />}
                    </div>
                  </td>
                  <td className="px-3 text-right text-[11px] font-bold text-palette-tan">{formatDate(campaign.scheduled_start_at || campaign.started_at || campaign.created_at)}</td>
                  <td className="px-4">
                    <div className="flex justify-end gap-1">
                      <IconButton icon="edit" onClick={() => setDialog(campaign)} />
                      <IconButton icon="delete" danger onClick={() => remove(campaign.id)} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </TableShell>

      <CampaignDialog
        open={!!dialog}
        campaign={dialog === 'new' ? null : dialog}
        accounts={accounts}
        lists={lists}
        templates={templates}
        onClose={() => setDialog(null)}
        onSaved={() => {
          setDialog(null);
          load();
          refresh();
        }}
      />
    </>
  );
};

const CampaignDialog = ({ open, campaign, accounts, lists, templates, onClose, onSaved }: { open: boolean; campaign: MailCampaign | null; accounts: MailAccount[]; lists: MailContactList[]; templates: MailTemplate[]; onClose: () => void; onSaved: () => void }) => {
  const { showToast } = useToast();
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState<any>({});

  useEffect(() => {
    if (!open) return;
    setForm({
      id: campaign?.id,
      account_id: campaign?.account_id || accounts[0]?.id || '',
      contact_list_id: campaign?.contact_list_id || lists[0]?.id || '',
      template_id: campaign?.template_id || '',
      campaign_name: campaign?.campaign_name || '',
      subject: campaign?.subject || '',
      preview_text: campaign?.preview_text || '',
      content_html: campaign?.content_html || '',
      send_rate: campaign?.send_rate || 100,
      add_unsubscribe_link: campaign?.add_unsubscribe_link ?? true,
      add_tracking_pixel: campaign?.add_tracking_pixel ?? true,
    });
  }, [accounts, campaign, lists, open]);

  const applyTemplate = (id: string) => {
    const template = templates.find((item) => item.id === id);
    setForm((prev: any) => ({ ...prev, template_id: id, content_html: template?.content_html || prev.content_html, subject: prev.subject || template?.template_name || '' }));
  };

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    setSaving(true);
    try {
      await mailClient.saveCampaign(form);
      showToast('Kampanya kaydedildi', 'success');
      onSaved();
    } catch (error: any) {
      showToast(error.message || 'Kampanya kaydedilemedi', 'error');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Drawer open={open} title={campaign ? 'Kampanya Düzenle' : 'Kampanya Oluştur'} icon="campaign" size="compose" onClose={onClose}>
      <form onSubmit={submit} className="min-h-full flex flex-col">
        <div className="flex-1 p-7 grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_260px] gap-6">
          <div className="space-y-5">
            <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 grid grid-cols-1 md:grid-cols-2 gap-5">
              <Field label="Kampanya Adı"><input className={inputClass} value={form.campaign_name || ''} onChange={(e) => setForm({ ...form, campaign_name: e.target.value })} /></Field>
              <Field label="Konu"><input className={inputClass} value={form.subject || ''} onChange={(e) => setForm({ ...form, subject: e.target.value })} /></Field>
              <Field label="Hesap">
                <select className={inputClass} value={form.account_id || ''} onChange={(e) => setForm({ ...form, account_id: e.target.value })}>
                  <option value="">Hesap seçin</option>
                  {accounts.map((account) => <option key={account.id} value={account.id}>{account.account_name}</option>)}
                </select>
              </Field>
              <Field label="Kişi Listesi">
                <select className={inputClass} value={form.contact_list_id || ''} onChange={(e) => setForm({ ...form, contact_list_id: e.target.value })}>
                  <option value="">Liste seçin</option>
                  {lists.map((list) => <option key={list.id} value={list.id}>{list.list_name} ({list.contact_count || 0})</option>)}
                </select>
              </Field>
              <Field label="Şablon">
                <select className={inputClass} value={form.template_id || ''} onChange={(e) => applyTemplate(e.target.value)}>
                  <option value="">Şablon seçin</option>
                  {templates.map((template) => <option key={template.id} value={template.id}>{template.template_name}</option>)}
                </select>
              </Field>
              <Field label="Önizleme Metni"><input className={inputClass} value={form.preview_text || ''} onChange={(e) => setForm({ ...form, preview_text: e.target.value })} /></Field>
            </div>
            <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6">
              <Field label="HTML İçerik"><textarea className={`${textareaClass} min-h-[300px] font-mono text-[13px]`} value={form.content_html || ''} onChange={(e) => setForm({ ...form, content_html: e.target.value })} /></Field>
            </div>
          </div>
          <div className="space-y-5">
            <div className="bg-white rounded-[5px] border border-palette-tan/20 p-5 space-y-4">
              <Field label="Gönderim Hızı"><input type="number" className={inputClass} value={form.send_rate || 100} onChange={(e) => setForm({ ...form, send_rate: Number(e.target.value) })} /></Field>
              <label className="flex items-center gap-3 text-[13px] font-black text-palette-maroon"><input type="checkbox" checked={!!form.add_unsubscribe_link} onChange={(e) => setForm({ ...form, add_unsubscribe_link: e.target.checked })} /> Unsubscribe linki ekle</label>
              <label className="flex items-center gap-3 text-[13px] font-black text-palette-maroon"><input type="checkbox" checked={!!form.add_tracking_pixel} onChange={(e) => setForm({ ...form, add_tracking_pixel: e.target.checked })} /> Takip pikseli ekle</label>
            </div>
            <div className="bg-white rounded-[5px] border border-palette-tan/20 p-5">
              <p className="text-[11px] font-black text-palette-tan/50 uppercase tracking-widest mb-3">Yer Tutucular</p>
              {['{{ad}}', '{{soyad}}', '{{eposta}}', '{{unsubscribe_url}}'].map((token) => (
                <button key={token} type="button" onClick={() => setForm({ ...form, content_html: `${form.content_html || ''} ${token}` })} className="mr-2 mb-2 px-2.5 h-8 bg-palette-beige/40 rounded-[5px] text-[11px] font-black text-palette-tan hover:text-palette-maroon">{token}</button>
              ))}
            </div>
          </div>
        </div>
        <div className="h-20 px-7 bg-white border-t border-palette-tan/20 flex justify-end items-center gap-3">
          <GhostButton icon="close" onClick={onClose}>Vazgeç</GhostButton>
          <PrimaryButton type="submit" icon="save" disabled={saving}>{saving ? 'Kaydediliyor' : 'Kaydet'}</PrimaryButton>
        </div>
      </form>
    </Drawer>
  );
};

const TemplatesPage = ({ templates, refresh }: { templates: MailTemplate[]; refresh: () => void }) => {
  const { showToast } = useToast();
  const [items, setItems] = useState<MailTemplate[]>(templates);
  const [stats, setStats] = useState<any>(emptyStats);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('all');
  const [preview, setPreview] = useState<MailTemplate | null>(null);
  const [editor, setEditor] = useState<MailTemplate | null | 'new'>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ limit: '80', search, category });
      const payload = await mailClient.getTemplates(params);
      setItems(payload.items || []);
      setStats(payload.stats || emptyStats);
    } catch (error: any) {
      showToast(error.message || 'Şablonlar yüklenemedi', 'error');
    } finally {
      setLoading(false);
    }
  }, [category, search, showToast]);

  useEffect(() => {
    const timer = window.setTimeout(load, 200);
    return () => window.clearTimeout(timer);
  }, [load]);

  const remove = async (id: string) => {
    if (!window.confirm('Şablon silinsin mi?')) return;
    await mailClient.deleteTemplate(id);
    load();
    refresh();
  };

  return (
    <>
      <TableShell
        title="Şablonlar"
        icon="description"
        search={search}
        onSearch={setSearch}
        stats={[
          { label: 'Toplam', value: stats.total || 0, icon: 'description' },
          { label: 'Hazır', value: stats.ready || 0, icon: 'task_alt' },
          { label: 'Aktif', value: stats.active || 0, icon: 'toggle_on' },
          { label: 'Kategori', value: templateCategories.length, icon: 'category' },
        ]}
        actions={<PrimaryButton icon="add" onClick={() => setEditor('new')}>Yeni Şablon</PrimaryButton>}
      >
        <div className="px-7 py-4 border-b border-palette-tan/15 flex flex-wrap gap-2">
          {['all', ...templateCategories].map((item) => (
            <button key={item} onClick={() => setCategory(item)} className={`h-8 px-3 rounded-[5px] text-[11px] font-black uppercase tracking-widest ${category === item ? 'bg-palette-maroon text-white' : 'bg-palette-beige/40 text-palette-tan hover:text-palette-maroon'}`}>{item === 'all' ? 'Tümü' : item}</button>
          ))}
        </div>
        {loading ? <EmptyState icon="progress_activity" title="Şablonlar yükleniyor" description="Kayıtlar hazırlanıyor." /> : !items.length ? <EmptyState icon="description" title="Şablon yok" description="Yeni şablon oluşturun veya varsayılanları kullanın." /> : (
          <table className="w-full min-w-[980px]">
            <thead className="bg-palette-beige/30 border-b border-palette-tan/20">
              <tr className="text-[10px] font-black text-palette-tan/50 uppercase tracking-widest">
                <th className="w-[50px] px-4 py-4 text-left">Seç</th>
                <th className="w-[250px] px-3 py-4 text-left">Şablon Adı</th>
                <th className="w-[150px] px-3 py-4 text-center">Kategori</th>
                <th className="w-[120px] px-3 py-4 text-center">Değişken</th>
                <th className="w-[120px] px-3 py-4 text-center">Hazır</th>
                <th className="w-[120px] px-3 py-4 text-center">Durum</th>
                <th className="w-[160px] px-3 py-4 text-right">Tarih</th>
                <th className="w-[120px] px-4 py-4 text-right">İşlem</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-palette-tan/10">
              {items.map((template) => (
                <tr key={template.id} onClick={() => setPreview(template)} className="h-[74px] hover:bg-palette-beige/20 transition-all cursor-pointer">
                  <td className="px-4"><input type="checkbox" onClick={(event) => event.stopPropagation()} className="w-4 h-4 rounded-[5px] border-palette-tan/30 text-palette-red focus:ring-palette-red" /></td>
                  <td className="px-3">
                    <p className="text-[14px] font-black text-palette-maroon">{template.template_name}</p>
                    <p className="text-[11px] font-bold text-palette-tan/50 truncate">{plainText(template.content_html).slice(0, 80)}</p>
                  </td>
                  <td className="px-3 text-center"><span className="px-2 py-1 bg-palette-beige/50 rounded-[5px] text-[10px] font-black text-palette-tan uppercase">{template.category}</span></td>
                  <td className="px-3 text-center text-[13px] font-black text-palette-maroon">{template.variables?.length || 0}</td>
                  <td className="px-3 text-center">{template.is_ready ? <StatusBadge status="ok" /> : <StatusBadge status="draft" />}</td>
                  <td className="px-3 text-center"><StatusBadge status={template.is_active ? 'ok' : 'cancelled'} /></td>
                  <td className="px-3 text-right text-[11px] font-bold text-palette-tan">{formatDate(template.created_at)}</td>
                  <td className="px-4">
                    <div className="flex justify-end gap-1">
                      <IconButton icon="edit" onClick={() => setEditor(template)} />
                      <IconButton icon="visibility" onClick={() => setPreview(template)} />
                      <IconButton icon="delete" danger onClick={() => remove(template.id)} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </TableShell>
      <Drawer open={!!preview} title="Şablon Önizleme" icon="visibility" size="template" onClose={() => setPreview(null)}>
        {preview ? <TemplatePreview template={preview} /> : null}
      </Drawer>
      <TemplateEditor open={!!editor} template={editor === 'new' ? null : editor} onClose={() => setEditor(null)} onSaved={() => { setEditor(null); load(); refresh(); }} />
    </>
  );
};

const TemplatePreview = ({ template }: { template: MailTemplate }) => (
  <div className="p-7 space-y-5">
    <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6">
      <h3 className="text-[22px] font-black text-palette-maroon">{template.template_name}</h3>
      <p className="text-[12px] font-black text-palette-tan/50 uppercase tracking-widest mt-1">{template.category}</p>
    </div>
    <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 min-h-[420px]" dangerouslySetInnerHTML={{ __html: template.content_html }} />
  </div>
);

const TemplateEditor = ({ open, template, onClose, onSaved }: { open: boolean; template: MailTemplate | null; onClose: () => void; onSaved: () => void }) => {
  const { showToast } = useToast();
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState<any>({});

  useEffect(() => {
    if (!open) return;
    setForm({
      id: template?.id,
      template_name: template?.template_name || '',
      category: template?.category || 'kampanya',
      content_html: template?.content_html || '<h1>Başlık</h1><p>İçerik...</p>',
      variables: template?.variables || [],
      is_ready: template?.is_ready ?? false,
      is_active: template?.is_active ?? true,
    });
  }, [open, template]);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    setSaving(true);
    try {
      await mailClient.saveTemplate(form);
      showToast('Şablon kaydedildi', 'success');
      onSaved();
    } catch (error: any) {
      showToast(error.message || 'Şablon kaydedilemedi', 'error');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Drawer open={open} title={template ? 'Şablon Düzenleyici' : 'Yeni Şablon'} icon="edit_document" size="compose" onClose={onClose}>
      <form onSubmit={submit} className="min-h-full flex flex-col">
        <div className="flex-1 p-7 grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_260px] gap-6">
          <div className="space-y-5">
            <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 grid grid-cols-1 md:grid-cols-2 gap-5">
              <Field label="Şablon Adı"><input className={inputClass} value={form.template_name || ''} onChange={(e) => setForm({ ...form, template_name: e.target.value })} /></Field>
              <Field label="Kategori">
                <select className={inputClass} value={form.category || 'kampanya'} onChange={(e) => setForm({ ...form, category: e.target.value })}>
                  {templateCategories.map((category) => <option key={category} value={category}>{category}</option>)}
                </select>
              </Field>
            </div>
            <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6">
              <Field label="HTML / MJML Builder Alanı"><textarea className={`${textareaClass} min-h-[360px] font-mono text-[13px]`} value={form.content_html || ''} onChange={(e) => setForm({ ...form, content_html: e.target.value })} /></Field>
            </div>
          </div>
          <div className="space-y-5">
            <div className="bg-white rounded-[5px] border border-palette-tan/20 p-5 space-y-4">
              <label className="flex items-center gap-3 text-[13px] font-black text-palette-maroon"><input type="checkbox" checked={!!form.is_ready} onChange={(e) => setForm({ ...form, is_ready: e.target.checked })} /> Hazır</label>
              <label className="flex items-center gap-3 text-[13px] font-black text-palette-maroon"><input type="checkbox" checked={!!form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} /> Aktif</label>
            </div>
            <div className="bg-white rounded-[5px] border border-palette-tan/20 p-5">
              <p className="text-[11px] font-black text-palette-tan/50 uppercase tracking-widest mb-3">Değişkenler</p>
              {['{{ad}}', '{{soyad}}', '{{eposta}}', '{{baslik}}'].map((token) => (
                <button key={token} type="button" onClick={() => setForm({ ...form, content_html: `${form.content_html || ''} ${token}` })} className="mr-2 mb-2 px-2.5 h-8 bg-palette-beige/40 rounded-[5px] text-[11px] font-black text-palette-tan hover:text-palette-maroon">{token}</button>
              ))}
            </div>
          </div>
        </div>
        <div className="h-20 px-7 bg-white border-t border-palette-tan/20 flex justify-end items-center gap-3">
          <GhostButton icon="close" onClick={onClose}>Vazgeç</GhostButton>
          <PrimaryButton type="submit" icon="save" disabled={saving}>{saving ? 'Kaydediliyor' : 'Kaydet'}</PrimaryButton>
        </div>
      </form>
    </Drawer>
  );
};

const ContactListsPage = ({ lists, refresh }: { lists: MailContactList[]; refresh: () => void }) => {
  const { showToast } = useToast();
  const [items, setItems] = useState<MailContactList[]>(lists);
  const [stats, setStats] = useState<any>(emptyStats);
  const [search, setSearch] = useState('');
  const [importOpen, setImportOpen] = useState(false);
  const [editing, setEditing] = useState<MailContactList | null | 'new'>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const payload = await mailClient.getContactLists(new URLSearchParams({ limit: '50', search }));
      setItems(payload.items || []);
      setStats(payload.stats || emptyStats);
    } catch (error: any) {
      showToast(error.message || 'Kişi listeleri yüklenemedi', 'error');
    } finally {
      setLoading(false);
    }
  }, [search, showToast]);

  useEffect(() => {
    const timer = window.setTimeout(load, 200);
    return () => window.clearTimeout(timer);
  }, [load]);

  const remove = async (id: string) => {
    if (!window.confirm('Kişi listesi silinsin mi?')) return;
    await mailClient.deleteContactList(id);
    load();
    refresh();
  };

  return (
    <>
      <TableShell
        title="Kişi Listeleri"
        icon="contacts"
        search={search}
        onSearch={setSearch}
        stats={[
          { label: 'Liste', value: stats.lists || 0, icon: 'contacts' },
          { label: 'Kişi', value: stats.contacts || 0, icon: 'person' },
          { label: 'Sync', value: stats.synced || 0, icon: 'sync' },
          { label: 'Aktif', value: items.filter((item) => item.is_active).length, icon: 'toggle_on' },
        ]}
        actions={
          <>
            <GhostButton icon="upload_file" onClick={() => setImportOpen(true)}>İçe Aktar</GhostButton>
            <PrimaryButton icon="add" onClick={() => setEditing('new')}>Yeni Liste</PrimaryButton>
          </>
        }
      >
        {loading ? <EmptyState icon="progress_activity" title="Kişi listeleri yükleniyor" description="Kayıtlar hazırlanıyor." /> : !items.length ? <EmptyState icon="contacts" title="Liste yok" description="CSV, Excel, manuel veya bülten kaynaklarından liste oluşturun." /> : (
          <table className="w-full min-w-[980px]">
            <thead className="bg-palette-beige/30 border-b border-palette-tan/20">
              <tr className="text-[10px] font-black text-palette-tan/50 uppercase tracking-widest">
                <th className="w-[50px] px-4 py-4 text-left">Seç</th>
                <th className="w-[250px] px-3 py-4 text-left">Liste Adı</th>
                <th className="px-3 py-4 text-left">Açıklama</th>
                <th className="w-[120px] px-3 py-4 text-center">Kişi</th>
                <th className="w-[120px] px-3 py-4 text-center">Sync</th>
                <th className="w-[120px] px-3 py-4 text-center">Durum</th>
                <th className="w-[160px] px-3 py-4 text-right">Tarih</th>
                <th className="w-[120px] px-4 py-4 text-right">İşlem</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-palette-tan/10">
              {items.map((list) => (
                <tr key={list.id} className="h-[74px] hover:bg-palette-beige/20 transition-all">
                  <td className="px-4"><input type="checkbox" className="w-4 h-4 rounded-[5px] border-palette-tan/30 text-palette-red focus:ring-palette-red" /></td>
                  <td className="px-3 text-[14px] font-black text-palette-maroon">{list.list_name}</td>
                  <td className="px-3 text-[12px] font-bold text-palette-tan/60">{list.description || '-'}</td>
                  <td className="px-3 text-center text-[14px] font-black text-palette-maroon">{list.contact_count || 0}</td>
                  <td className="px-3 text-center"><StatusBadge status={list.auto_sync ? 'ok' : 'draft'} /></td>
                  <td className="px-3 text-center"><StatusBadge status={list.is_active ? 'ok' : 'cancelled'} /></td>
                  <td className="px-3 text-right text-[11px] font-bold text-palette-tan">{formatDate(list.created_at)}</td>
                  <td className="px-4">
                    <div className="flex justify-end gap-1">
                      <IconButton icon="edit" onClick={() => setEditing(list)} />
                      <IconButton icon="delete" danger onClick={() => remove(list.id)} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </TableShell>
      <ContactListDialog open={!!editing} list={editing === 'new' ? null : editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); load(); refresh(); }} />
      <ImportDialog open={importOpen} lists={items} onClose={() => setImportOpen(false)} onImported={() => { setImportOpen(false); load(); refresh(); }} />
    </>
  );
};

const ContactListDialog = ({ open, list, onClose, onSaved }: { open: boolean; list: MailContactList | null; onClose: () => void; onSaved: () => void }) => {
  const { showToast } = useToast();
  const [form, setForm] = useState<any>({});

  useEffect(() => {
    if (!open) return;
    setForm({ id: list?.id, list_name: list?.list_name || '', description: list?.description || '', auto_sync: list?.auto_sync || false, is_active: list?.is_active ?? true });
  }, [list, open]);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    try {
      await mailClient.saveContactList(form);
      showToast('Kişi listesi kaydedildi', 'success');
      onSaved();
    } catch (error: any) {
      showToast(error.message || 'Liste kaydedilemedi', 'error');
    }
  };

  return (
    <Drawer open={open} title={list ? 'Liste Düzenle' : 'Yeni Liste'} icon="contacts" size="detail" onClose={onClose}>
      <form onSubmit={submit} className="p-7 space-y-5">
        <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 space-y-5">
          <Field label="Liste Adı"><input className={inputClass} value={form.list_name || ''} onChange={(e) => setForm({ ...form, list_name: e.target.value })} /></Field>
          <Field label="Açıklama"><textarea className={textareaClass} value={form.description || ''} onChange={(e) => setForm({ ...form, description: e.target.value })} /></Field>
          <label className="flex items-center gap-3 text-[13px] font-black text-palette-maroon"><input type="checkbox" checked={!!form.auto_sync} onChange={(e) => setForm({ ...form, auto_sync: e.target.checked })} /> Otomatik Sync</label>
          <label className="flex items-center gap-3 text-[13px] font-black text-palette-maroon"><input type="checkbox" checked={!!form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} /> Aktif</label>
        </div>
        <div className="flex justify-end gap-3">
          <GhostButton icon="close" onClick={onClose}>Vazgeç</GhostButton>
          <PrimaryButton type="submit" icon="save">Kaydet</PrimaryButton>
        </div>
      </form>
    </Drawer>
  );
};

const ImportDialog = ({ open, lists, onClose, onImported }: { open: boolean; lists: MailContactList[]; onClose: () => void; onImported: () => void }) => {
  const { showToast } = useToast();
  const [source, setSource] = useState('manual');
  const [listId, setListId] = useState('');
  const [listName, setListName] = useState('İçe Aktarılan Kişiler');
  const [text, setText] = useState('');
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    setSaving(true);
    try {
      const payload = await mailClient.importContacts({ source, list_id: listId, list_name: listName, text });
      showToast(`${payload.valid || 0} kişi işlendi`, 'success');
      onImported();
    } catch (error: any) {
      showToast(error.message || 'İçe aktarma başarısız', 'error');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Drawer open={open} title="Kişi Listesi İçe Aktar" icon="upload_file" size="compose" onClose={onClose}>
      <div className="p-7 grid grid-cols-1 lg:grid-cols-[236px_minmax(0,1fr)_244px] gap-6">
        <div className="bg-white rounded-[5px] border border-palette-tan/20 p-4 space-y-2 h-fit">
          {[
            { id: 'manual', label: 'Manuel', icon: 'edit' },
            { id: 'csv', label: 'CSV / Excel', icon: 'table' },
            { id: 'newsletter', label: 'Bülten', icon: 'subscriptions' },
            { id: 'cari_disabled', label: 'Cari', icon: 'business', disabled: true },
          ].map((item) => (
            <button
              key={item.id}
              disabled={item.disabled}
              onClick={() => !item.disabled && setSource(item.id)}
              className={`w-full h-11 rounded-[5px] px-3 flex items-center gap-3 text-[13px] font-black transition-all ${source === item.id ? 'bg-palette-maroon text-white' : 'text-palette-tan hover:bg-palette-beige hover:text-palette-maroon disabled:opacity-35 disabled:hover:bg-transparent'}`}
            >
              <Icon name={item.icon} size={18} />
              {item.label}
            </button>
          ))}
        </div>
        <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 space-y-5">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <Field label="Hedef Liste">
              <select className={inputClass} value={listId} onChange={(e) => setListId(e.target.value)}>
                <option value="">Yeni liste oluştur</option>
                {lists.map((list) => <option key={list.id} value={list.id}>{list.list_name}</option>)}
              </select>
            </Field>
            {!listId ? <Field label="Yeni Liste Adı"><input className={inputClass} value={listName} onChange={(e) => setListName(e.target.value)} /></Field> : null}
          </div>
          {source === 'newsletter' ? (
            <div className="rounded-[5px] bg-palette-beige/30 border border-palette-tan/20 p-6 text-[13px] font-bold text-palette-tan">Aktif bülten aboneleri hedef listeye aktarılacak.</div>
          ) : (
            <Field label="Veri">
              <textarea className={`${textareaClass} min-h-[320px] font-mono text-[13px]`} value={text} onChange={(e) => setText(e.target.value)} placeholder="Ad Soyad; eposta@ornek.com; 0555..." />
            </Field>
          )}
        </div>
        <div className="bg-white rounded-[5px] border border-palette-tan/20 p-5 h-fit space-y-4">
          <h4 className="text-[13px] font-black text-palette-maroon">Başlamadan Önce</h4>
          <p className="text-[12px] font-bold text-palette-tan/60 leading-relaxed">Manuel, CSV/Excel ve bülten kaynakları aktiftir. Cari aktarım kaynağı şu anda pasif.</p>
          <PrimaryButton icon="download_done" onClick={submit} disabled={saving}>{saving ? 'Aktarılıyor' : 'İçe Aktar'}</PrimaryButton>
        </div>
      </div>
    </Drawer>
  );
};

const MailSettingsPage = ({ accounts, refresh }: { accounts: MailAccount[]; refresh: () => void }) => {
  const { showToast } = useToast();
  const [editing, setEditing] = useState<MailAccount | null | 'new'>(null);
  const [dns, setDns] = useState<any[] | null>(null);

  const remove = async (id: string) => {
    if (!window.confirm('Posta hesabı silinsin mi?')) return;
    await mailClient.deleteAccount(id);
    refresh();
  };

  const checkDns = async (account: MailAccount) => {
    try {
      const payload = await mailClient.checkDns(account.id);
      setDns(payload.checklist || []);
      showToast('DNS kontrol listesi hazırlandı', 'success');
    } catch (error: any) {
      showToast(error.message || 'DNS kontrolü yapılamadı', 'error');
    }
  };

  return (
    <>
      <TableShell
        title="Ayarlar"
        icon="settings"
        stats={[
          { label: 'Hesap', value: accounts.length, icon: 'mail' },
          { label: 'Aktif', value: accounts.filter((account) => account.is_active).length, icon: 'toggle_on' },
          { label: 'SMTP', value: accounts.filter((account) => account.sending_mode === 'smtp').length, icon: 'settings_ethernet' },
          { label: 'IMAP', value: accounts.filter((account) => account.receiving_enabled).length, icon: 'inbox' },
        ]}
        actions={
          <>
            <GhostButton icon="refresh" onClick={refresh}>Yenile</GhostButton>
            <PrimaryButton icon="add" onClick={() => setEditing('new')}>Hesap Ekle</PrimaryButton>
          </>
        }
      >
        {!accounts.length ? <EmptyState icon="settings" title="Posta hesabı yok" description="SMTP/API hesabı ekleyerek gönderim ve alım ayarlarını başlatın." /> : (
          <table className="w-full min-w-[1120px]">
            <thead className="bg-palette-beige/30 border-b border-palette-tan/20">
              <tr className="text-[10px] font-black text-palette-tan/50 uppercase tracking-widest">
                <th className="w-[50px] px-4 py-4 text-left">Seç</th>
                <th className="w-[220px] px-3 py-4 text-left">Hesap</th>
                <th className="w-[220px] px-3 py-4 text-left">Gönderen</th>
                <th className="w-[150px] px-3 py-4 text-center">Servis</th>
                <th className="w-[160px] px-3 py-4 text-center">Domain</th>
                <th className="w-[110px] px-3 py-4 text-center">Limit</th>
                <th className="w-[110px] px-3 py-4 text-center">DNS</th>
                <th className="w-[120px] px-3 py-4 text-center">Durum</th>
                <th className="w-[120px] px-4 py-4 text-right">İşlem</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-palette-tan/10">
              {accounts.map((account) => (
                <tr key={account.id} className="h-[74px] hover:bg-palette-beige/20 transition-all">
                  <td className="px-4"><input type="checkbox" className="w-4 h-4 rounded-[5px] border-palette-tan/30 text-palette-red focus:ring-palette-red" /></td>
                  <td className="px-3 text-[14px] font-black text-palette-maroon">{account.account_name}</td>
                  <td className="px-3">
                    <p className="text-[13px] font-black text-palette-maroon">{account.sender_name || '-'}</p>
                    <p className="text-[11px] font-bold text-palette-tan/50">{account.sender_email}</p>
                  </td>
                  <td className="px-3 text-center text-[12px] font-black text-palette-tan">{providerLabels[account.service_type] || account.service_type}</td>
                  <td className="px-3 text-center text-[12px] font-bold text-palette-tan">{account.sender_email?.split('@')[1] || '-'}</td>
                  <td className="px-3 text-center text-[12px] font-black text-palette-maroon">{account.sent_today || 0}/{account.daily_limit || 0}</td>
                  <td className="px-3 text-center"><StatusBadge status={account.spf_registered && account.dkim_registered && account.dmarc_registered ? 'ok' : 'draft'} /></td>
                  <td className="px-3 text-center"><StatusBadge status={account.connection_status || 'not_tested'} /></td>
                  <td className="px-4">
                    <div className="flex justify-end gap-1">
                      <IconButton icon="dns" onClick={() => checkDns(account)} />
                      <IconButton icon="edit" onClick={() => setEditing(account)} />
                      <IconButton icon="delete" danger onClick={() => remove(account.id)} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </TableShell>
      {dns ? (
        <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6">
          <div className="flex items-center justify-between mb-5">
            <h3 className="text-[16px] font-black text-palette-maroon">DNS Yapılandırma</h3>
            <IconButton icon="close" onClick={() => setDns(null)} />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {dns.map((record, index) => (
              <div key={index} className="rounded-[5px] border border-palette-tan/20 bg-palette-beige/20 p-4">
                <p className="text-[12px] font-black text-palette-red mb-2">{record.type}</p>
                <p className="text-[11px] font-black text-palette-tan/50 uppercase">Host</p>
                <p className="text-[12px] font-bold text-palette-maroon break-all mb-3">{record.host}</p>
                <p className="text-[11px] font-black text-palette-tan/50 uppercase">Value</p>
                <p className="text-[12px] font-bold text-palette-maroon break-all">{record.value}</p>
              </div>
            ))}
          </div>
        </div>
      ) : null}
      <AccountDialog open={!!editing} account={editing === 'new' ? null : editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); refresh(); }} />
    </>
  );
};

const AccountDialog = ({ open, account, onClose, onSaved }: { open: boolean; account: MailAccount | null; onClose: () => void; onSaved: () => void }) => {
  const { showToast } = useToast();
  const [form, setForm] = useState<any>({});
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) return;
    setForm({
      id: account?.id,
      account_name: account?.account_name || '',
      sender_name: account?.sender_name || '',
      sender_email: account?.sender_email || '',
      service_type: account?.service_type || 'smtp_generic',
      sending_mode: account?.sending_mode || 'smtp',
      smtp_host: account?.smtp_host || '',
      smtp_port: account?.smtp_port || 587,
      smtp_username: account?.smtp_username || '',
      smtp_secure: account?.smtp_secure || 'starttls',
      receiving_enabled: account?.receiving_enabled || false,
      imap_host: account?.imap_host || '',
      imap_port: account?.imap_port || 993,
      imap_username: account?.imap_username || '',
      daily_limit: account?.daily_limit || 500,
      monthly_limit: account?.monthly_limit || 15000,
      hourly_limit: account?.hourly_limit || 100,
      default_signature: account?.default_signature || '',
      default_reply_to: account?.default_reply_to || '',
      is_active: account?.is_active ?? true,
    });
  }, [account, open]);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    setSaving(true);
    try {
      await mailClient.saveAccount(form);
      showToast('Posta hesabı kaydedildi', 'success');
      onSaved();
    } catch (error: any) {
      showToast(error.message || 'Hesap kaydedilemedi', 'error');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Drawer open={open} title={account ? 'Hesap Düzenle' : 'Hesap Ekle'} icon="settings" size="compose" onClose={onClose}>
      <form onSubmit={submit} className="min-h-full flex flex-col">
        <div className="flex-1 p-7 space-y-6">
          <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 grid grid-cols-1 md:grid-cols-2 gap-5">
            <Field label="Hesap Adı"><input className={inputClass} value={form.account_name || ''} onChange={(e) => setForm({ ...form, account_name: e.target.value })} /></Field>
            <Field label="Servis">
              <select className={inputClass} value={form.service_type || 'smtp_generic'} onChange={(e) => setForm({ ...form, service_type: e.target.value })}>
                {providerOptions.map((provider) => <option key={provider.id} value={provider.id}>{provider.label}</option>)}
              </select>
            </Field>
            <Field label="Gönderen Adı"><input className={inputClass} value={form.sender_name || ''} onChange={(e) => setForm({ ...form, sender_name: e.target.value })} /></Field>
            <Field label="Gönderen E-posta"><input className={inputClass} value={form.sender_email || ''} onChange={(e) => setForm({ ...form, sender_email: e.target.value })} /></Field>
          </div>
          <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 space-y-5">
            <h4 className="text-[13px] font-black text-palette-maroon uppercase tracking-widest">SMTP / API</h4>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
              <Field label="Mod">
                <select className={inputClass} value={form.sending_mode || 'smtp'} onChange={(e) => setForm({ ...form, sending_mode: e.target.value })}>
                  <option value="smtp">SMTP</option>
                  <option value="api">API</option>
                  <option value="sendmail">Sendmail</option>
                </select>
              </Field>
              <Field label="SMTP Sunucu"><input className={inputClass} value={form.smtp_host || ''} onChange={(e) => setForm({ ...form, smtp_host: e.target.value })} /></Field>
              <Field label="SMTP Port"><input type="number" className={inputClass} value={form.smtp_port || ''} onChange={(e) => setForm({ ...form, smtp_port: Number(e.target.value) })} /></Field>
              <Field label="SMTP Kullanıcı"><input className={inputClass} value={form.smtp_username || ''} onChange={(e) => setForm({ ...form, smtp_username: e.target.value })} /></Field>
              <Field label={account?.has_smtp_password ? 'SMTP Şifre (değiştirmek için yazın)' : 'SMTP Şifre'}><input type="password" className={inputClass} value={form.smtp_password || ''} onChange={(e) => setForm({ ...form, smtp_password: e.target.value })} /></Field>
              <Field label="Güvenlik">
                <select className={inputClass} value={form.smtp_secure || 'starttls'} onChange={(e) => setForm({ ...form, smtp_secure: e.target.value })}>
                  <option value="starttls">STARTTLS</option>
                  <option value="ssl">SSL</option>
                  <option value="none">Yok</option>
                </select>
              </Field>
              <Field label={account?.has_api_key ? 'API Anahtarı (değiştirmek için yazın)' : 'API Anahtarı'}><input type="password" className={inputClass} value={form.api_key || ''} onChange={(e) => setForm({ ...form, api_key: e.target.value })} /></Field>
              <Field label={account?.has_api_token ? 'API Token (değiştirmek için yazın)' : 'API Token'}><input type="password" className={inputClass} value={form.api_token || ''} onChange={(e) => setForm({ ...form, api_token: e.target.value })} /></Field>
              <Field label="Reply-To"><input className={inputClass} value={form.default_reply_to || ''} onChange={(e) => setForm({ ...form, default_reply_to: e.target.value })} /></Field>
            </div>
          </div>
          <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 space-y-5">
            <div className="flex items-center gap-3">
              <input type="checkbox" checked={!!form.receiving_enabled} onChange={(e) => setForm({ ...form, receiving_enabled: e.target.checked })} />
              <h4 className="text-[13px] font-black text-palette-maroon uppercase tracking-widest">IMAP Alım Aktif</h4>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-5">
              <Field label="IMAP Sunucu"><input className={inputClass} value={form.imap_host || ''} onChange={(e) => setForm({ ...form, imap_host: e.target.value })} /></Field>
              <Field label="IMAP Port"><input type="number" className={inputClass} value={form.imap_port || ''} onChange={(e) => setForm({ ...form, imap_port: Number(e.target.value) })} /></Field>
              <Field label="IMAP Kullanıcı"><input className={inputClass} value={form.imap_username || ''} onChange={(e) => setForm({ ...form, imap_username: e.target.value })} /></Field>
              <Field label={account?.has_imap_password ? 'IMAP Şifre (değiştirmek için yazın)' : 'IMAP Şifre'}><input type="password" className={inputClass} value={form.imap_password || ''} onChange={(e) => setForm({ ...form, imap_password: e.target.value })} /></Field>
            </div>
          </div>
          <div className="bg-white rounded-[5px] border border-palette-tan/20 p-6 grid grid-cols-1 md:grid-cols-4 gap-5">
            <Field label="Günlük Limit"><input type="number" className={inputClass} value={form.daily_limit || ''} onChange={(e) => setForm({ ...form, daily_limit: Number(e.target.value) })} /></Field>
            <Field label="Aylık Limit"><input type="number" className={inputClass} value={form.monthly_limit || ''} onChange={(e) => setForm({ ...form, monthly_limit: Number(e.target.value) })} /></Field>
            <Field label="Saatlik Limit"><input type="number" className={inputClass} value={form.hourly_limit || ''} onChange={(e) => setForm({ ...form, hourly_limit: Number(e.target.value) })} /></Field>
            <label className="flex items-center gap-3 text-[13px] font-black text-palette-maroon pt-7"><input type="checkbox" checked={!!form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} /> Aktif</label>
          </div>
        </div>
        <div className="h-20 px-7 bg-white border-t border-palette-tan/20 flex justify-end items-center gap-3">
          <GhostButton icon="close" onClick={onClose}>Vazgeç</GhostButton>
          <PrimaryButton type="submit" icon="save" disabled={saving}>{saving ? 'Kaydediliyor' : 'Kaydet'}</PrimaryButton>
        </div>
      </form>
    </Drawer>
  );
};

export default MailModule;
