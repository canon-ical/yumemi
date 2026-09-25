//// GENERATED from entity / types declarations [sha256:bbf198d7f83a] — 手で編集しない
// 宣言から導けない decoder(hook も無い): article(tags が Multi), staff(framework/idp.Name の module が読めない)
import { Some, None } from '../../gleam_stdlib/gleam/option.mjs';
import { toList, List } from '../gleam.mjs';
import * as party from '../../yumemi/framework/party.mjs';
import * as time from '../../yumemi/framework/time.mjs';
import * as blob from '../../yumemi/framework/blob.mjs';
import * as er from '../../yumemi/framework/er.mjs';
import * as page from '../../yumemi/framework/page.mjs';
import * as secret from '../../yumemi/framework/secret_ffi.mjs';
import { codec } from '../../yumemi/framework/server/codec.mjs';
import * as article from '../entity/article.mjs';
import * as category from '../entity/category.mjs';
import * as staff from '../entity/staff.mjs';
import * as tag from '../entity/tag.mjs';
import * as widget from '../widget.mjs';
import * as t_slug from './types/slug.mjs';
import * as t_title from './types/title.mjs';
import * as t_body from './types/body.mjs';
import * as t_category_name from './types/category_name.mjs';
import * as t_tag_name from './types/tag_name.mjs';
export { Some, None, toList, article, category, staff, tag, widget, party, time, page, er, blob };
export const scalar = {slug:t_slug,title:t_title,body:t_body,category_name:t_category_name,tag_name:t_tag_name};
const integerKeys=new Set([]);
const base=codec({scalar,integerKeys,Some,None,List,time});
export const {checked,parse,option,unwrap,text,tag,encode,phase,timeText,dateText}=base;
const {cDate,cDatetime,cTime,list}=base;
export function decodeCategory(r) {
 return new category.Category(
  parse('category_name',String(r.name)),
 );
}
export function decodeTag(r) {
 return new tag.Tag(
  parse('tag_name',String(r.name)),
 );
}
