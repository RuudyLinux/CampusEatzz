namespace UniversityCanteen.Api.Models;

public sealed class SessionUserDto
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string Role { get; init; } = string.Empty;
    public string? UniversityId { get; init; }
    public string? FirstName { get; init; }
    public string? LastName { get; init; }
    public string? Contact { get; init; }
    public string? Department { get; init; }
    public string? Status { get; init; }
    public int? CanteenId { get; init; }
    public string? CanteenName { get; init; }
    public string? ImageUrl { get; init; }
}
