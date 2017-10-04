This repository contains some tools, written in Lua, for dealing with [libsn](https://github.com/SolraBizna/libsn) message catalogs. They are written for Lua 5.3, though will probably work for 5.2.

# Finished tools

## `main_cat_lint.lua`

This is a tool with two purposes. Purpose 1 is to find messages which are in the catalog, but not used by the program. Purpose 2 is to find message IDs which are used by the program, but missing from the catalog.

The catalog being tested should be the main catalog for the program. (This tool is NOT meant to test completeness of translations!)

If you're in a UNIX environment, something like the following command line should serve you well:

```sh
find . \( \
-iname \*.hh -o -iname \*.hpp -o -iname \*.hxx -o -iname \*.h++ \
-o -iname \*.cc -o -iname \*.cpp -o -iname \*.cxx -o -iname \*.c++ \
\) -print0 | xargs -0 main_cat_lint.lua Lang/en.utxt
```

# Planned tools

- XLIFF
    - Tool to convert a main catalog into XLIFF
    - Tool to convert a sea of XLIFFs into secondary catalogs
