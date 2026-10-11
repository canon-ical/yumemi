export const EXTERNAL_HOSTS = Object.freeze([
  {
    connector: 'fixture-browser',
    host: 'images.example.test',
    name: 'Fixture Images',
    information: '公開画像の取得',
    purpose: '記事画像を表示する',
    side: 'browser',
  },
  {
    connector: 'fixture-search',
    host: 'search.example.test',
    name: 'Fixture Search',
    information: '検索結果の取得',
    purpose: '記事候補を探す',
    side: 'server',
  },
  {
    connector: 'fixture-search',
    host: 'api.example.test',
    name: 'Fixture Search API',
    information: '検索候補の取得',
    purpose: '候補を絞り込む',
    side: 'server',
  },
]);
