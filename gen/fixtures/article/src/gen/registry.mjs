//// GENERATED from service declarations / entry.gleam / server.gleam [sha256:032d56dd277b] — 手で編集しない
import { validateWho } from '../../yumemi/framework/server/contracts.mjs';

import * as article_blob_save from '../service/article_blob_save.mjs';
import * as root_article_blob_save from './root/article_blob_save.mjs';
import * as article_create from '../service/article_create.mjs';
import * as root_article_create from './root/article_create.mjs';
import * as article_list from '../service/article_list.mjs';
import * as root_article_list from './root/article_list.mjs';
import * as article_publish from '../service/article_publish.mjs';
import * as root_article_publish from './root/article_publish.mjs';
import * as article_read from '../service/article_read.mjs';
import * as root_article_read from './root/article_read.mjs';
import * as article_retract from '../service/article_retract.mjs';
import * as root_article_retract from './root/article_retract.mjs';
import * as widget_list from '../service/widget_list.mjs';
import * as root_widget_list from './root/widget_list.mjs';

export const registry = [
  { name: 'article_blob_save', module: article_blob_save, root: root_article_blob_save, method: 'POST', path: '/api/articles/:slug/blob_save', fields: ['slug', 'blob', 'existing'], folded: null, entry: 'public' },
  { name: 'article_create', module: article_create, root: root_article_create, method: 'POST', path: '/api/admin/articles', fields: ['slug', 'title', 'body', 'category', 'tags'], folded: null },
  { name: 'article_list', module: article_list, root: root_article_list, method: 'GET', path: '/api/admin/articles', fields: ['limit', 'cursor'], folded: null },
  { name: 'article_publish', module: article_publish, root: root_article_publish, method: 'POST', path: '/api/admin/articles/:slug/publish', fields: ['slug'], folded: null },
  { name: 'article_read', module: article_read, root: root_article_read, method: 'GET', path: '/api/admin/articles/:slug', fields: ['slug'], folded: null },
  { name: 'article_retract', module: article_retract, root: root_article_retract, method: 'POST', path: '/api/admin/articles/:slug/retract', fields: ['slug'], folded: null, entry: 'admin' },
  { name: 'widget_list', module: widget_list, root: root_widget_list, method: 'GET', path: '/api/admin/widgets', fields: ['widget', 'slug'], folded: null },
  { name: 'article_create_public', module: article_create, root: root_article_create, method: 'POST', path: '/api/articles', fields: ['slug', 'title', 'body', 'category', 'tags'], folded: null, target: 'article_create' },
  { name: 'article_list_public', module: article_list, root: root_article_list, method: 'GET', path: '/api/articles', fields: ['limit', 'cursor'], folded: null, target: 'article_list' },
  { name: 'article_publish_public', module: article_publish, root: root_article_publish, method: 'POST', path: '/api/articles/:slug/publish', fields: ['slug'], folded: null, target: 'article_publish' },
  { name: 'article_read_public', module: article_read, root: root_article_read, method: 'GET', path: '/api/articles/:slug', fields: ['slug'], folded: null, target: 'article_read' },
  { name: 'widget_list_public', module: widget_list, root: root_widget_list, method: 'GET', path: '/api/widgets', fields: ['widget', 'slug'], folded: null, target: 'widget_list' },
];

export const byName = Object.fromEntries(registry.filter((record) => !record.target && record.module).map((record) => [record.name, record]));

for (const record of registry) if(record.module) validateWho([...record.module.service.allow]);
