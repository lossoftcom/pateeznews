import astroWorker from '@astrojs/cloudflare/entrypoints/server';
import { runAnnouncementsRefresh } from './lib/server/announcementsData';

const handler = astroWorker as {
  fetch: ExportedHandlerFetchHandler;
};

export default {
  fetch: handler.fetch,
  scheduled(_controller, _env, ctx) {
    ctx.waitUntil(
      runAnnouncementsRefresh({
        runType: 'cron',
        discoverSources: true,
      }).catch((error) => {
        console.error('announcement cron failed', error);
      })
    );
  },
} satisfies ExportedHandler;
