using System;
using System.Configuration;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using Standard.Data.Japson;

namespace Standard.Configuration
{
    /// <summary>
    /// This class contains methods used to retrieve configuration information from a variety of sources including user-supplied strings, configuration files and assembly resources.
    /// </summary>
    public static class JapsonFactoryExtension
    {
        /// <summary>
        /// Loads a configuration defined in the current application's configuration file, e.g. app.config or web.config
        /// </summary>
        /// <returns>The configuration defined in the configuration file.</returns>
        public static JapsonContext FromAppConfiguration(this JapsonContext context)
        {
           JapsonConfigurationSection section = (JapsonConfigurationSection)ConfigurationManager.GetSection("japson") ?? new JapsonConfigurationSection();
           JapsonContext config = section.Config;
   
           return config;
        }
    }
}
