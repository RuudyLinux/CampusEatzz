using Dapper;
using UniversityCanteen.Api.Models;

namespace UniversityCanteen.Api.Data;

public sealed class UniversityCanteenDbContext(IDbConnectionFactory connectionFactory)
{
    public async Task<AdminUser?> FindAdminByIdentifierAsync(string identifier, CancellationToken cancellationToken)
    {
        using var connection = connectionFactory.CreateConnection();
        var admins = await connection.QueryAsync<AdminUser>(new CommandDefinition(
            """
            SELECT
                id AS Id,
                COALESCE(name, '') AS Name,
                COALESCE(email, '') AS Email,
                COALESCE(password, '') AS Password,
                COALESCE(created_at, UTC_TIMESTAMP()) AS CreatedAt
            FROM admin_users
            WHERE LOWER(COALESCE(email, '')) = LOWER(@identifier)
               OR LOWER(COALESCE(name, '')) = LOWER(@identifier)
            LIMIT 2;
            """,
            new { identifier },
            cancellationToken: cancellationToken));

        return admins.FirstOrDefault();
    }

    public async Task<Student?> FindStudentByUniversityIdAsync(string universityId, CancellationToken cancellationToken)
    {
        using var connection = connectionFactory.CreateConnection();
        var students = await connection.QueryAsync<Student>(new CommandDefinition(
            """
            SELECT
                COALESCE(university_id, '') AS UniversityId,
                COALESCE(course, '') AS Course,
                COALESCE(semester, 0) AS Semester,
                COALESCE(created_at, UTC_TIMESTAMP()) AS CreatedAt,
                COALESCE(updated_at, UTC_TIMESTAMP()) AS UpdatedAt
            FROM students
            WHERE COALESCE(university_id, '') = @universityId
            LIMIT 2;
            """,
            new { universityId },
            cancellationToken: cancellationToken));

        return students.FirstOrDefault();
    }

    public async Task<UniversityStaff?> FindUniversityStaffByUniversityIdAsync(string universityId, CancellationToken cancellationToken)
    {
        using var connection = connectionFactory.CreateConnection();
        var staff = await connection.QueryAsync<UniversityStaff>(new CommandDefinition(
            """
            SELECT
                COALESCE(university_id, '') AS UniversityId,
                COALESCE(department, '') AS Department,
                date_of_birth AS DateOfBirth,
                COALESCE(created_at, UTC_TIMESTAMP()) AS CreatedAt,
                COALESCE(updated_at, UTC_TIMESTAMP()) AS UpdatedAt
            FROM university_staff
            WHERE COALESCE(university_id, '') = @universityId
            LIMIT 2;
            """,
            new { universityId },
            cancellationToken: cancellationToken));

        return staff.FirstOrDefault();
    }

    public async Task<UserCredentialSnapshot?> FindUserCredentialByUniversityIdAsync(string universityId, CancellationToken cancellationToken)
    {
        using var connection = connectionFactory.CreateConnection();
        var users = await connection.QueryAsync<UserCredentialSnapshot>(new CommandDefinition(
            """
            SELECT
                u.id AS Id,
                COALESCE(u.university_id, '') AS UniversityId,
                COALESCE(u.email, '') AS Email,
                COALESCE(u.password_hash, '') AS PasswordHash,
                COALESCE(u.role, '') AS Role,
                COALESCE(u.first_name, '') AS FirstName,
                COALESCE(u.last_name, '') AS LastName,
                COALESCE(u.contact, '') AS Contact,
                COALESCE(u.department, '') AS Department,
                COALESCE(u.status, '') AS Status
            FROM users u
            WHERE COALESCE(u.university_id, '') = @universityId
              AND COALESCE(u.status, 'active') = 'active'
            LIMIT 2;
            """,
            new { universityId },
            cancellationToken: cancellationToken));

        return users.FirstOrDefault();
    }

