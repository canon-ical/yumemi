//// GENERATED from service declarations / entry.gleam / server.gleam [sha256:fe4ede23cb20] — 手で編集しない
import { validateWho } from '../../yumemi/yumemi/server/contracts.mjs';

import * as note_create from '../service/note_create.mjs';
import * as root_note_create from './root/note_create.mjs';
import * as note_delete from '../service/note_delete.mjs';
import * as root_note_delete from './root/note_delete.mjs';
import * as note_edit from '../service/note_edit.mjs';
import * as root_note_edit from './root/note_edit.mjs';
import * as note_list from '../service/note_list.mjs';
import * as root_note_list from './root/note_list.mjs';
import * as note_read from '../service/note_read.mjs';
import * as root_note_read from './root/note_read.mjs';

export const registry = [
  { name: 'note_create', module: note_create, root: root_note_create, method: 'POST', path: '/api/notes', fields: ['title', 'body'], folded: null, entry: 'api' },
  { name: 'note_delete', module: note_delete, root: root_note_delete, method: 'DELETE', path: '/api/notes/:id', fields: ['id'], folded: null, entry: 'api' },
  { name: 'note_edit', module: note_edit, root: root_note_edit, method: 'PUT', path: '/api/notes/:id', fields: ['id', 'title', 'body'], folded: null, entry: 'api' },
  { name: 'note_list', module: note_list, root: root_note_list, method: 'GET', path: '/api/notes', fields: ['limit', 'cursor'], folded: null, entry: 'api' },
  { name: 'note_read', module: note_read, root: root_note_read, method: 'GET', path: '/api/notes/:id', fields: ['id'], folded: null, entry: 'api' },
];

export const byName = Object.fromEntries(registry.filter((record) => !record.target && record.module).map((record) => [record.name, record]));

for (const record of registry) if(record.module) validateWho([...record.module.service.allow]);
