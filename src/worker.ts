import astroWorker from '@astrojs/cloudflare/entrypoints/server';
import { runAnnouncementsRefresh } from './lib/server/announcementsData';
import {
  dispatchAutomaticNewsDueSources,
  processAutomaticNewsQueueBatch,
  type AutomaticNewsQueueMessage,
} from './lib/server/automaticNewsData';
import { processMailCampaigns } from './lib/server/mail/campaignProcessor';
import { processNotificationOutbox } from './lib/server/notifications/processor';

const handler = astroWorker as {
  fetch: ExportedHandlerFetchHandler;
};

interface Env {
  AUTOMATIC_NEWS_QUEUE?: Queue<AutomaticNewsQueueMessage>;
}

export default {
  fetch: handler.fetch,
  scheduled(controller, env, ctx) {
    if (controller.cron === '* * * * *') {
      ctx.waitUntil(
        dispatchAutomaticNewsDueSources({
          queue: env.AUTOMATIC_NEWS_QUEUE,
          runType: 'cron',
        }).catch((error) => {
          console.error('automatic news dispatcher failed', error);
        })
      );
    } else if (controller.cron === '*/5 * * * *') {
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
  async queue(batch) {
    await processAutomaticNewsQueueBatch(batch);
  },
} satisfies ExportedHandler<Env, AutomaticNewsQueueMessage>;
