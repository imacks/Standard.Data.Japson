using System;
using System.Linq;
using System.Collections.Generic;
using Xunit;
using Standard.Data.Japson;

namespace Standard.Data.Japson.Tests
{
    public class JapsonTests
    {
        // undefined behavior in spec, this does not behave the same as JVM japson.
        [Fact]
        public void CanUnwrapSub() 
        {
            var japson = @"
a {
   b {
     c = 1
     d = true
   }
}";
            var config = JapsonFactory.ParseString(japson).Root.GetObject().Unwrapped;
            var a = config["a"] as IDictionary<string, object>;
            var b = a["b"] as IDictionary<string, object>;
            Assert.Equal(1, (b["c"] as JapsonValue).GetInt32());
            Assert.True((b["d"] as JapsonValue).GetBoolean());
        }

        //undefined behavior in spec
        [Fact]
        public void ThrowsParserExceptionOnUnterminatedObject() 
        {
            var japson = " root { string : \"hello\" ";
            Assert.Throws<JapsonParserException>(() => 
                JapsonFactory.ParseString(japson));
        }

        //undefined behavior in spec        
        [Fact]
        public void ThrowsParserExceptionOnUnterminatedNestedObject() 
        {
            var japson = " root { bar { string : \"hello\" } ";
            Assert.Throws<JapsonParserException>(() =>
                JapsonFactory.ParseString(japson));
        }

        //undefined behavior in spec        
        [Fact]
        public void ThrowsParserExceptionOnUnterminatedString() 
        {
            var japson = " string : \"hello";
            Assert.Throws<JapsonParserException>(() => 
                JapsonFactory.ParseString(japson));
        }

        //undefined behavior in spec        
        [Fact]
        public void ThrowsParserExceptionOnUnterminatedStringInObject()
        {
            var japson = " root { string : \"hello }";
            Assert.Throws<JapsonParserException>(() => 
                JapsonFactory.ParseString(japson));
        }

        //undefined behavior in spec        
        [Fact]
        public void ThrowsParserExceptionOnUnterminatedArray() 
        {
            var japson = " array : [1,2,3";
            Assert.Throws<JapsonParserException>(() => 
                JapsonFactory.ParseString(japson));
        }

        //undefined behavior in spec        
        [Fact]
        public void ThrowsParserExceptionOnUnterminatedArrayInObject() 
        {
            var japson = " root { array : [1,2,3 }";
            Assert.Throws<JapsonParserException>(() => 
                JapsonFactory.ParseString(japson));
        }

        //undefined behavior in spec        
        [Fact]
        public void GettingStringFromArrayReturnsNull()
        {
            var japson = " array : [1,2,3]";
            Assert.Null(JapsonFactory.ParseString(japson).GetString("array"));
        }


        //TODO: not sure if this is the expected behavior but it is what we have established
        //undefined behavior in spec        
        [Fact]
        public void GettingArrayFromLiteralsReturnsNull() 
        {
            var japson = " literal : a b c";
            var res = JapsonFactory.ParseString(japson).GetStringList("literal");

            Assert.Empty(res);
        }

        //Added tests to conform to the JAPSON spec
        [Fact]
        public void CanUsePathsAsKeys_3_14()
        {
            var japson1 = @"3.14 : 42";
            var japson2 = @"3 { 14 : 42}";
            Assert.Equal(
                JapsonFactory.ParseString(japson1).GetString("3.14"),
                JapsonFactory.ParseString(japson2).GetString("3.14"));
        }

        [Fact]
        public void CanUsePathsAsKeys_3()
        {
            var japson1 = @"3 : 42";
            var japson2 = @"""3"" : 42";
            Assert.Equal(
                JapsonFactory.ParseString(japson1).GetString("3"),
                JapsonFactory.ParseString(japson2).GetString("3"));
        }

        [Fact]
        public void CanUsePathsAsKeys_true()
        {
            var japson1 = @"true : 42";
            var japson2 = @"""true"" : 42";
            Assert.Equal(
                JapsonFactory.ParseString(japson1).GetString("true"),
                JapsonFactory.ParseString(japson2).GetString("true"));
        }

