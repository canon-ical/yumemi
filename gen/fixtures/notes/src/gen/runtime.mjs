//// GENERATED from service Logic / verb / reads / outbox contracts [sha256:54f6b8da8abb] — 手で編集しない
import { SQL } from './sql.mjs';
import * as c from './codec.mjs';
import { runtime } from '../../yumemi/yumemi/server/runtime.mjs';
import * as allow_note from './allow/note.mjs';
import * as draft_note from './draft/note.mjs';
const roots={
 note_delete:{sql:'note_delete/root',params:['arg:id'],values:['entity:note']},
 note_edit:{sql:'note_edit/root',params:['arg:id'],values:['entity:note']},
 note_read:{sql:'note_read/root',params:['arg:id'],values:['entity:note']},
};
const actors={
 note_create:{kind:'sum',module:allow_note,variants:[],party:false,any:true},
 note_delete:{kind:'sum',module:allow_note,variants:[],party:false,any:true},
 note_edit:{kind:'sum',module:allow_note,variants:[],party:false,any:true},
 note_list:{kind:'sum',module:allow_note,variants:[],party:false,any:true},
 note_read:{kind:'sum',module:allow_note,variants:[],party:false,any:true},
};
const verbs={
 create_note:{key:'verb/create_note',tuple:false,params:[['id'],['f','title','note_title'],['f','body','note_body'],['f','created_at',null]],created:['note','NoteCreated',['id','title','body','created_at'],'note_id']},
 update_note_created_at:{key:'verb/update_note_created_at',tuple:true,params:[['a',0,'note_id'],['a',1,null]]},
 edit_note:{key:'verb/edit_note',tuple:true,params:[['a',0,'note_id'],['a',1,'note_title'],['a',2,'note_body']]},
 delete_note:{key:'verb/delete_note',tuple:false,params:[['a',0,'note_id']]},
};
const manualVerbs={names:new Set([]),stage:()=>{throw new Error('no manual verb')}};
const reads={
 'note_list/items':{key:'note_list/items',args:[['enc'],['cursor']],allow:[],out:['page',['entity','note']],keyset:{size:20,sizeArg:0,sizeField:'limit',uniform:true,columns:[['created_at','timestamptz'],['id','value']]}},
};
const readAliases={
};
const connectors={
};
const connectorNames={};
const folds={
};
const enqueues={
};
const boundaries=new Set([]);
function rootKey(root) {
 const first=Object.values(root??{})[0];
 return c.text(first?.id);
}
const relationDecoders={note:c.decodeNote};
const phaseModules={note:c.note};
const drafts={note:draft_note};
const subjects=[];
const encoders={};
const carried={
};
const labels={apiKeyLabel:null,claimLabel:null};
export const {statement,run,step,seededId,labeledHmac,apiKeyHmac,claimHmac,resolveSession,resolveApiKey,issueSession,revokeParty,connectorFailureDiagnostic,actorFor,loadRoot,makeContext,invoke}=runtime({SQL,c,cursorArgs:c.cursorArgs,roots,actors,verbs,manualVerbs,reads,readAliases,connectors,connectorNames,folds,enqueues,boundaries,relationDecoders,phaseModules,drafts,subjects,encoders,carried,...labels});
