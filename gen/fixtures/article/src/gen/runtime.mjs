//// GENERATED from service Logic / verb / reads / outbox contracts [sha256:032d56dd277b] — 手で編集しない
import { SQL } from './sql.mjs';
import * as c from './codec.mjs';
import * as subject from './subject.mjs';
import { runtime } from '../../yumemi/framework/server/runtime.mjs';
import * as allow_article from './allow/article.mjs';
import * as draft_article from './draft/article.mjs';
import * as draft_category from './draft/category.mjs';
import * as draft_staff from './draft/staff.mjs';
import * as draft_tag from './draft/tag.mjs';
const roots={
 article_create:{sql:null,params:[],values:['entity:article','phase:article']},
 article_publish:{sql:null,params:[],values:['entity:article','phase:article']},
 article_read:{sql:null,params:[],values:['entity:article','phase:article']},
 article_retract:{sql:null,params:[],values:['entity:article','phase:article']},
};
const actors={
 article_blob_save:{kind:'sum',module:allow_article,variants:[['staff','StaffActor']],party:false,any:true},
 article_create:{kind:'direct',subject:'staff'},
 article_list:{kind:'sum',module:allow_article,variants:[['staff','StaffActor']],party:false,any:true},
 article_publish:{kind:'direct',subject:'staff'},
 article_read:{kind:'sum',module:allow_article,variants:[['staff','StaffActor']],party:false,any:true},
 article_retract:{kind:'direct',subject:'staff'},
 widget_list:{kind:'sum',module:allow_article,variants:[['staff','StaffActor']],party:false,any:true},
};
const verbs={
 create_article:{key:'verb/create_article',tuple:false,params:[['id'],['f','title','title'],['f','body','body'],['f','version',null],['f','category',null],['at']],created:['article','ArticleCreated',['id','title','body','version','=order','category'],'slug'],before:[['verb/create_article_lock',[['f','category',null]]]]},
 delete_article_by_title:{key:'verb/delete_article_by_title',tuple:false,params:[['a',0,'title']]},
 create_articles:{key:'verb/create_articles',tuple:true,params:[['ja',0],['a',1,null]]},
 update_article_body:{key:'verb/update_article_body',tuple:true,params:[['a',0,'slug'],['a',1,null],['a',2,'body']]},
 update_article_order:{key:'verb/update_article_order',tuple:true,params:[['a',0,'slug'],['a',1,null],['a',2,null]]},
 pin_article:{key:'verb/pin_article',tuple:true,params:[['a',0,'slug'],['a',1,null],['a',2,'title']]},
 advance_article:{key:'verb/advance_article',tuple:true,params:[['a',0,'slug'],['a',1,null],['from',2],['to',2],['at']],transitions:{'article_draft_to_published':['draft','published'],'article_draft_to_scheduled':['draft','scheduled'],'article_scheduled_to_draft':['scheduled','draft'],'article_published_to_retracted':['published','retracted']}},
 delete_article:{key:'verb/delete_article',tuple:false,params:[['a',0,'slug']]},
 reorder_articles_stage:{key:'verb/reorder_articles_stage',tuple:true,params:[['a',0,null],['ja',1]]},
 reorder_articles:{key:'verb/reorder_articles',tuple:true,params:[['a',0,null],['ja',1]]},
 put_article:{key:'verb/put_article',tuple:true,params:[['a',0,null],['a',1,null],['a',2,'slug'],['a',3,'title'],['a',4,'body'],['a',5,null]]},
 create_category:{key:'verb/create_category',tuple:false,params:[['id']],created:['category','CategoryCreated',['id'],'category_name']},
 delete_category:{key:'verb/delete_category',tuple:false,params:[['a',0,'category_name']]},
 create_staff:{key:'verb/create_staff',tuple:false,params:[['id'],['f','name',null],['f','email',null]],created:['staff','StaffCreated',['id','name','email'],null]},
 update_staff_name:{key:'verb/update_staff_name',tuple:true,params:[['a',0,null],['a',1,null]]},
 update_staff_email:{key:'verb/update_staff_email',tuple:true,params:[['a',0,null],['a',1,null]]},
 delete_staff:{key:'verb/delete_staff',tuple:false,params:[['a',0,null]]},
 create_tag:{key:'verb/create_tag',tuple:false,params:[['id']],created:['tag','TagCreated',['id'],'tag_name']},
 delete_tag:{key:'verb/delete_tag',tuple:false,params:[['a',0,'tag_name']]},
};
const manualVerbs={names:new Set([]),stage:()=>{throw new Error('no manual verb')}};
const reads={
 'article_list/items':{key:'article_list/items',args:[['enc'],['cursor']],allow:['clauses'],out:['page',['tuple',[['entity','article'],['phase','article']]]],keyset:{size:20,uniform:true,columns:[['entered_published','timestamptz'],['slug','value']]}},
 'article_list/counts':{key:'article_list/counts',args:[],allow:['clauses'],out:['list',['tuple',[['text','group'],['number','count']]]]},
 'widget_list/items':{key:'widget_list/items',args:[],allow:['clauses'],out:['list',['tuple',[['entity','article'],['phase','article']]]]},
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
const relationDecoders={article:c.decodeArticle,category:c.decodeCategory,staff:c.decodeStaff,tag:c.decodeTag};
const phaseModules={article:c.article,category:c.category,staff:c.staff,tag:c.tag};
const drafts={article:draft_article,category:draft_category,staff:draft_staff,tag:draft_tag};
const subjects=[];
const encoders={};
const carried={
};
const labels={apiKeyLabel:null,claimLabel:null};
export const {statement,run,step,seededId,labeledHmac,apiKeyHmac,claimHmac,resolveSession,resolveApiKey,issueSession,revokeParty,connectorFailureDiagnostic,actorFor,loadRoot,makeContext,invoke}=runtime({SQL,c,cursorArgs:c.cursorArgs,roots,actors,verbs,manualVerbs,reads,readAliases,connectors,connectorNames,folds,enqueues,boundaries,relationDecoders,phaseModules,drafts,subjects,encoders,carried,...labels});
