//// GENERATED from entry.entries / service declarations / framework dispatch [sha256:54f6b8da8abb] — 手で編集しない
import { Ok, Error } from '../gleam.mjs';
import { registry } from './registry.mjs';
import { attached } from './attached.mjs';
import * as c from './codec.mjs';
import * as runtime from './runtime.mjs';
import { http } from '../../yumemi/yumemi/server/http.mjs';
const hosts={api:'API_HOST'};
const args={
 note_create:[['title',['scalar','note_title']],['body',['scalar','note_body']]],
 note_delete:[['id',['scalar','note_id']]],
 note_edit:[['id',['scalar','note_id']],['title',['scalar','note_title']],['body',['scalar','note_body']]],
 note_list:[['limit',['integer']],['cursor',['option',['cursor']]]],
 note_read:[['id',['scalar','note_id']]],
};
const modules={};
const phaseGates={};
const accepted={note_delete:'note',note_edit:'note',note_read:'note'};
const ports={};
const hooks={};
const subjects=[];
const roles={};
const browserCookie=null;
const pageviews={};
const subjectFree=[];
const keyPattern='[0-9a-f]{64}';
export const {sessionCookie,cookies,signBrowser,verifyBrowser,host,route,origin,browser,admit,resolve,subject,decode,judge,execute,apiEncode,logicFailureStatus}=http({Ok,Error,registry,attached,c,runtime,hosts,args,modules,phaseGates,accepted,ports,hooks,subjects,roles,browserCookie,pageviews,subjectFree,apiKeyPattern:keyPattern});
