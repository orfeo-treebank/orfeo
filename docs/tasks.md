# Common tasks

Here's how to do the most basic administrative tasks.

## Importing data

To import files, go to the directory where the importer is installed (`orfeo-importer`) and run

```
./import.sh -i inputdir
```

where inputdir is a directory with input files. Other settings will be read from the file settings.yaml, if available, but can also be specified on the command line. Run `./import.sh --help` for a full list of available parameters. Note that the various URL parameters must be set in order for the links between the components of the search app to work. This is done automatically by the installer script.

The input directory should correspond to a single corpus (so, for example, use `import.sh -i corpora/coralrom` instead of `import.sh corpora`) to keep samples in their respective corpora.

The importer creates sample pages, indexes the samples into the Solr index, and creates relAnnis format files (if so specified in options). To import the relAnnis files into ANNIS, go to the directory where the installer was executed and issue the following commands:

```
source settings.sh
annis-admin.sh import dir
```

where dir is the directory where the relAnnis files are stored (by default, of the format `output/annis/corpusname`, but a different location may be specified in the YAML file or via command line options).

The importer looks for files with a known extension (`.macaon`, `.conll`, `.orfeo`), and for each file found, looks for related files with the same name but a different extension (including `.mp3`, `.wav`, `.xml`, `.md.txt`). It does some matching to accommodate inconsistent naming, but only in a few, obvious cases (e.g. name written in all capitals). The input data provided so far has been much more poorly structured and named, so some manual renaming of files may be necessary.


## Removing data

To clear up the Solr index completely (PASS is the Solr password; it need not match the previous value as it will be set anew):

```
rake jetty:stop jetty:clean
rake jetty:start jetty:stop    # because the jetty:start task creates some files
rake orfeo:update password=PASS
rake jetty:start
```

To remove a specific corpus from the ANNIS database (in directory where installer was run):

```
source settings.sh
annis-admin.sh list       # check what corpora are there first
annis-admin.sh delete [corpusname]
```

In the case of sample pages, the directory representing a corpus can simply be deleted.


## Adding or changing metadata fields

After editing the metadata definitions in the `orfeo-metadata` module, run `rake install` within the metadata module to update that gem, then restart Rails. If the change has been pushed into the GitHub repository, re-running the installer script will take care of this automatically.

If the change involves addition or removal of fields or changes to XPath expressions, the import process must be re-run. First clear up Solr, then re-import the data. Both steps are described above.


## Stemming

Stemming for French text can be turned on by adding a parameter to the rake task:

```
rake orfeo:update password=PASS stemming=true
```

This enables the builtin stemming of Solr for French text, and also enables the use of a stop word list. Note that the stemmer is aggressive and hence makes mistakes (e.g. mapping "gars" and "gare" together). For this reason, the stemming is off by default.
