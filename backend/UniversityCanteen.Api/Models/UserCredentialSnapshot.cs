namespace UniversityCanteen.Api.Models;

public sealed class UserCredentialSnapshot
{
    public int Id { get; init; }
    public string UniversityId { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string PasswordHash { get; init; } = string.Empty;
    public string Role { get; init; } = string.Empty;
    public string FirstName { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public string Contact { get; init; } = string.Empty;
    public string Department { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
}
