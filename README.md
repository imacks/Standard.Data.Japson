What is Japson
==============
JAPSON is a JSON dialect that is easier to write.


Show me the money
-----------------
A quick compare-and-contrast:

```JSON
{
    "foo": abc,
    "bar": "abc\ndef",
    "taz": {
        "z" = "abcabc"
    }
}
```

If you have written JSON by hand, you will probably have experienced these gotchas:

- forgot to write a comma delimiter, or had an extra the comma delimiter.
- forgot to "quote" your key
- got lost with escape characters
- find yourself copy-and-pasting a lot sometimes

Here's a rewrite in JAPSON:

```JSON
foo = abc
bar = """abc
def"""
taz {
    z = ${foo}${foo}
}
```

Seriously, it is like writing an INI file.

What's more! JAPSON is a superset of JSON, so your existing JSON text is also recognized. 



More details
------------
Read [more examples](./Docs/conceptual/japson-example.md) here, or see [the whole spec](./Docs/conceptual/japson-spec.md).



Building from source
--------------------
First, read the [repo structure](./Docs/repo-organization.md) to make sure your paths are correctly set up. Then just execute `build.cmd` to build a debug copy. For more options, run `build /?`.
