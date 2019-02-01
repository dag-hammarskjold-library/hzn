
# hzn-client

This module provides classes for extracting and working with data from the Horizon database, and exporting MARC records in various formats. The module also provides scripts that are command line programs powered by these classes.

###### Installation:

```bash
git clone https://github.com/dag-hammarskjold-library/hzn-client
````

###### Requirements:

* Perl version 5.10 or above
* Local connection to Horizon database.
* Local installation of ```isql``` command line tool in PATH
* Environment variables HORIZON_USERNAME and HORIZON_PASSWORD set to valid credentials.
* For exporting MARC:
  * [DLX::MARC]()
* For exporting to a Mongo instance:
  * [MongoDB](https://metacpan.org/pod/MongoDB)
  * Valid connection sting granting read access to a MongoDB instance with collections named "bib" and "auth"
 


## Scripts

> ### run-sql.pl

Wrapper for [`isql`](http://infocenter.sybase.com/help/index.jsp?topic=/com.sybase.infocenter.dc35456.1570/html/ocspsunx/X33477.htm) for executing SQL from the command line. Write results to file or STDOUT. The `isql` output is converted to tab-separated values.  

###### Usage:

```bash
perl run-sql.pl -v -s 'select bib#, create_user from bib_control' | grep 'jbcat' 
```

###### Options:

| opt | datatype | desc |
|-----|----------|:-----|
| -h  | *boolean* | Display help
| -s | *string* | SQL statement
| -S | *string* | Path to SQL script
| -u | *boolean* | Convert data to UTF-8
| -o | *string* | Output file (warning - existing file will be overwrittern)
| -v | *boolean* | Verbose. Display results on console

___

> ### export.pl

Export MARC records from the Horizon database to file, STDOUT, or MongoDB. There are three export modes:
* Raw: Export records with minimal transformations documented [here](). 
* DLX: Export records with metadata enhancements specified by DHL librarians documented [here]().
* UNDL: Export records with transformations for UNDL documented [here]().

###### Usage:

```bash
perl export.pl -b -s "select top 100 bib# from bib_control" -f xml -o output.xml
```

###### Options:

| opt | datatype | desc |
|-----|----------|:-----|
| -h | *boolean* | Display help
| -a | *boolean* | Export authority records
| -b | *boolean* | Export bibliographic records
| -s | *string* | SQL statement to run against the Horizon database. The results must contain auth/bib IDs in the first column to be used as IDs to export
| -m | *datetime* | ISO 8601 datetime (in UTC) from which to export records new/changed since
| -u | *datetime* | ISO 8601 datetime (in UTC) from which to export records new/changed until
| -r | *boolean* | Export in Raw mode
| -d | *boolean* | Export in DLX mode
| -u | *boolean* | Export in UNDL mode
| -X | *boolean* | Export as XML
| -C | *boolean* | Export as MARC21 (.mrc)
| -K | *boolean* | Export as MRK (.mrk)
| -M | *string* | MongoDB connection string to export JMARC records in to

___

## Classes

... to do
