using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Standard.Data.Japson
{
    /// <summary>
    /// This class represents an object element in a JAPSON configuration string.
    /// </summary>
    /// <remarks>
    /// <code>
    /// foo {  
    ///   child {
    ///     grandchild {  
    ///       receive = on 
    ///       autoreceive = on
    ///       lifecycle = on
    ///       event-stream = on
    ///       unhandled = on
    ///     }
    ///   }
    /// }
    /// </code>
    /// </remarks>
    public class JapsonObject : IJapsonElement
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="JapsonObject"/> class.
        /// </summary>
        public JapsonObject()
        {
            Items = new Dictionary<string, JapsonValue>();
        }

        /// <summary>
        /// Retrieves the underlying map that contains the barebones object values.
        /// </summary>
        /// [JsonIgnore]
        public IDictionary<string, object> Unwrapped
        {
            get
            {
                return Items.ToDictionary(k => k.Key, v =>
                    {
                        JapsonObject obj = v.Value.GetObject();

                        if (obj != null)
                            return (object)obj.Unwrapped;

                        return v.Value;
                    });
            }
        }

        /// <summary>
        /// Retrieves the underlying map that this element is based on.
        /// </summary>
        public Dictionary<string, JapsonValue> Items { get; private set; }

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
        /// <returns>The string representation of this element.</returns>
        /// <exception cref="System.NotImplementedException">
        /// This element is an object. It is not a string. Therefore this method will throw an exception.
        /// </exception>
        public string GetString()
        {
            throw new NotSupportedException();
        }

        /// <summary>
        /// Determines whether this element is an array.
        /// </summary>
        /// <returns><c>false</c></returns>
        public bool IsArray()
        {
            return false;
        }

        /// <summary>
        /// Retrieves a list of elements associated with this element.
        /// </summary>
        /// <returns>A list of elements associated with this element.</returns>
        /// <exception cref="System.NotImplementedException">
        /// This element is an object. It is not an array. Therefore this method will throw an exception.
        /// </exception>
        public IList<JapsonValue> GetArray()
        {
            throw new NotSupportedException();
        }

        /// <summary>
        /// Retrieves the value associated with the supplied key.
        /// </summary>
        /// <param name="key">The key associated with the value to retrieve.</param>
        /// <returns>
        /// The value associated with the supplied key or null if they key does not exist.
        /// </returns>
        public JapsonValue GetKey(string key)
        {
            if (Items.ContainsKey(key))
                return Items[key];

            return null;
        }

        /// <summary>
        /// Retrieves the value associated with the supplied key. If the supplied key is not found, then one is created with a blank value.
        /// </summary>
        /// <param name="key">The key associated with the value to retrieve.</param>
        /// <returns>The value associated with the supplied key.</returns>
        public JapsonValue GetOrCreateKey(string key)
        {
            if (Items.ContainsKey(key))
                return Items[key];

            JapsonValue child = new JapsonValue();
            Items.Add(key, child);
            return child;
        }

        /// <summary>
        /// Returns a JAPSON string representation of this element.
        /// </summary>
        /// <returns>A JAPSON string representation of this element.</returns>
        public override string ToString()
        {
            return ToString(0);
        }

        /// <summary>
        /// Returns a JAPSON string representation of this element.
        /// </summary>
        /// <param name="indent">The number of spaces to indent the string.</param>
        /// <returns>A JAPSON string representation of this element.</returns>
        public string ToString(int indent)
        {
            string i = new string(' ', indent * 2);
            StringBuilder sb = new StringBuilder();
            foreach (var kvp in Items)
            {
                string key = QuoteIfNeeded(kvp.Key);
                sb.AppendFormat("{0}{1} : {2}\r\n", i, key, kvp.Value.ToString(indent));
            }

            return sb.ToString();
        }

        private string QuoteIfNeeded(string text)
        {
            if (text.ToCharArray().Intersect(" \t".ToCharArray()).Any())
                return "\"" + text + "\"";

            return text;
        }

        public void Merge(JapsonObject other)
        {
            Dictionary<string, JapsonValue> thisItems = Items;
            Dictionary<string, JapsonValue> otherItems = other.Items;

            foreach (var otherItem in otherItems)
            {
                if (thisItems.ContainsKey(otherItem.Key))
                {
                    // other key was present in this object.
                    // if we have a value, just ignore the other value, unless it is an object
                    JapsonValue thisItem = thisItems[otherItem.Key];

                    //if both values are objects, merge them
                    if (thisItem.IsObject() && otherItem.Value.IsObject())
                        thisItem.GetObject().Merge(otherItem.Value.GetObject());
                }
                else
                {
                    //other key was not present in this object, just copy it over
                    Items.Add(otherItem.Key,otherItem.Value);
                }
            }            
        }
    }
}
