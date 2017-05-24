using System.Configuration;
using System.Linq;
using Xunit;
using Standard.Configuration;
using Standard.Data.Japson;

namespace Standard.Configuration.Japson.Tests
{
    public class ConfigurationSpecTest
    {
        [Fact]
        public void CanDeserializeJapsonConfigurationFromConfigFile()
        {
            JapsonConfigurationSection section = (JapsonConfigurationSection)ConfigurationManager.GetSection("foo");
            Assert.NotNull(section);
            Assert.False(string.IsNullOrEmpty(section.Japson.Content));
            JapsonContext config = section.Config;
            Assert.NotNull(config);
        }

        /*
        [Fact]
        public void CanCreateConfigFromSourceObject()
        {
            var source = new MyObjectConfig
            {
                StringProperty = "aaa",
                BoolProperty = true,
                IntergerArray = new[]{1,2,3,4 }
            };

            var config = JapsonFactory.FromObject(source);

            Assert.Equal("aaa", config.GetString("StringProperty"));
            Assert.Equal(true, config.GetBoolean("BoolProperty"));

            Assert.Equal(new[] { 1, 2, 3, 4 }, config.GetInt32List("IntergerArray").ToArray());
        }
        */
        
        [Fact]
        public void CanMergeObjects()
        {
            string japson1 = @"
a {
    b = 123
    c = 456
    d = 789
    sub {
        aa = 123
    }
}
";

            string japson2 = @"
a {
    c = 999
    e = 888
    sub {
        bb = 456
    }
}
";

            var root1 = JapsonParser.Parse(japson1, null);
            var root2 = JapsonParser.Parse(japson2, null);

            var obj1 = root1.Value.GetObject();
            var obj2 = root2.Value.GetObject();
            obj1.Merge(obj2);

            JapsonContext config = new JapsonContext(root1);

            Assert.Equal(123, config.GetInt32("a.b"));
            Assert.Equal(456, config.GetInt32("a.c"));
            Assert.Equal(789, config.GetInt32("a.d"));
            Assert.Equal(888, config.GetInt32("a.e"));
            Assert.Equal(888, config.GetInt32("a.e"));
            Assert.Equal(123, config.GetInt32("a.sub.aa"));
            Assert.Equal(456, config.GetInt32("a.sub.bb"));
        }

        public class MyObjectConfig
        {
            public string StringProperty { get; set; }
            public bool BoolProperty { get; set; }
            public int[] IntergerArray { get; set; }
        }
   }
}