    public async Task SaveRefreshTokenAsync(AuthRefreshToken refreshToken, CancellationToken cancellationToken)
    {
        using var connection = connectionFactory.CreateConnection();

        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO auth_refresh_tokens (user_id, role, token_hash, expires_at_utc, created_at_utc)
            VALUES (@userId, @role, @tokenHash, @expiresAtUtc, UTC_TIMESTAMP());
            """,
            new
            {
                userId = refreshToken.UserId,
                role = refreshToken.Role,
                tokenHash = refreshToken.TokenHash,
                expiresAtUtc = refreshToken.ExpiresAtUtc
            },
            cancellationToken: cancellationToken));
    }

    public async Task<AuthRefreshToken?> FindRefreshTokenByHashAsync(string tokenHash, CancellationToken cancellationToken)
    {
        using var connection = connectionFactory.CreateConnection();

        var tokens = await connection.QueryAsync<AuthRefreshToken>(new CommandDefinition(
            """
            SELECT
                id AS Id,
                user_id AS UserId,
                COALESCE(role, '') AS Role,
                COALESCE(token_hash, '') AS TokenHash,
                COALESCE(expires_at_utc, UTC_TIMESTAMP()) AS ExpiresAtUtc,
                COALESCE(created_at_utc, UTC_TIMESTAMP()) AS CreatedAtUtc,
                revoked_at_utc AS RevokedAtUtc
            FROM auth_refresh_tokens
            WHERE token_hash = @tokenHash
            LIMIT 1;
            """,
            new { tokenHash },
            cancellationToken: cancellationToken));

        return tokens.FirstOrDefault();
    }

    public async Task RevokeRefreshTokenAsync(string tokenHash, CancellationToken cancellationToken)
    {
        using var connection = connectionFactory.CreateConnection();

        await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE auth_refresh_tokens
            SET revoked_at_utc = UTC_TIMESTAMP()
            WHERE token_hash = @tokenHash
              AND revoked_at_utc IS NULL;
            """,
            new { tokenHash },
            cancellationToken: cancellationToken));
    }

    public async Task RevokeRefreshTokensAsync(int userId, string role, CancellationToken cancellationToken)
    {
        using var connection = connectionFactory.CreateConnection();

        await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE auth_refresh_tokens
            SET revoked_at_utc = UTC_TIMESTAMP()
            WHERE user_id = @userId
              AND LOWER(COALESCE(role, '')) = LOWER(@role)
              AND revoked_at_utc IS NULL;
            """,
            new { userId, role },
            cancellationToken: cancellationToken));
    }

    public async Task<SessionUserDto?> BuildSessionUserAsync(int userId, string role, CancellationToken cancellationToken)
    {
        if (string.Equals(role, "admin", StringComparison.OrdinalIgnoreCase))
        {
            using var adminConnection = connectionFactory.CreateConnection();
            return await adminConnection.QuerySingleOrDefaultAsync<SessionUserDto>(new CommandDefinition(
                """
                SELECT
                    a.id AS Id,
                    COALESCE(a.name, '') AS Name,
                    COALESCE(a.email, '') AS Email,
                    'admin' AS Role
                FROM admin_users a
                WHERE a.id = @userId
                LIMIT 1;
                """,
                new { userId },
                cancellationToken: cancellationToken));
        }

        using var userConnection = connectionFactory.CreateConnection();
        return await userConnection.QuerySingleOrDefaultAsync<SessionUserDto>(new CommandDefinition(
            """
            SELECT
                u.id AS Id,
                COALESCE(NULLIF(TRIM(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))), ''), COALESCE(u.email, ''), COALESCE(u.university_id, '')) AS Name,
                COALESCE(u.email, '') AS Email,
                COALESCE(u.role, '') AS Role,
                COALESCE(u.university_id, '') AS UniversityId,
                COALESCE(u.first_name, '') AS FirstName,
                COALESCE(u.last_name, '') AS LastName,
                COALESCE(u.contact, '') AS Contact,
                COALESCE(u.department, '') AS Department,
                COALESCE(u.status, '') AS Status
            FROM users u
            WHERE u.id = @userId
              AND COALESCE(u.status, 'active') = 'active'
            LIMIT 1;
            """,
            new { userId },
            cancellationToken: cancellationToken));
    }
}
