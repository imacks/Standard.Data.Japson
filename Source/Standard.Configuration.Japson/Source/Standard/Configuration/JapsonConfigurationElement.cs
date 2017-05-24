using System.Configuration;

namespace Standard.Configuration
{
    /// <summary>
    /// This class represents a custom JAPSON node within a configuration file.
    /// <code>
    /// <![CDATA[
    /// <?xml version="1.0" encoding="utf-8" ?>
    /// <configuration>
    ///   <configSections>
    ///     <section name="foo" type="Standard.Configuration.JapsonConfigurationSection, Standard.Configuration.Japsonn" />
    ///   </configSections>
    ///   <foo>
    ///     <japson>
    ///     ...
    ///     </japson>
    ///   </foo>
    /// </configuration>
    /// ]]>
    /// </code>
    /// </summary>
    public class JapsonConfigurationElement : CDataConfigurationElement
    {
        /// <summary>
        /// Gets or sets the JAPSON configuration string contained in the japson node.
        /// </summary>
        [ConfigurationProperty(ContentPropertyName, IsRequired = true, IsKey = true)]
        public string Content
        {
            get { return (string)base[ContentPropertyName]; }
            set { base[ContentPropertyName] = value; }
        }
    }
}

