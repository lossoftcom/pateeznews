import astroWorker from '@astrojs/cloudflare/entrypoints/server';
import { runAnnouncementsRefresh } from './lib/server/announcementsData';
import { runAutomaticNewsRefresh } from './lib/server/automaticNewsData';
import { processMailCampaigns } from './lib/server/mail/campaignProcessor';
import { processNotificationOutbox } from './lib/server/notifications/processor';

const handler = astroWorker as {
  fetch: ExportedHandlerFetchHandler;
};

export default {
  fetch: handler.fetch,
  scheduled(controller, _env, ctx) {
    if (controller.cron === '*/5 * * * *') {
      ctx.waitUntil(
        processMailCampaigns().catch((error) => {
          console.error('mail campaign cron failed', error);
        })
      );
      ctx.waitUntil(
        processNotificationOutbox().catch((error) => {
          console.error('notification outbox cron failed', error);
        })
      );
      ctx.waitUntil(
        runAutomaticNewsRefresh({
          runType: 'cron',
        }).catch((error) => {
          console.error('automatic news cron failed', error);
        })
      );
    }
    if (controller.cron === '*/30 * * * *') {
      ctx.waitUntil(
        runAnnouncementsRefresh({
          runType: 'cron',
          discoverSources: true,
        }).catch((error) => {
          console.error('announcement cron failed', error);
        })
      );
    }
  },
} satisfies ExportedHandler;
