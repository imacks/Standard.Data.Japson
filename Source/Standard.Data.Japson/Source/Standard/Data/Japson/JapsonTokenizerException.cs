using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Standard.Data.Japson
{
    public class JapsonTokenizerException : Exception
    {
        public JapsonTokenizerException(string message) 
            : base(message)
        {
        }
    }
}
