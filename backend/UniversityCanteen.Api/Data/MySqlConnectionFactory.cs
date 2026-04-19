using System.Data;
using MySqlConnector;

namespace UniversityCanteen.Api.Data;

public sealed class MySqlConnectionFactory(string connectionString) : IDbConnectionFactory
{
    public IDbConnection CreateConnection() => new MySqlConnection(connectionString);
}
