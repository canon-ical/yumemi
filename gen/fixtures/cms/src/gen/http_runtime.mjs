//// GENERATED from entry.entries / service declarations / framework dispatch [sha256:3e10e3ef3932] — 手で編集しない
import { Ok, Error } from '../gleam.mjs';
import { registry } from './registry.mjs';
import { attached } from './attached.mjs';
import * as c from './codec.mjs';
import * as runtime from './runtime.mjs';
import { http } from '../../yumemi/yumemi/server/http.mjs';
import { attachedFixtureBrowser as h_attachedFixtureBrowser } from '../hooks.mjs';
import { attachedFixtureSync as h_attachedFixtureSync } from '../hooks.mjs';
import { attachedBlobCopy as h_attachedBlobCopy } from '../hooks.mjs';
import { attachedFixtureMedia as h_attachedFixtureMedia } from '../hooks.mjs';
const hosts={public:'PUBLIC_HOST',admin:'ADMIN_HOST'};
const args={
 article_blob_save:[['slug',['scalar','slug']],['blob',['blob']],['existing',['option',['blob']]]],
 article_create:[['slug',['scalar','slug']],['title',['scalar','title']],['body',['scalar','body']],['category',['key']],['tags',['list',['key']]]],
 article_list:[['limit',['integer']],['cursor',['option',['cursor']]]],
 article_publish:[['slug',['scalar','slug']]],
 article_read:[['slug',['scalar','slug']]],
 article_retract:[['slug',['scalar','slug']]],
 page_resolve:[['path',['text']]],
 widget_list:[['widget',['option',['text']]],['slug',['option',['text']]]],
};
const modules={};
const phaseGates={};
const accepted={article_create:'article',article_publish:'article',article_read:'article',article_retract:'article'};
const ports={fixture_browser:h_attachedFixtureBrowser,fixture_sync:h_attachedFixtureSync,blob_copy:h_attachedBlobCopy,fixture_media:h_attachedFixtureMedia};
const hooks={};
const subjects=[];
const roles={fixture_session:['read_session'],fixture_declare:['declare:adult'],fixture_media:['needs_declared:adult']};
const browserCookie={cookie:'_fx',binding:'FIXTURE_BROWSER_KEY',maxAgeDays:400,declarations:[{kind:'adult',claim:'adult_declared_at',maxAgeDays:395},{kind:'region',claim:'region_declared_at',maxAgeDays:30}]};
const pageviews={'public':{only:[{type:'declared',kind:'adult'}],fields:[{type:'kind'},{type:'client_at'},{type:'path'},{type:'previous'},{type:'referrer'},{type:'query',name:'source_key',max:16}],sink:{type:'store',resolve:'page_resolve',rollupBy:['section'],excludeWhen:['own']}}};
const subjectFree=[];
const keyPattern='[0-9a-f]{64}';
export const {sessionCookie,cookies,signBrowser,verifyBrowser,host,route,origin,browser,admit,resolve,subject,decode,judge,execute,apiEncode,logicFailureStatus}=http({Ok,Error,registry,attached,c,runtime,hosts,args,modules,phaseGates,accepted,ports,hooks,subjects,roles,browserCookie,pageviews,subjectFree,apiKeyPattern:keyPattern});
