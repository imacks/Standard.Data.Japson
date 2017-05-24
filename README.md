What is Japson
==============
JAPSON is a JSON dialect that is easier to write.


Show me the money
-----------------
A quick compare-and-contrast:

```JSON
{
    "foo": "abc",
    "bar": "abc\ndef",
    "taz": {
        "z": "abcabc"
    }
}
```

If you have written JSON by hand, you probably have experienced these:

- forget a comma delimiter, or had an extra comma delimiter
- tirelessly "quoting" your keys and strings
- got lost with escape characters
- no place to write your comments
- wishing for variables like you do with CSS

The answer? JAPSON!

```JSON
foo = abc
# a comment!
bar = """abc
def"""
taz {
    z = ${foo}${foo}
}
```

Seriously, it is like writing an INI file, but with comments, multi-line, variables and stuff.

What's more! JAPSON is a superset of JSON, so your existing JSON text works as well.



Getting started
---------------
The latest package is [available on NuGet](https://www.nuget.org/packages/Standard.Data.Japson). Simply reference it in your .NET project file or `packages.config`.

If you are interested in working with Japson inside PowerShell, the latest module is hosted on PowerShell Gallery:

```PowerShell
Install-Package PSJapson
```



More details
------------
Read [more examples](./Docs/conceptual/japson-example.md) here, or see [the whole spec](./Docs/conceptual/japson-spec.md).

The documentation index is [here](./Docs/README.md).



Building from source
--------------------
First, read the [repo structure](./Docs/repo-organization.md) to make sure your paths are correctly set up. Then just execute `build.cmd` to build a debug copy. For more options, run `build /?`.
