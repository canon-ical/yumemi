//// GENERATED from entry.entries / server.gleam / framework Cloudflare adapter [sha256:6a5b1b1c95d8] — 手で編集しない
import { handlers, appSystem, durableObject } from '../../yumemi/yumemi/server/worker.mjs';
import { purgeIdempotency, rollupPageviews } from '../../yumemi/yumemi/server/cron.mjs';
import { database } from '../../yumemi/yumemi/server/driver.mjs';
import { dispatch } from './entry/http.mjs';
import { issueSession,resolveSession,revokeParty,run } from './runtime.mjs';
import { sweep,consume } from './queue_runtime.mjs';
const observe=event=>console.log(JSON.stringify({component:'database',...event}));
const worker=handlers({dispatch,database,observe,sweep,consume});
export default {
 fetch: worker.fetch,
 queue: worker.queue,
 async scheduled(controller,env,execution) {
  const db=database(env,observe);
  execution.waitUntil(purgeIdempotency({db,env,run}));
  if(controller.cron==='0 1 * * *') execution.waitUntil(rollupPageviews({db,run}));
  execution.waitUntil(sweep(db,env));
 }
};
export const AppSystem=appSystem({database,observe,issueSession,revokeParty,resolveSession,run});
export { YumemiLive } from '../../yumemi/yumemi/server/worker.mjs';
