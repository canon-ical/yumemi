//// GENERATED from entity / types declarations [sha256:fe4ede23cb20] — 手で編集しない
import { Some, None } from '../../gleam_stdlib/gleam/option.mjs';
import { toList, List } from '../gleam.mjs';
import * as party from '../../yumemi/yumemi/party.mjs';
import * as time from '../../yumemi/yumemi/time.mjs';
import * as blob from '../../yumemi/yumemi/blob.mjs';
import * as color from '../../yumemi/yumemi/front/color.mjs';
import * as er from '../../yumemi/yumemi/er.mjs';
import * as page from '../../yumemi/yumemi/page.mjs';
import * as secret from '../../yumemi/yumemi/secret_ffi.mjs';
import { codec } from '../../yumemi/yumemi/server/codec.mjs';
import * as note from '../entity/note.mjs';
import * as t_note_id from './types/note_id.mjs';
import * as t_note_title from './types/note_title.mjs';
import * as t_note_body from './types/note_body.mjs';
export { Some, None, toList, note, party, time, page, er, blob };
export const scalar = {note_id:t_note_id,note_title:t_note_title,note_body:t_note_body};
const integerKeys=new Set([]);
const base=codec({scalar,integerKeys,Some,None,List,time});
export const {checked,parse,option,unwrap,text,tag,encode,phase,timeText,dateText}=base;
const {cDate,cDatetime,cTime,list}=base;
export function decodeNote(r) {
 return new note.Note(
  parse('note_id',String(r.id)),
  parse('note_title',String(r.title)),
  parse('note_body',String(r.body)),
  cDatetime(r.created_at),
 );
}
