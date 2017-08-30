# Convert SATIQ.mdb to SATIQ.sqlite

Install mdbtools `sudo apt-get install mdbtools`
Install sqlite3 `sudo apt-get install sqlite3`
Run the following in shell

```
python AccessDump.py SATIQ.mdb | sqlite3 SATIQ.sqlite
```
