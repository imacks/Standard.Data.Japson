Known issues & workarounds
==========================
Here are the officially known and documented issues, with possible workarounds.

We will keep updating this page, so come back and check out some time later.


Support for empty objects
-------------------------
### Affected versions
- 1.2 and below

### Synopsis
This throws and error:
```
foo {}
```

### Workarounds
- Will be fixed by version 1.3


Array of objects
----------------
### Affected versions
- 1.2 and below

### Synopsis
This throws and error:
```
foo = [
	{ a = 1 }
]
```

### Workarounds
- Will be fixed by version 1.3


Substitutions containing dot paths
----------------------------------
### Affects versions
- 1.2 and below.

### Synopsis
This throws and error:
```
'foo.bar' = 5
baz = ${ 'foo.bar' }
```

### Workarounds
- Will be fixed by version 1.3
