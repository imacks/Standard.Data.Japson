## simple-lib/reference.japson

```
simple-lib {
    foo = "This value comes from simple-lib's reference.japson"
    hello = "This value comes from simple-lib's reference.japson"
    whatever = "This value comes from simple-lib's reference.japson"
}
```

## simple-app/reference.japson

```
# these are our own config values defined by the app
simple-app {
    answer=42
}

# Here we override some values used by a library
simple-lib.foo="This value comes from simple-app's application.conf"
simple-lib.whatever = "This value comes from simple-app's application.conf"
```

## complex-app/reference.japson

```
# these are our own config values defined by the app
complex-app {
    something="This value comes from complex-app's complex1.conf"
}

# Here we override some values used by a library
simple-lib.foo="This value comes from complex-app's complex1.conf"
simple-lib.whatever = "This value comes from complex-app's complex1.conf"
```

## complex-app/reference2.japson

```
complex-app {
    something="This value comes from complex-app's complex2.conf"

    # here we want a simple-lib-context unique to our app
    # which can be custom-configured. In code, we have to
    # pull out this subtree and pass it to simple-lib.
    simple-lib-context = {
        simple-lib {
            foo="This value comes from complex-app's complex2.conf in its custom simple-lib-context"
            whatever = "This value comes from complex-app's complex2.conf in its custom simple-lib-context"
        }
    }
}
```
