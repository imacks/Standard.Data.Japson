﻿using System;
using System.IO;
using System.Reflection;

namespace Standard.Data.Japson
{
    /// <summary>
    /// This class contains methods used to retrieve configuration information from a variety of sources including user-supplied strings, configuration files and assembly resources.
    /// </summary>
    public class JapsonFactory
    {
        /// <summary>
        /// Generates an empty configuration.
        /// </summary>
        public static JapsonContext Empty
        {
            get { return ParseString(string.Empty); }
        }

        /// <summary>
        /// Generates a configuration defined in the supplied JAPSON string.
        /// </summary>
        /// <param name="japson">A string that contains configuration options to use.</param>
        /// <param name="includeCallback">callback used to resolve includes</param>
        /// <returns>The configuration defined in the supplied JAPSON string.</returns>
        public static JapsonContext ParseString(string japson, Func<string, JapsonRoot> includeCallback)
        {
            JapsonRoot res = JapsonParser.Parse(japson, includeCallback);
            return new JapsonContext(res);
        }

        /// <summary>
        /// Generates a configuration defined in the supplied JAPSON string.
        /// </summary>
        /// <param name="japson">A string that contains configuration options to use.</param>
        /// <returns>The configuration defined in the supplied JAPSON string.</returns>
        public static JapsonContext ParseString(string japson)
        {
            // TODO: add default include resolver
            return ParseString(japson, null);
        }

        private static Assembly GetAssemblyByType(Type type)
        {
#if NETSTANDARD
            return type.GetTypeInfo().Assembly;
#else
            return type.Assembly;
#endif           
        }

        /// <summary>
        /// Retrieves a configuration defined in a resource of the current executing assembly.
        /// </summary>
        /// <param name="resourceName">The name of the resource that contains the configuration.</param>
        /// <returns>The configuration defined in the current executing assembly.</returns>
        internal static JapsonContext FromResource(string resourceName)
        {
#if NETSTANDARD
            Assembly assembly = typeof(JapsonFactory).GetTypeInfo().Assembly;
#else
            Assembly assembly = Assembly.GetExecutingAssembly();
#endif

            return FromResource(resourceName, assembly);
        }

        /// <summary>
        /// Retrieves a configuration defined in a resource of the assembly containing the supplied instance object.
        /// </summary>
        /// <param name="resourceName">The name of the resource that contains the configuration.</param>
        /// <param name="instanceInAssembly">An instance object located in the assembly to search.</param>
        /// <returns>The configuration defined in the assembly that contains the instanced object.</returns>
        public static JapsonContext FromResource(string resourceName, object instanceInAssembly)
        {
            Type type = instanceInAssembly as Type;
            if (type != null)
                return FromResource(resourceName, GetAssemblyByType(type));

            Assembly assembly = instanceInAssembly as Assembly;
            if (assembly != null)
                return FromResource(resourceName, assembly);

            return FromResource(resourceName, GetAssemblyByType(instanceInAssembly.GetType()));
        }

        /// <summary>
        /// Retrieves a configuration defined in a resource of the assembly containing the supplied type <typeparamref name="TAssembly"/>.
        /// </summary>
        /// <typeparam name="TAssembly">A type located in the assembly to search.</typeparam>
        /// <param name="resourceName">The name of the resource that contains the configuration.</param>
        /// <returns>The configuration defined in the assembly that contains the type <typeparamref name="TAssembly"/>.</returns>
        public static JapsonContext FromResource<TAssembly>(string resourceName)
        {
            return FromResource(resourceName, GetAssemblyByType(typeof(TAssembly)));
        }

        /// <summary>
        /// Retrieves a configuration defined in a resource of the supplied assembly.
        /// </summary>
        /// <param name="resourceName">The name of the resource that contains the configuration.</param>
        /// <param name="assembly">The assembly that contains the given resource.</param>
        /// <returns>The configuration defined in the assembly that contains the given resource.</returns>
        public static JapsonContext FromResource(string resourceName, Assembly assembly)
        {
            using (Stream stream = assembly.GetManifestResourceStream(resourceName))
            {
                using (StreamReader reader = new StreamReader(stream))
                {
                    string result = reader.ReadToEnd();

                    return ParseString(result);
                }
            }
        }
    }
}
