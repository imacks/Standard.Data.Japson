Examples
========
Here are some samples to get a feel of how Japson files look like.

We are going to load the following Japson files in the order they appear.


## myawesomelib/config.japson

```
my-awesome-lib {
    foo = "I am from myawesomelib/config.japson"
    hello = "I am from myawesomelib/config.japson"
    bar = "I am from myawesomelib/config.japson"
}
```

## awesomeapp/config.japson

```
# this won't be affected by anything before it, because it is a unique name
awesome-app {
    the-answer = 42
}

# Let's override some vars!
my-awesome-lib.foo = "I am from awesomeapp/config.japson"
my-awesome-lib.bar = "I am from awesomeapp/config.japson"
```

## golden-hammer-app/config.japson

```
# this won't be affected by anything before it, because it is a unique name
golder-hammer-app {
    caret = 24
}

# More overrides
my-awesome-lib.foo = "I am from golder-hammer-app/config.japson"
my-awesome-lib.hello = "I am from golden-hammer-app/config.japson"
```

## golden-hammer-app/config2.japson

```
golder-hammer-app {
    caret = 18

    # here 'libconfig' will get all the properties of 'my-awesome-lib'.
    # then, we customize the 'bar' property.
	my-context {
		libconfig = ${my-awesome-lib}
		libconfig {
			bar = "I am from golden-hammer-app/config2.japson"
		}
	}
}
```
