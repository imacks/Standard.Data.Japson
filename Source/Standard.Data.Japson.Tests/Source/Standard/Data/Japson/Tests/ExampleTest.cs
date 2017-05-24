using System;
using System.Reflection;
using System.Linq;
using System.IO;
using Xunit;
using Standard.Data.Japson;

namespace Standard.Data.Japson.Tests
{
    public class ExampleTest
    {
        private JapsonContext GetEmbedFileContent(string fileName)
        {
#if NETSTANDARD
            Assembly assembly = typeof(ExampleTest).GetTypeInfo().Assembly;
#else
            Assembly assembly = Assembly.GetExecutingAssembly();
#endif

            string resourceName = string.Format("Standard.Data.Japson.Tests.Embed.{0}", fileName);

            return JapsonFactory.FromResource(resourceName, assembly);
        }

        [Fact]
        public void CanParseHelloFile()
        {
            JapsonContext japson = GetEmbedFileContent("Hello.japson");
            var val = japson.GetString("root.simple-string");
            Assert.Equal("Hello JAPSON", val);
        }

        [Fact]
        public void CanParseSimpleSubstitutionFile()
        {
            JapsonContext japson = GetEmbedFileContent("SimpleSub.japson");
            var val = japson.GetString("root.simple-string");
            Assert.Equal("Hello JAPSON", val);
        }

        [Fact]
        public void CanParseObjectMergeFile()
        {
            JapsonContext japson = GetEmbedFileContent("ObjectMerge.japson");

            var val1 = japson.GetString("root.some-object.property1");
            var val2 = japson.GetString("root.some-object.property2");
            var val3 = japson.GetString("root.some-object.property3");

            Assert.Equal("123", val1);
            Assert.Equal("456", val2);
            Assert.Equal("789", val3);
        }

        [Fact]
        public void CanParseFallbackFile()
        {
            JapsonContext baseContext = GetEmbedFileContent("FallbackBase.japson");
            JapsonContext userContext = GetEmbedFileContent("FallbackUser.japson");
            JapsonContext merged = userContext.WithFallback(baseContext);

            var val1 = merged.GetString("root.some-property1");
            var val2 = merged.GetString("root.some-property2");
            var val3 = merged.GetString("root.some-property3");

            Assert.Equal("123", val1);
            Assert.Equal("456", val2);
            Assert.Equal("789", val3);
        }

        /*
        #todo
        [Fact]
        public void CanParseExternalRefFile()
        {
            string japson = GetEmbedFileContent("ExternalRef.japson").ToString();

            // in this example we use a file resolver as the include mechanism
            // but could be replaced with e.g. a resolver for assembly resources
            Func<string, JapsonRoot> fileResolver = null;

            fileResolver = fileName =>
                {
                    var content = GetEmbedFileContent(fileName).ToString();

                    //var content = File.ReadAllText(fileName);
                    var parsed = JapsonParser.Parse(content, fileResolver);
                    return parsed;
                };

            var config = JapsonFactory.ParseString(japson, fileResolver);

            var val1 = config.GetInt32("root.some-property.foo");
            var val2 = config.GetInt32("root.some-property.bar");
            var val3 = config.GetInt32("root.some-property.baz");

            Assert.Equal(123, val1);
            Assert.Equal(234, val2);
            Assert.Equal(789, val3);
        }
        */
    }
}
