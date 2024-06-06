# About

This directory contains tools to prepare data for ingest into Preservica.
There are two scripts - one creates a standard manifest with in a 
specific folder and the other creates one or more sets of manifests for
ingesting and linking to ArchivesSpace.

## Process

Ensure that you have the latest gems for the ingest scripts. Run 
```
bundler install
```
or 

```
bundle
```

from the directory the ingest scripts are located in. Then run the 
appropriate script

```
ruby opex_manifest_create.rb
```
for standard (non-linking ingests) or
```
ruby opex_manifest_w_linking.rb
```
for data to be linked to ArchivesSpace. Note that there is a specific
directory structure.

Standard
```
ingest wrapper (directory)
-- Top Level (directory; unique name in Preservica)
---- asset(s)
```
Linking
```
ingest wrapper (directory)
-- archival_object_xxxx (directory; requires naming structure as shown)
---- digital_object_identifier (directory; name must be unique in Preservica and ArchivesSpace)
------ asset(s)
-- archival_object_yyyy (directory; requires naming structure as shown)
---- digital_object_identifier (directory; name must be unique in Preservica and ArchivesSpace)
------ asset(s)
```

You will need the absolute path to the directory you wish to create manifests for.

Once prepared, the files can be ingested into Preservica by uploading them to the
bulk bucket.
