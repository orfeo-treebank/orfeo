# Implementation notes

This page discusses some details of how the system has been implemented. This information is mainly useful only for those interested in further development of the system.


## Importer

### Annis output

There is already a canonical way to convert data into the relAnnis format (the native input format of Annis), namely [Pepper](http://korpling.german.hu-berlin.de/saltnpepper/). In this project it was not used, and instead, the relAnnis output of the Orfeo importer has been written from scratch. The main reasons for this are the slow and resource-intensive execution of Pepper and the sparse state of its documentation. However, note that Salt/Pepper is much more complete than the code in the Orfeo importer, and supports a number of input and output formats. The Orfeo importer makes a number of simplifying assumptions which might need to be revised when dealing with data of an unforeseen type. Consequently Salt/Pepper is also far more complex than the importer, containing about 100 times as many lines of code.

The relAnnis implementation is based on reverse engineering the relAnnis output produced by Pepper and on [a paper](http://www.researchgate.net/publication/228731067_An_Implementation_Of_The_Annis_2_Query_Language) by Viktor Rosenfeld. No reference to the source code of Pepper has been made.


## Sample page

The sample pages are pure HTML pages with embedded Javascript, meaning that they can be hosted on any ordinary web server.

### Parameters

The sample page accepts query parameters `from` and `to` to specify a range of words to highlight or `tree` to jump to the syntax tree associated with a particular word. The values of these parameters are indices to the list of *words* (what you get when you split the document on spaces) as opposed to *tokens* (which are imported from the input file, and are subject to variance based on the theoretical framework used when defining the tokens). Words, tokens and locutions are all numbered starting from 0.

In the text panel of the sample page, each token is contained in a separate span element with an id attribute based on the token number in the sample, e.g.

```html
<span id="tok42">parce que</span>
```

However, links from the concordancer are based on word, rather than token, numbers.

To enable matching of these, the importer inserts a JSON object (called word_map) within the sample page that contains mappings such as this:

```javascript
"42": [42,3],
"43": [42,3],
"44": [43,3]
```

Here, words 42 ("parce") and 43 ("que") both map to token 42 ("parce que"). The highlighting is always applied based on tokens, so invoking the sample page with the query string `from=43&to=43` highlights "parce que", not just "que". The second element in the value is the number of the locution, used to jump to the correct syntax tree.

The reason for this approach is that the concordance view is generated by string splitting from a highlighted Solr field, where splitting by words is simple and fast, while tokens are not directly available unless reconstituted with a variety of string operations. The concordance view contains a large number of links of this type, so complex operations that slow rendering are noticeable and annoying to users. The importer is not run in a time-critical context, and the sample page only needs to find the highlighted words, i.e. generally only a few words, hence the work of mapping word to token is left to the sample page.