        [Fact]
        public void CanUsePathsAsKeys_FooBar()
        {
            var japson1 = @"foo.bar : 42";
            var japson2 = @"foo { bar : 42 }";
            Assert.Equal(
                JapsonFactory.ParseString(japson1).GetString("foo.bar"),
                JapsonFactory.ParseString(japson2).GetString("foo.bar"));
        }

        [Fact]
        public void CanUsePathsAsKeys_FooBarBaz()
        {
            var japson1 = @"foo.bar.baz : 42";
            var japson2 = @"foo { bar { baz : 42 } }";
            Assert.Equal(
                JapsonFactory.ParseString(japson1).GetString("foo.bar.baz"),
                JapsonFactory.ParseString(japson2).GetString("foo.bar.baz"));
        }

        [Fact]
        public void CanUsePathsAsKeys_AX_AY()
        {
            var japson1 = @"a.x : 42, a.y : 43";
            var japson2 = @"a { x : 42, y : 43 }";
            Assert.Equal(
                JapsonFactory.ParseString(japson1).GetString("a.x"),
                JapsonFactory.ParseString(japson2).GetString("a.x"));
            Assert.Equal(
                JapsonFactory.ParseString(japson1).GetString("a.y"),
                JapsonFactory.ParseString(japson2).GetString("a.y"));
        }

        [Fact]
        public void CanUsePathsAsKeys_A_B_C()
        {
            var japson1 = @"a b c : 42";
            var japson2 = @"""a b c"" : 42";
            Assert.Equal(
                JapsonFactory.ParseString(japson1).GetString("a b c"),
                JapsonFactory.ParseString(japson2).GetString("a b c"));
        }


        [Fact]
        public void CanConcatenateSubstitutedUnquotedString()
        {
            var japson = @"a {
  name = Roger
  c = Hello my name is ${a.name}
}";
            Assert.Equal(
                "Hello my name is Roger", 
                JapsonFactory.ParseString(japson).GetString("a.c"));
        }

        [Fact]
        public void CanConcatenateSubstitutedArray()
        {
            var japson = @"a {
  b = [1,2,3]
  c = ${a.b} [4,5,6]
}";
            Assert.True(new[] {1, 2, 3, 4, 5, 6}.SequenceEqual(JapsonFactory.ParseString(japson).GetInt32List("a.c")));
        }

        [Fact]
        public void CanParseSubConfig()
        {
            var japson = @"
a {
   b {
     c = 1
     d = true
   }
}";
            var config = JapsonFactory.ParseString(japson);
            var subConfig = config.GetContext("a");
            Assert.Equal(1, subConfig.GetInt32("b.c"));
            Assert.True(subConfig.GetBoolean("b.d"));
        }


        [Fact]
        public void CanParseJapson()
        {
            var japson = @"
root {
  int = 1
  quoted-string = ""foo""
  unquoted-string = bar
  concat-string = foo bar
  object {
    hasContent = true
  }
  array = [1,2,3,4]
  array-concat = [[1,2] [3,4]]
  array-single-element = [1 2 3 4]
  array-newline-element = [
    1
    2
    3
    4
  ]
  null = null
  double = 1.23
  bool = true
}
";
            var config = JapsonFactory.ParseString(japson);
            Assert.Equal("1", config.GetString("root.int"));
            Assert.Equal("1.23", config.GetString("root.double"));
            Assert.True(config.GetBoolean("root.bool"));
            Assert.True(config.GetBoolean("root.object.hasContent"));
            Assert.Null(config.GetString("root.null"));
            Assert.Equal("foo", config.GetString("root.quoted-string"));
            Assert.Equal("bar", config.GetString("root.unquoted-string"));
            Assert.Equal("foo bar", config.GetString("root.concat-string"));
            Assert.True(
                new[] {1, 2, 3, 4}.SequenceEqual(JapsonFactory.ParseString(japson).GetInt32List("root.array")));
            Assert.True(
                new[] {1, 2, 3, 4}.SequenceEqual(
                    JapsonFactory.ParseString(japson).GetInt32List("root.array-newline-element")));
            Assert.True(
                new[] {"1 2 3 4"}.SequenceEqual(
                    JapsonFactory.ParseString(japson).GetStringList("root.array-single-element")));
        }

        [Fact]
        public void CanParseJson()
        {
            var japson = @"
""root"" : {
  ""int"" : 1,
  ""string"" : ""foo"",
  ""object"" : {
        ""hasContent"" : true
    },
  ""array"" : [1,2,3],
  ""null"" : null,
  ""double"" : 1.23,
  ""bool"" : true
}
";
            var config = JapsonFactory.ParseString(japson);
            Assert.Equal("1", config.GetString("root.int"));
            Assert.Equal("1.23", config.GetString("root.double"));
            Assert.True(config.GetBoolean("root.bool"));
            Assert.True(config.GetBoolean("root.object.hasContent"));
            Assert.Null(config.GetString("root.null"));
            Assert.Equal("foo", config.GetString("root.string"));
            Assert.True(new[] {1, 2, 3}.SequenceEqual(JapsonFactory.ParseString(japson).GetInt32List("root.array")));
        }

        [Fact]
        public void CanMergeObject()
        {
            var japson = @"
a.b.c = {
        x = 1
        y = 2
    }
a.b.c = {
        z = 3
    }
";
            var config = JapsonFactory.ParseString(japson);
            Assert.Equal("1", config.GetString("a.b.c.x"));
            Assert.Equal("2", config.GetString("a.b.c.y"));
            Assert.Equal("3", config.GetString("a.b.c.z"));
        }

        [Fact]
        public void CanOverrideObject()
        {
            var japson = @"
a.b = 1
a = null
a.c = 3
";
            var config = JapsonFactory.ParseString(japson);
            Assert.Null(config.GetString("a.b"));
            Assert.Equal("3", config.GetString("a.c"));
        }

        [Fact]
        public void CanParseObject()
        {
            var japson = @"
a {
  b = 1
}
";
            Assert.Equal("1", JapsonFactory.ParseString(japson).GetString("a.b"));
        }

        [Fact]
        public void CanTrimValue()
        {
            var japson = "a= \t \t 1 \t \t,";
            Assert.Equal("1", JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanTrimConcatenatedValue()
        {
            var japson = "a= \t \t 1 2 3 \t \t,";
            Assert.Equal("1 2 3", JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanConsumeCommaAfterValue()
        {
            var japson = "a=1,";
            Assert.Equal("1", JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanAssignIpAddressToField()
        {
            var japson = @"a=127.0.0.1";
            Assert.Equal("127.0.0.1", JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanAssignConcatenatedValueToField()
        {
            var japson = @"a=1 2 3";
            Assert.Equal("1 2 3", JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanAssignValueToQuotedField()
        {
            var japson = @"""a""=1";
            Assert.Equal(1L, JapsonFactory.ParseString(japson).GetInt64("a"));
        }

