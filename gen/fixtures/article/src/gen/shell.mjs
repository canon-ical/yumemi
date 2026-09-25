//// GENERATED from entry.entries / server.gleam / framework Cloudflare adapter [sha256:032d56dd277b] — 手で編集しない
import { handlers, appSystem, durableObject } from '../../yumemi/framework/server/worker.mjs';
import { database } from '../../yumemi/framework/server/driver.mjs';
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
  execution.waitUntil(sweep(db,env));
 }
};
export const AppSystem=appSystem({database,observe,issueSession,revokeParty,resolveSession,run});
