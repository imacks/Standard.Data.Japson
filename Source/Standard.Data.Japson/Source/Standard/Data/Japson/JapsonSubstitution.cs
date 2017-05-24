using System.Collections.Generic;

namespace Standard.Data.Japson
{
    /// <summary>
    /// This class represents a substitution element in a JAPSON configuration string.
    /// </summary>
    /// <remarks>
    /// <code>
    /// foo {  
    ///   defaultInstances = 10
    ///   deployment{
    ///     /user/time{
    ///       nr-of-instances = $defaultInstances
    ///     }
    ///   }
    /// }
    /// </code>
    /// </remarks>
    public class JapsonSubstitution : IJapsonElement, IPossibleJapsonObject
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="JapsonSubstitution"/> class.
        /// </summary>
        protected JapsonSubstitution()
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="JapsonSubstitution" /> class.
        /// </summary>
        /// <param name="path">The path.</param>
        public JapsonSubstitution(string path)
        {
            Path = path;
        }

        /// <summary>
        /// The full path to the value which should substitute this instance.
        /// </summary>
        public string Path { get; set; }

        /// <summary>
        /// The evaluated value from the Path property
        /// </summary>
        public JapsonValue ResolvedValue { get; set; }

        /// <summary>
        /// Determines whether this element is a string.
        /// </summary>
        /// <returns><c>true</c> if this element is a string; otherwise <c>false</c></returns>
        public bool IsString()
        {
            return ResolvedValue.IsString();
        }

        /// <summary>
        /// Retrieves the string representation of this element.
        /// </summary>
        /// <returns>The string representation of this element.</returns>
        public string GetString()
        {
            return ResolvedValue.GetString();
        }

        /// <summary>
        /// Determines whether this element is an array.
        /// </summary>
        /// <returns><c>true</c> if this element is aan array; otherwise <c>false</c></returns>
        public bool IsArray()
        {
            return ResolvedValue.IsArray();
        }

        /// <summary>
        /// Retrieves a list of elements associated with this element.
        /// </summary>
        /// <returns>A list of elements associated with this element.</returns>
        public IList<JapsonValue> GetArray()
        {
            return ResolvedValue.GetArray();
        }

        /// <summary>
        /// Determines whether this element is a JAPSON object.
        /// </summary>
        /// <returns><c>true</c> if this element is a JAPSON object; otherwise <c>false</c></returns>
        public bool IsObject()
        {
            return ResolvedValue != null && ResolvedValue.IsObject();
        }

        /// <summary>
        /// Retrieves the JAPSON object representation of this element.
        /// </summary>
        /// <returns>The JAPSON object representation of this element.</returns>
        public JapsonObject GetObject()
        {
            return ResolvedValue.GetObject();
        }
    }
}

