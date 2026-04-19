using System.Data;

namespace UniversityCanteen.Api.Data;

public interface IDbConnectionFactory
{
    IDbConnection CreateConnection();
}
