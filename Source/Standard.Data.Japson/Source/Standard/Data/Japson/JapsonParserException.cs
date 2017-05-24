using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Standard.Data.Japson
{
    public class JapsonParserException : Exception
    {
        public JapsonParserException(string message) 
            : base(message)
        {
        }

        public JapsonParserException(string message, Exception innerException) 
            : base(message, innerException)
        {
        }
    }
}