        [Fact]
        public void CanAssignValueToPathExpression()
        {
            var japson = @"a.b.c=1";
            Assert.Equal(1L, JapsonFactory.ParseString(japson).GetInt64("a.b.c"));
        }

        [Fact]
        public void CanAssignValuesToPathExpressions()
        {
            var japson = @"
a.b.c=1
a.b.d=2
a.b.e.f=3
";
            var config = JapsonFactory.ParseString(japson);
            Assert.Equal(1L, config.GetInt64("a.b.c"));
            Assert.Equal(2L, config.GetInt64("a.b.d"));
            Assert.Equal(3L, config.GetInt64("a.b.e.f"));
        }

        [Fact]
        public void CanAssignLongToField()
        {
            var japson = @"a=1";
            Assert.Equal(1L, JapsonFactory.ParseString(japson).GetInt64("a"));
        }

        [Fact]
        public void CanAssignArrayToField()
        {
            var japson = @"a=
[
    1
    2
    3
]";
            Assert.True(new[] {1, 2, 3}.SequenceEqual(JapsonFactory.ParseString(japson).GetInt32List("a")));

            //japson = @"a= [ 1, 2, 3 ]";
            //Assert.True(new[] { 1, 2, 3 }.SequenceEqual(JapsonFactory.ParseString(japson).GetIntList("a")));
        }

