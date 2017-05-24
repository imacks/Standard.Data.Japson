using System;
using System.Collections.Generic;

namespace Standard.Data.Japson
{
    /// <summary>
    /// This class represents an array element in a JAPSON configuration string.
    /// </summary>
    /// <remarks>
    /// <code>
    /// root {
    ///     items = [
    ///       "1",
    ///       "2"]
    /// }
    /// </code>
    /// </remarks>
    public class JapsonArray : List<JapsonValue>, IJapsonElement
    {
        /// <summary>
        /// Determines whether this element is a string.
        /// </summary>
        /// <returns><c>false</c></returns>
        public bool IsString()
        {
            return false;
        }

        /// <summary>
        /// Retrieves the string representation of this element.
        /// </summary>
        /// <exception cref="System.NotImplementedException">
        /// This element is an array. It is not a string. Therefore this method will throw an exception.
        /// </exception>
        /// <returns>
        /// The string representation of this element.
        /// </returns>
        public string GetString()
        {
            throw new NotSupportedException();
        }

        /// <summary>
        /// Determines whether this element is an array.
        /// </summary>
        /// <returns><c>true</c></returns>
        public bool IsArray()
        {
            return true;
        }

        /// <summary>
        /// Retrieves a list of elements associated with this element.
        /// </summary>
        /// <returns>
        /// A list of elements associated with this element.
        /// </returns>
        public IList<JapsonValue> GetArray()
        {
            return this;
        }

        /// <summary>
        /// Returns a JAPSON string representation of this element.
        /// </summary>
        /// <returns>A JAPSON string representation of this element.</returns>
        public override string ToString()
        {
            return "[" + string.Join(",", this) + "]";
        }
    }
}
