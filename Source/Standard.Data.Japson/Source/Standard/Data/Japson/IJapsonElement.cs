using System.Collections.Generic;

namespace Standard.Data.Japson
{
    /// <summary>
    /// Marker interface to make it easier to retrieve JAPSON objects for substitutions.
    /// </summary>
    public interface IPossibleJapsonObject
    {
        /// <summary>
        /// Determines whether this element is a JAPSON object.
        /// </summary>
        /// <returns>
        /// <c>true</c> if this element is a JAPSON object; otherwise <c>false</c>
        /// </returns>
        bool IsObject();

        /// <summary>
        /// Retrieves the JAPSON object representation of this element.
        /// </summary>
        /// <returns>
        /// The JAPSON object representation of this element.
        /// </returns>
        JapsonObject GetObject();
    }

    /// <summary>
    /// This interface defines the contract needed to implement a JAPSON element.
    /// </summary>
    public interface IJapsonElement
    {
        /// <summary>
        /// Determines whether this element is a string.
        /// </summary>
        /// <returns>
        /// <c>true</c> if this element is a string; otherwise <c>false</c>
        /// </returns>
        bool IsString();

        /// <summary>
        /// Retrieves the string representation of this element.
        /// </summary>
        /// <returns>
        /// The string representation of this element.
        /// </returns>
        string GetString();

        /// <summary>
        /// Determines whether this element is an array.
        /// </summary>
        /// <returns>
        /// <c>true</c> if this element is aan array; otherwise <c>false</c>
        /// </returns>
        bool IsArray();

        /// <summary>
        /// Retrieves a list of elements associated with this element.
        /// </summary>
        /// <returns>
        /// A list of elements associated with this element.
        /// </returns>
        IList<JapsonValue> GetArray();
    }
}

