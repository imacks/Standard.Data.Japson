using System.Collections.Generic;
using System.Linq;

namespace Standard.Data.Japson
{
    /// <summary>
    /// This class represents the root element in a JAPSON configuration string.
    /// </summary>
    public class JapsonRoot
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="JapsonRoot"/> class.
        /// </summary>
        protected JapsonRoot()
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="JapsonRoot"/> class.
        /// </summary>
        /// <param name="value">The value to associate with this element.</param>
        /// <param name="substitutions">An enumeration of substitutions to associate with this element.</param>
        public JapsonRoot(JapsonValue value, IEnumerable<JapsonSubstitution> substitutions)
        {
            Value = value;
            Substitutions = substitutions;
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="JapsonRoot"/> class.
        /// </summary>
        /// <param name="value">The value to associate with this element.</param>
        public JapsonRoot(JapsonValue value)
        {
            Value = value;
            Substitutions = Enumerable.Empty<JapsonSubstitution>();
        }

        /// <summary>
        /// Retrieves the value associated with this element.
        /// </summary>
        public JapsonValue Value { get; private set; }

        /// <summary>
        /// Retrieves an enumeration of substitutions associated with this element.
        /// </summary>
        public IEnumerable<JapsonSubstitution> Substitutions { get; private set; }
    }
}