        [Fact]
        public void CanConcatenateArray()
        {
            var japson = @"a=[1,2] [3,4]";
            Assert.True(new[] {1, 2, 3, 4}.SequenceEqual(JapsonFactory.ParseString(japson).GetInt32List("a")));
        }

        [Fact]
        public void CanAssignSubstitutionToField()
        {
            var japson = @"a{
    b = 1
    c = ${a.b}
    d = ${a.c}23
}";
            Assert.Equal(1, JapsonFactory.ParseString(japson).GetInt32("a.c"));
            Assert.Equal(123, JapsonFactory.ParseString(japson).GetInt32("a.d"));
        }

        [Fact]
        public void CanAssignDoubleToField()
        {
            var japson = @"a=1.1";
            Assert.Equal(1.1, JapsonFactory.ParseString(japson).GetDouble("a"));
        }

        [Fact]
        public void CanAssignNullToField()
        {
            var japson = @"a=null";
            Assert.Null(JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanAssignBooleanToField()
        {
            var japson = @"a=true";
            Assert.True(JapsonFactory.ParseString(japson).GetBoolean("a"));
            japson = @"a=false";
            Assert.False(JapsonFactory.ParseString(japson).GetBoolean("a"));

            japson = @"a=on";
            Assert.True(JapsonFactory.ParseString(japson).GetBoolean("a"));
            japson = @"a=off";
            Assert.False(JapsonFactory.ParseString(japson).GetBoolean("a"));
        }

        [Fact]
        public void CanAssignQuotedStringToField()
        {
            var japson = @"a=""hello""";
            Assert.Equal("hello", JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanAssignTrippleQuotedStringToField()
        {
            var japson = @"a=""""""hello""""""";
            Assert.Equal("hello", JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanAssignUnQuotedStringToField()
        {
            var japson = @"a=hello";
            Assert.Equal("hello", JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanAssignTripleQuotedStringToField()
        {
            var japson = @"a=""""""hello""""""";
            Assert.Equal("hello", JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanUseFallback()
        {
            var japson1 = @"
foo {
   bar {
      a=123
   }
}";
            var japson2 = @"
foo {
   bar {
      a=1
      b=2
      c=3
   }
}";

            var config1 = JapsonFactory.ParseString(japson1);
            var config2 = JapsonFactory.ParseString(japson2);

            var config = config1.WithFallback(config2);

            Assert.Equal(123, config.GetInt32("foo.bar.a"));
            Assert.Equal(2, config.GetInt32("foo.bar.b"));
            Assert.Equal(3, config.GetInt32("foo.bar.c"));
        }

        [Fact]
        public void CanUseFallbackInSubConfig()
        {
            var japson1 = @"
foo {
   bar {
      a=123
   }
}";
            var japson2 = @"
foo {
   bar {
      a=1
      b=2
      c=3
   }
}";

            var config1 = JapsonFactory.ParseString(japson1);
            var config2 = JapsonFactory.ParseString(japson2);

            var config = config1.WithFallback(config2).GetContext("foo.bar");

            Assert.Equal(123, config.GetInt32("a"));
            Assert.Equal(2, config.GetInt32("b"));
            Assert.Equal(3, config.GetInt32("c"));
        }

        [Fact]
        public void CanUseMultiLevelFallback()
        {
            var japson1 = @"
foo {
   bar {
      a=123
   }
}";
            var japson2 = @"
foo {
   bar {
      a=1
      b=2
      c=3
   }
}";
            var japson3 = @"
foo {
   bar {
      a=99
      zork=555
   }
}";
            var japson4 = @"
foo {
   bar {
      borkbork=-1
   }
}";

            var config1 = JapsonFactory.ParseString(japson1);
            var config2 = JapsonFactory.ParseString(japson2);
            var config3 = JapsonFactory.ParseString(japson3);
            var config4 = JapsonFactory.ParseString(japson4);

            var config = config1.WithFallback(config2.WithFallback(config3.WithFallback(config4)));

            Assert.Equal(123, config.GetInt32("foo.bar.a"));
            Assert.Equal(2, config.GetInt32("foo.bar.b"));
            Assert.Equal(3, config.GetInt32("foo.bar.c"));
            Assert.Equal(555, config.GetInt32("foo.bar.zork"));
            Assert.Equal(-1, config.GetInt32("foo.bar.borkbork"));
        }

        [Fact]
        public void CanUseFluentMultiLevelFallback()
        {
            var japson1 = @"
foo {
   bar {
      a=123
   }
}";
            var japson2 = @"
foo {
   bar {
      a=1
      b=2
      c=3
   }
}";
            var japson3 = @"
foo {
   bar {
      a=99
      zork=555
   }
}";
            var japson4 = @"
foo {
   bar {
      borkbork=-1
   }
}";

            var config1 = JapsonFactory.ParseString(japson1);
            var config2 = JapsonFactory.ParseString(japson2);
            var config3 = JapsonFactory.ParseString(japson3);
            var config4 = JapsonFactory.ParseString(japson4);

            var config = config1.WithFallback(config2).WithFallback(config3).WithFallback(config4);

            Assert.Equal(123, config.GetInt32("foo.bar.a"));
            Assert.Equal(2, config.GetInt32("foo.bar.b"));
            Assert.Equal(3, config.GetInt32("foo.bar.c"));
            Assert.Equal(555, config.GetInt32("foo.bar.zork"));
            Assert.Equal(-1, config.GetInt32("foo.bar.borkbork"));
        }

        [Fact]
        public void CanParseQuotedKeys()
        {
            var japson = @"
a {
   ""some quoted, key"": 123
}
";
            var config = JapsonFactory.ParseString(japson);
            Assert.Equal(123, config.GetInt32("a.some quoted, key"));
        }

        [Fact]
        public void CanParseQuotedKeysWithPeriodsInside()
        {
            var japson = @"
a {
   ""some quoted key. with periods."": 123
}
";
            var config = JapsonFactory.ParseString(japson);
            Assert.Equal(123, config.GetInt32(@"a.""some quoted key. with periods."""));
        }

        [Fact]
        public void CanEnumerateQuotedKeys()
        {
            var japson = @"
a {
   ""some quoted, key"": 123
}
";
            var config = JapsonFactory.ParseString(japson);
            var config2 = config.GetContext("a");
            var enumerable = config2.AsEnumerable();

            Assert.Equal("some quoted, key",
                enumerable.Select(kvp => kvp.Key).First());
        }

        [Fact]
        public void CanEnumerateQuotedKeysWithPeriodsInside()
        {
            var japson = @"
a {
   ""some quoted key. with periods."": 123
}
";
            var config = JapsonFactory.ParseString(japson);
            var config2 = config.GetContext("a");
            var enumerable = config2.AsEnumerable();

            Assert.Equal("some quoted key. with periods.",
                enumerable.Select(kvp => kvp.Key).First());
        }

        [Fact]
        public void CanEnumerateQuotedKeysOfObjectWithPeriodsInside()
        {
            var japson = @"
a {
   ""some.quoted.key"": {
      foo = bar
   }
   'single.quoted.key': {
      frog = green
   }
}
";
            var config = JapsonFactory.ParseString(japson);

            var config2 = config.GetContext("a.'some.quoted.key'");
            var enumerable2 = config2.AsEnumerable();
            Assert.Equal("foo",
                enumerable2.Select(kvp => kvp.Key).First());

            var config3 = config.GetContext("a.\"single.quoted.key\"");
            var enumerable3 = config3.AsEnumerable();
            Assert.Equal("frog",
                enumerable3.Select(kvp => kvp.Key).First());
        }        

/*
#todo
        [Fact]
        public void CanSubstituteQuotedKeysWithPeriodsInside()
        {
            var japson = @"
a {
   'dot.key': {
      frog = green
   }
}
b = ${a.'dot.key'}
";
            var config = JapsonFactory.ParseString(japson);

            var config2 = config.GetContext("b.'dot.key'");
            var enumerable2 = config2.AsEnumerable();
            Assert.Equal("frog",
                enumerable2.Select(kvp => kvp.Key).First());
        }        
*/

        [Fact]
        public void CanParseSerializersAndBindings()
        {
            var japson = @"
akka.actor {
    serializers {
      akka-containers = ""Akka.Remote.Serialization.MessageContainerSerializer, Akka.Remote""
      proto = ""Akka.Remote.Serialization.ProtobufSerializer, Akka.Remote""
      daemon-create = ""Akka.Remote.Serialization.DaemonMsgCreateSerializer, Akka.Remote""
    }

    serialization-bindings {
      # Since com.google.protobuf.Message does not extend Serializable but
      # GeneratedMessage does, need to use the more specific one here in order
      # to avoid ambiguity
      ""Akka.Actor.ActorSelectionMessage"" = akka-containers
      ""Akka.Remote.DaemonMsgCreate, Akka.Remote"" = daemon-create
    }

}";

            var config = JapsonFactory.ParseString(japson);

            var serializersConfig = config.GetContext("akka.actor.serializers").AsEnumerable().ToList();
            var serializerBindingConfig = config.GetContext("akka.actor.serialization-bindings").AsEnumerable().ToList();

            Assert.Equal("Akka.Remote.Serialization.MessageContainerSerializer, Akka.Remote",
                serializersConfig.Select(kvp => kvp.Value).First().GetString());

            Assert.Equal("Akka.Remote.DaemonMsgCreate, Akka.Remote",
                serializerBindingConfig.Select(kvp => kvp.Key).Last());
        }

        [Fact]
        public void CanOverwriteValue()
        {
            var japson = @"
test {
  value  = 123
}
test.value = 456
";
            var config = JapsonFactory.ParseString(japson);
            Assert.Equal(456, config.GetInt32("test.value"));
        }

        [Fact]
        public void CanCSubstituteObject()
        {
            var japson = @"a {
  b {
      foo = hello
      bar = 123
  }
  c {
     d = xyz
     e = ${a.b}
  }  
}";
            var ace = JapsonFactory.ParseString(japson).GetContext("a.c.e");
            Assert.Equal("hello", ace.GetString("foo"));
            Assert.Equal(123, ace.GetInt32("bar"));
        }

        [Fact]
        public void CanAssignNullStringToField()
        {
            var japson = @"a=null";
            Assert.Null(JapsonFactory.ParseString(japson).GetString("a"));
        }

        // [Ignore("we currently do not make any destinction between quoted and unquoted strings once parsed")]
        [Fact]
        public void CanAssignQuotedNullStringToField()
        {
            var japson = @"a=""null""";
            Assert.Null(JapsonFactory.ParseString(japson).GetString("a"));
        }

        [Fact]
        public void CanParseInclude()
        {
            var japson = @"a {
  b { 
       include ""foo""
  }";
            var includeJapson = @"
x = 123
y = hello
";
            Func<string, JapsonRoot> include = s => JapsonParser.Parse(includeJapson, null);
            var config = JapsonFactory.ParseString(japson, include);

            Assert.Equal(123, config.GetInt32("a.b.x"));
            Assert.Equal("hello", config.GetString("a.b.y"));
        }

        [Fact]
        public void CanResolveSubstitutesInInclude()
        {
            var japson = @"a {
  b { 
       include ""foo""
  }";
            var includeJapson = @"
x = 123
y = ${x}
";
            Func<string, JapsonRoot> include = s => JapsonParser.Parse(includeJapson, null);
            var config = JapsonFactory.ParseString(japson, include);

            Assert.Equal(123, config.GetInt32("a.b.x"));
            Assert.Equal(123, config.GetInt32("a.b.y"));
        }

        [Fact]
        public void CanResolveSubstitutesInNestedIncludes()
        {
            var japson = @"a.b.c {
  d { 
       include ""foo""
  }";
            var includeJapson = @"
f = 123
e {
      include ""foo""
}
";

            var includeJapson2 = @"
x = 123
y = ${x}
";

            Func<string, JapsonRoot> include2 = s => JapsonParser.Parse(includeJapson2, null);
            Func<string, JapsonRoot> include = s => JapsonParser.Parse(includeJapson, include2);
            var config = JapsonFactory.ParseString(japson, include);

            Assert.Equal(123, config.GetInt32("a.b.c.d.e.x"));
            Assert.Equal(123, config.GetInt32("a.b.c.d.e.y"));
        }
    }
}

