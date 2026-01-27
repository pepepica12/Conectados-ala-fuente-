const { algoliasearch, instantsearch } = window;

const searchClient = algoliasearch('UFD5F4B5UE', '5fed8affe514ee904a9bb89b55622a63');

const search = instantsearch({
  indexName: 'algolia_movie_sample_dataset',
  searchClient,
  future: { preserveSharedStateOnUnmount: true },
  
});


search.addWidgets([
  instantsearch.widgets.searchBox({
    container: '#searchbox',
  }),
  instantsearch.widgets.hits({
    container: '#hits',
    templates: {
      item: (hit, { html, components }) => html`
<article>
  <img src=${ hit.poster_path } alt=${ hit.original_language } />
  <div>
    <h1>${components.Highlight({hit, attribute: "original_language"})}</h1>
    <p>${components.Highlight({hit, attribute: "release_date"})}</p>
    <p>${components.Highlight({hit, attribute: "cast.0.name"})}</p>
  </div>
</article>
`,
    },
  }),
  instantsearch.widgets.configure({
    hitsPerPage: 8,
  }),
  instantsearch.widgets.pagination({
    container: '#pagination',
  }),
]);

search.start();

