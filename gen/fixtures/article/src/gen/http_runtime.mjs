//// GENERATED from entry.entries / service declarations / framework dispatch [sha256:032d56dd277b] — 手で編集しない
import { Ok, Error } from '../gleam.mjs';
import { registry } from './registry.mjs';
import { attached } from './attached.mjs';
import * as c from './codec.mjs';
import * as runtime from './runtime.mjs';
import { http } from '../../yumemi/framework/server/http.mjs';
import { attachedFixtureBrowser as h_attachedFixtureBrowser } from '../hooks.mjs';
import { attachedFixtureSync as h_attachedFixtureSync } from '../hooks.mjs';
import { attachedBlobCopy as h_attachedBlobCopy } from '../hooks.mjs';
const hosts={public:'PUBLIC_HOST',admin:'ADMIN_HOST'};
const args={
 article_blob_save:[['slug',['scalar','slug']],['blob',['blob']],['existing',['option',['blob']]]],
 article_create:[['slug',['scalar','slug']],['title',['scalar','title']],['body',['scalar','body']],['category',['key']],['tags',['list',['key']]]],
 article_list:[['limit',['integer']],['cursor',['option',['cursor']]]],
 article_publish:[['slug',['scalar','slug']]],
 article_read:[['slug',['scalar','slug']]],
 article_retract:[['slug',['scalar','slug']]],
 widget_list:[['widget',['option',['text']]],['slug',['option',['text']]]],
};
const modules={};
const phaseGates={};
const accepted={article_create:'article',article_publish:'article',article_read:'article',article_retract:'article'};
const ports={fixture_browser:h_attachedFixtureBrowser,fixture_sync:h_attachedFixtureSync,blob_copy:h_attachedBlobCopy};
const hooks={};
const subjects=[];
const roles={};
const browserCookie=null;
const keyPattern='[0-9a-f]{64}';
export const {sessionCookie,cookies,signBrowser,verifyBrowser,host,route,origin,browser,admit,resolve,subject,decode,judge,execute,apiEncode,logicFailureStatus}=http({Ok,Error,registry,attached,c,runtime,hosts,args,modules,phaseGates,accepted,ports,hooks,subjects,roles,browserCookie,apiKeyPattern:keyPattern});
