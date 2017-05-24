using System.Configuration;
using Standard.Data.Japson;

namespace Standard.Configuration
{
   /// <summary>
   /// This class represents a custom node within a configuration file.
   /// <code>
   /// <![CDATA[
   /// <?xml version="1.0" encoding="utf-8" ?>
   /// <configuration>
   ///   <configSections>
   ///     <section name="foo" type="Standard.Configuration.JapsonConfigurationSection, Standard.Configuration.Japson" />
   ///   </configSections>
   ///   <foo>
   ///   ...
   ///   </foo>
   /// </configuration>
   /// ]]>
   /// </code>
   /// </summary>
   public class JapsonConfigurationSection : ConfigurationSection
   {
      private const string ConfigurationPropertyName = "japson";
      private JapsonContext _config;

      /// <summary>
      /// Retrieves a <see cref="Config"/> from the contents of the custom node within a configuration file.
      /// </summary>
      public JapsonContext Config
      {
         get 
         { 
            return _config ?? (_config = JapsonFactory.ParseString(Japson.Content)); 
         }
      }

      /// <summary>
      /// Retrieves the JAPSON configuration string from the custom node.
      /// </summary>
      [ConfigurationProperty(ConfigurationPropertyName, IsRequired = true)]
      public JapsonConfigurationElement Japson
      {
         get { return (JapsonConfigurationElement)base[ConfigurationPropertyName]; }
         set { base[ConfigurationPropertyName] = value; }
      }
   }
}